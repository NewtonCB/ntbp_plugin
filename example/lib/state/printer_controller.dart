import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

enum BluetoothPermission { unknown, granted, denied, blocked }

/// Connection state, printer status, media settings and the list of labels
/// to print. One instance lives for the whole app and is exposed through
/// [PrinterScope].
class PrinterController extends ChangeNotifier {
  final NtbpPlugin _plugin = NtbpPlugin();

  // --- Permissions ---------------------------------------------------------
  BluetoothPermission permission = BluetoothPermission.unknown;
  bool requestingPermission = false;

  // --- Bluetooth -----------------------------------------------------------
  List<BluetoothDevice> devices = [];
  bool scanning = false;
  BluetoothDevice? connected;
  bool connecting = false;
  String? connectionError;

  // --- Printer status ------------------------------------------------------
  PrinterStatus? status;
  DateTime? statusCheckedAt;
  bool checkingStatus = false;

  // --- Printing ------------------------------------------------------------
  bool printing = false;
  int printingIndex = -1;
  PrintBatchResult? lastBatch;

  // --- Data ----------------------------------------------------------------
  LabelPrintConfig config = const LabelPrintConfig(density: 10);
  final List<CargoLabel> labels = [];

  /// Logo printed at the top of every label. Loaded from the app bundle;
  /// replace with [setLogo] to use another image.
  CargoLogo? logo;
  bool printLogo = true;

  String? lastMessage;

  PrinterController() {
    loadSampleLabels();
    checkPermissions();
    _loadBundledLogo();
  }

  Future<void> _loadBundledLogo() async {
    try {
      final data = await rootBundle.load('assets/logo.png');
      logo = CargoLogo.fromBytes(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('[NTBP] logo not loaded: $e');
    }
    notifyListeners();
  }

  void setLogo(CargoLogo? value) {
    logo = value;
    notifyListeners();
  }

  void setPrintLogo(bool value) {
    printLogo = value;
    notifyListeners();
  }

  CargoLogo? get _activeLogo => printLogo ? logo : null;

  bool get isConnected => connected != null;

  void _say(String message) {
    lastMessage = message;
    debugPrint('[NTBP] $message');
    notifyListeners();
  }

  // ===========================================================================
  // Permissions and discovery
  // ===========================================================================

  List<Permission> get _wantedPermissions => [
        if (Platform.isIOS) Permission.bluetooth,
        if (Platform.isAndroid) ...[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ],
      ];

  BluetoothPermission _fold(Iterable<PermissionStatus> statuses) {
    if (statuses.every((s) => s.isGranted || s.isLimited)) {
      return BluetoothPermission.granted;
    }
    if (statuses.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
      return BluetoothPermission.blocked;
    }
    return BluetoothPermission.denied;
  }

  /// Reads the current permission state without prompting.
  ///
  /// On Android the plugin itself is the authority: it knows which runtime
  /// permissions the running OS version needs. permission_handler is only
  /// consulted to tell "denied" from "blocked" (user chose "Don't ask again").
  Future<BluetoothPermission> checkPermissions() async {
    try {
      if (Platform.isAndroid) {
        if (await _plugin.hasBluetoothPermissions()) {
          permission = BluetoothPermission.granted;
        } else {
          permission = await _androidDeniedOrBlocked();
        }
      } else {
        final wanted = _wantedPermissions;
        if (wanted.isEmpty) {
          permission = BluetoothPermission.granted;
        } else {
          final statuses = await Future.wait(wanted.map((p) => p.status));
          permission = _fold(statuses);
        }
      }
    } catch (e) {
      _say('Could not read permission state: $e');
    }
    notifyListeners();
    return permission;
  }

  Future<BluetoothPermission> _androidDeniedOrBlocked() async {
    try {
      final statuses = await Future.wait(
        [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse]
            .map((p) => p.status),
      );
      if (statuses.any((s) => s.isPermanentlyDenied)) return BluetoothPermission.blocked;
    } catch (_) {}
    return BluetoothPermission.denied;
  }

  /// Shows the system permission prompt. When the OS no longer allows the
  /// prompt (user chose "Don't allow" before) the app's Settings page is
  /// opened instead so the user can switch Bluetooth on there.
  Future<bool> requestPermissions({bool openSettingsIfBlocked = true}) async {
    if (requestingPermission) return permission == BluetoothPermission.granted;
    requestingPermission = true;
    notifyListeners();
    try {
      if (Platform.isAndroid) {
        // The plugin shows the system dialog for exactly what the OS needs.
        final ok = await _plugin.requestBluetoothPermissions();
        permission = ok ? BluetoothPermission.granted : await _androidDeniedOrBlocked();
      } else {
        final wanted = _wantedPermissions;
        if (wanted.isEmpty) {
          permission = BluetoothPermission.granted;
          return true;
        }
        final results = await wanted.request();
        permission = _fold(results.values);
      }

      if (permission == BluetoothPermission.granted) {
        _say('Bluetooth permission granted');
        return true;
      }
      if (permission == BluetoothPermission.blocked && openSettingsIfBlocked) {
        _say('Bluetooth is blocked for this app. Enable it in Settings.');
        await openAppSettings();
      } else {
        _say('Bluetooth permission was not granted');
      }
      return false;
    } catch (e) {
      _say('Permission request failed: $e');
      return false;
    } finally {
      requestingPermission = false;
      notifyListeners();
    }
  }

  Future<bool> ensurePermissions() async {
    if (permission == BluetoothPermission.granted) return true;
    await checkPermissions();
    if (permission == BluetoothPermission.granted) return true;
    return requestPermissions();
  }

  /// Scans for printers. The device list is refreshed every second while
  /// the scan window is open so the UI can show printers as they appear.
  Future<void> scan() async {
    if (scanning) return;
    if (!await ensurePermissions()) return;

    scanning = true;
    connectionError = null;
    devices = [];
    notifyListeners();

    Timer? poll;
    try {
      poll = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          devices = _sorted(await _plugin.getDiscoveredDevices());
          notifyListeners();
        } catch (_) {}
      });
      await _plugin.startScan();
      devices = _sorted(await _plugin.getDiscoveredDevices());
    } catch (e) {
      _say('Scan failed: $e');
    } finally {
      poll?.cancel();
      scanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await _plugin.stopScan();
    } catch (_) {}
  }

  List<BluetoothDevice> _sorted(List<BluetoothDevice> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final aPrinter = _looksLikePrinter(a) ? 0 : 1;
      final bPrinter = _looksLikePrinter(b) ? 0 : 1;
      if (aPrinter != bPrinter) return aPrinter - bPrinter;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return copy;
  }

  static bool _looksLikePrinter(BluetoothDevice d) {
    final n = d.name.toLowerCase();
    return n.contains('xp') ||
        n.contains('print') ||
        n.contains('n41') ||
        n.contains('tspl') ||
        n.contains('label');
  }

  // ===========================================================================
  // Connection
  // ===========================================================================

  Future<bool> connect(BluetoothDevice device) async {
    if (connecting) return false;
    if (!await ensurePermissions()) return false;
    connecting = true;
    connectionError = null;
    notifyListeners();
    try {
      final ok = await _plugin.connectToDevice(device);
      if (ok) {
        connected = device;
        _say('Connected to ${device.name}');
        unawaited(refreshStatus());
      } else {
        connectionError = 'Printer refused the connection';
        _say(connectionError!);
      }
      return ok;
    } catch (e) {
      connectionError = _friendly(e);
      _say('Connection failed: $connectionError');
      return false;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await _plugin.disconnect();
    } catch (_) {}
    connected = null;
    status = null;
    _say('Disconnected');
  }

  /// Re-checks whether the native side still holds a connection and refreshes
  /// the permission state (the user may have changed it in Settings).
  Future<void> syncConnection() async {
    unawaited(checkPermissions());
    try {
      final live = await _plugin.isConnected();
      if (!live && connected != null) {
        connected = null;
        status = null;
        _say('Printer connection was lost');
      }
    } catch (_) {}
  }

  // ===========================================================================
  // Status, calibration
  // ===========================================================================

  Future<PrinterStatus> refreshStatus() async {
    checkingStatus = true;
    notifyListeners();
    try {
      status = await NtbpPlugin.queryPrinterStatus();
      statusCheckedAt = DateTime.now();
      return status!;
    } catch (e) {
      status = PrinterStatus.noResponse;
      _say('Status query failed: ${_friendly(e)}');
      return status!;
    } finally {
      checkingStatus = false;
      notifyListeners();
    }
  }

  Future<bool> calibrate() async {
    try {
      final ok = await NtbpPlugin.calibrateGap();
      _say(ok
          ? 'Calibrating: the printer feeds a few labels to measure the gap'
          : 'Calibration command failed');
      return ok;
    } catch (e) {
      _say('Calibration failed: ${_friendly(e)}');
      return false;
    }
  }

  Future<bool> formFeed() async {
    try {
      return await NtbpPlugin.formFeed();
    } catch (e) {
      _say('Feed failed: ${_friendly(e)}');
      return false;
    }
  }

  // ===========================================================================
  // Printing
  // ===========================================================================

  Future<bool> printLabel(CargoLabel label) async {
    if (printing) return false;
    printing = true;
    printingIndex = labels.indexOf(label);
    notifyListeners();
    try {
      final ok = await NtbpPlugin.printCargoLabel(label, config: config, logo: _activeLogo);
      _say(ok ? 'Sent ${label.bookingReference} to the printer' : 'Print failed');
      return ok;
    } catch (e) {
      _say('Print failed: ${_friendly(e)}');
      return false;
    } finally {
      printing = false;
      printingIndex = -1;
      notifyListeners();
      unawaited(refreshStatus());
    }
  }

  Future<PrintBatchResult?> printAll() async {
    if (printing || labels.isEmpty) return null;
    printing = true;
    printingIndex = 0;
    lastBatch = null;
    notifyListeners();
    try {
      final result = await NtbpPlugin.printCargoLabels(
        List.of(labels),
        config: config,
        logo: _activeLogo,
      );
      lastBatch = result;
      if (result.success) {
        _say('Printed ${result.printed} of ${result.total} labels');
      } else {
        final why = result.stoppedBy?.description;
        _say('Printed ${result.printed} of ${result.total}'
            '${why != null ? '. Stopped: $why' : ''}');
      }
      return result;
    } catch (e) {
      _say('Series print failed: ${_friendly(e)}');
      return null;
    } finally {
      printing = false;
      printingIndex = -1;
      notifyListeners();
      unawaited(refreshStatus());
    }
  }

  // ===========================================================================
  // Labels and settings
  // ===========================================================================

  void setConfig(LabelPrintConfig value) {
    config = value;
    notifyListeners();
  }

  void addLabel(CargoLabel label) {
    labels.add(label);
    notifyListeners();
  }

  void updateLabel(int index, CargoLabel label) {
    if (index < 0 || index >= labels.length) return;
    labels[index] = label;
    notifyListeners();
  }

  void removeLabel(int index) {
    if (index < 0 || index >= labels.length) return;
    labels.removeAt(index);
    notifyListeners();
  }

  void duplicateLabel(int index) {
    if (index < 0 || index >= labels.length) return;
    final src = labels[index];
    labels.insert(index + 1, src.copyWith(
      item: CargoLabel.generateReference(src.bookingReference, labels.length + 1),
      package: _bumpPackage(src.package, labels.length + 1),
    ));
    notifyListeners();
  }

  /// [to] is the index after removal (ReorderableListView.onReorderItem).
  void moveLabel(int from, int to) {
    if (from == to) return;
    final item = labels.removeAt(from);
    labels.insert(to.clamp(0, labels.length), item);
    notifyListeners();
  }

  void clearLabels() {
    labels.clear();
    notifyListeners();
  }

  void loadSampleLabels() {
    labels
      ..clear()
      ..addAll(List.generate(3, (i) => sampleLabel(index: i + 1, total: 3)));
    notifyListeners();
  }

  static CargoLabel sampleLabel({int index = 1, int total = 1}) {
    return CargoLabel(
      brandName: 'BM Coach',
      bookingReference: 'BK-1025',
      item: CargoLabel.generateReference('BK-1025', index),
      cargoName: const ['Spare parts (engine)', 'Cartons of textiles', 'Solar panels, 2 pcs'][(index - 1) % 3],
      sender: const ['Otapp Agency Limited', 'Tel: +255 712 345 678'],
      receiver: const ['John Mwakyusa', 'Tel: +255 765 432 109'],
      destination: 'DAR ES SALAAM',
      weight: '5.0 KG',
      package: '$index / $total',
      source: 'MWANZA',
      date: '2025-10-19',
    );
  }

  /// "1 / 5" -> "2 / 5", "ITEM-001 / 5" -> "ITEM-002 / 5". Leaves other
  /// strings alone.
  static String _bumpPackage(String value, int fallback) {
    final m = RegExp(r'^(.*?)(\d+)(\s*/\s*\d+)?$').firstMatch(value.trim());
    if (m == null) return value;
    final n = int.parse(m.group(2)!);
    final width = m.group(2)!.length;
    return '${m.group(1)}${(n + 1).toString().padLeft(width, '0')}${m.group(3) ?? ''}';
  }

  static String _friendly(Object e) {
    final s = e.toString();
    final m = RegExp(r'PlatformException\((\w+), ([^,]+),').firstMatch(s);
    if (m != null) return m.group(2)!;
    return s;
  }
}

/// Makes a [PrinterController] available to the widget tree and rebuilds
/// dependents when it notifies.
class PrinterScope extends InheritedNotifier<PrinterController> {
  const PrinterScope({
    super.key,
    required PrinterController controller,
    required super.child,
  }) : super(notifier: controller);

  static PrinterController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PrinterScope>();
    assert(scope != null, 'PrinterScope not found above this widget');
    return scope!.notifier!;
  }
}
