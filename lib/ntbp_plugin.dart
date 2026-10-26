export 'ntbp_plugin_platform_interface.dart';
export 'ntbp_plugin_method_channel.dart';
export 'models/bluetooth_device.dart';
export 'models/print_command.dart';
export 'models/printer_status.dart';
export 'src/protocols.dart';
export 'src/tspl.dart';

import 'ntbp_plugin_platform_interface.dart';
import 'models/bluetooth_device.dart';
import 'models/print_command.dart';
import 'models/printer_status.dart';
import 'src/protocols/protocol_manager.dart';
import 'src/tspl/cargo_label.dart';
import 'src/tspl/label_print_config.dart';
import 'src/tspl/three_line_label.dart';
import 'src/tspl/tspl_builder.dart';

/// Thermal Bluetooth label printing for TSPL printers (Xprinter XP-420B,
/// N41 and compatible).
///
/// Label layouts are rendered to TSPL in Dart (see [CargoLabelLayout] and
/// [ThreeLineQrLayout]) so Android and iOS print identical output. The native
/// side only transports bytes and answers status queries.
class NtbpPlugin {
  static final ProtocolManager _protocolManager = ProtocolManager();

  static NtbpPluginPlatform get _platform => NtbpPluginPlatform.instance;

  // ===========================================================================
  // Cargo shipment labels (XP-420B)
  // ===========================================================================

  /// Prints one cargo shipment label.
  ///
  /// [config] describes the media (size, gap, darkness, copies). Call
  /// [calibrateGap] once when a new roll is loaded; it is not needed before
  /// every print.
  static Future<bool> printCargoLabel(
    CargoLabel label, {
    LabelPrintConfig config = const LabelPrintConfig(),
  }) {
    return sendTspl(CargoLabelLayout.buildJob(label, config));
  }

  /// Prints a series of cargo labels back to back.
  ///
  /// Each label is a separate job. When [waitForPrinter] is true the plugin
  /// polls the printer status between labels and stops at the first error
  /// (out of paper, head open, jam) so the remaining labels are not lost in
  /// the buffer. Returns which labels were printed.
  static Future<PrintBatchResult> printCargoLabels(
    List<CargoLabel> labels, {
    LabelPrintConfig config = const LabelPrintConfig(),
    bool waitForPrinter = true,
    Duration perLabelTimeout = const Duration(seconds: 15),
  }) {
    return _printSeries(
      labels.map((l) => CargoLabelLayout.buildJob(l, config)).toList(),
      config: config,
      waitForPrinter: waitForPrinter,
      perLabelTimeout: perLabelTimeout,
    );
  }

  /// Returns the TSPL that [printCargoLabel] would send. Handy for debugging
  /// a layout without a printer.
  static String previewCargoLabel(
    CargoLabel label, {
    LabelPrintConfig config = const LabelPrintConfig(),
  }) {
    return CargoLabelLayout.buildJob(label, config);
  }

  // ===========================================================================
  // Raw TSPL, calibration and status
  // ===========================================================================

  /// Sends a TSPL script verbatim. Lines should end with CRLF; [TsplBuilder]
  /// produces the right format.
  static Future<bool> sendTspl(String script) {
    return _platform.sendProtocolCommands(script.codeUnits, 'TSPL');
  }

  /// Sends raw bytes to the printer.
  static Future<bool> sendBytes(List<int> bytes) {
    return _platform.sendProtocolCommands(bytes, 'RAW');
  }

  /// Runs the printer's gap sensor calibration. The printer feeds two or
  /// three labels to measure the label length and gap. Do this once after
  /// loading a new roll, not before each print.
  static Future<bool> calibrateGap() {
    return sendTspl(TsplBuilder().gapDetect().build());
  }

  /// Runs automatic media calibration (gap or black mark).
  static Future<bool> autoCalibrate() {
    return sendTspl(TsplBuilder().autoDetect().build());
  }

  /// Runs black-mark sensor calibration.
  static Future<bool> calibrateBlackMark() {
    return sendTspl(TsplBuilder().blineDetect().build());
  }

  /// Feeds one blank label so the next print starts at a label boundary.
  static Future<bool> formFeed() {
    return sendTspl(TsplBuilder().formFeed().build());
  }

  /// Asks the printer for its current status.
  static Future<PrinterStatus> queryPrinterStatus({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final code = await _platform.queryPrinterStatus(
      timeoutMs: timeout.inMilliseconds,
    );
    return PrinterStatus(code);
  }

  /// Waits until the printer reports that it is no longer printing.
  ///
  /// Returns the final status. If the printer never answers, returns
  /// [PrinterStatus.noResponse] after [timeout].
  static Future<PrinterStatus> waitUntilIdle({
    Duration timeout = const Duration(seconds: 15),
    Duration pollInterval = const Duration(milliseconds: 300),
  }) async {
    final deadline = DateTime.now().add(timeout);
    PrinterStatus status = PrinterStatus.noResponse;
    while (DateTime.now().isBefore(deadline)) {
      status = await queryPrinterStatus();
      if (!status.responded) return status;
      if (!status.isPrinting) return status;
      await Future.delayed(pollInterval);
    }
    return status;
  }

  static Future<PrintBatchResult> _printSeries(
    List<String> jobs, {
    required LabelPrintConfig config,
    required bool waitForPrinter,
    required Duration perLabelTimeout,
  }) async {
    final failed = <int>[];
    var printed = 0;
    PrinterStatus? stoppedBy;

    // Without status feedback fall back to a time budget per label.
    final fallbackDelay =
        Duration(milliseconds: 600 + 900 * config.copies.clamp(1, 50));

    for (var i = 0; i < jobs.length; i++) {
      final sent = await sendTspl(jobs[i]);
      if (!sent) {
        failed.add(i);
        continue;
      }

      if (!waitForPrinter) {
        printed++;
        continue;
      }

      // Give the printer a moment to start before polling.
      await Future.delayed(const Duration(milliseconds: 200));
      final status = await waitUntilIdle(timeout: perLabelTimeout);

      if (!status.responded) {
        // Printer does not answer status queries; use timing instead.
        await Future.delayed(fallbackDelay);
        printed++;
        continue;
      }

      if (status.hasError) {
        failed.addAll(List.generate(jobs.length - i, (k) => i + k));
        stoppedBy = status;
        break;
      }
      printed++;
    }

    return PrintBatchResult(
      total: jobs.length,
      printed: printed,
      failedIndexes: failed,
      stoppedBy: stoppedBy,
    );
  }

  // ===========================================================================
  // Three-line QR labels (v2 API, unchanged signatures)
  // ===========================================================================

  /// Print single label with gap detection and proper positioning.
  ///
  /// Kept for backward compatibility. The layout is now rendered in Dart by
  /// [ThreeLineQrLayout], so it behaves the same on Android and iOS. The
  /// media gap can be tuned with [gapMm] (default 3 mm).
  static Future<bool> printSingleLabelWithGapDetection({
    required String qrData,
    required String textData1, // Customer name
    required String textData2, // Drop point
    required String textData3, // Additional info
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copies,
    int? textSize,
    double gapMm = 3,
  }) {
    final config = _legacyConfig(width, height, unit, dpi, copies ?? 1, gapMm);
    final label = ThreeLineQrLabel(
      qrData: qrData,
      line1: textData1,
      line2: textData2,
      line3: textData3,
    );
    return sendTspl(ThreeLineQrLayout.buildJob(
      label,
      config,
      textFont: (textSize ?? 9).toString(),
    ));
  }

  /// Print multiple labels with different content and proper gap detection.
  ///
  /// Each entry of [labelDataList] is a map with `qrData`, `textData1`,
  /// `textData2`, `textData3`. Returns true only if every label printed.
  static Future<bool> printMultipleLabelsWithGapDetection({
    required List<Map<String, dynamic>> labelDataList,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copiesPerLabel,
    int? textSize,
    double gapMm = 3,
    bool waitForPrinter = true,
  }) async {
    if (labelDataList.isEmpty) return false;
    final config =
        _legacyConfig(width, height, unit, dpi, copiesPerLabel ?? 1, gapMm);
    final font = (textSize ?? 9).toString();
    final jobs = <String>[];
    for (var i = 0; i < labelDataList.length; i++) {
      final label = ThreeLineQrLabel.fromMap(labelDataList[i], index: i);
      jobs.add(ThreeLineQrLayout.buildJob(label, config, textFont: font));
    }
    final result = await _printSeries(
      jobs,
      config: config,
      waitForPrinter: waitForPrinter,
      perLabelTimeout: const Duration(seconds: 15),
    );
    return result.success;
  }

  static LabelPrintConfig _legacyConfig(
    double width,
    double height,
    String? unit,
    int? dpi,
    int copies,
    double gapMm,
  ) {
    final u = (unit ?? 'mm').toLowerCase();
    final resolution = dpi ?? 203;
    double toMm(double v) {
      switch (u) {
        case 'inch':
          return v * 25.4;
        case 'dot':
          return v * 25.4 / resolution;
        default:
          return v;
      }
    }

    return LabelPrintConfig(
      widthMm: toMm(width),
      heightMm: toMm(height),
      dpi: resolution,
      gapMm: gapMm,
      copies: copies,
    );
  }

  // ===========================================================================
  // Protocol system (Dart-side TSPL/ESC-POS abstraction)
  // ===========================================================================

  /// Get the protocol manager instance
  static ProtocolManager get protocolManager => _protocolManager;

  /// Initialize protocol for a specific printer model
  static Future<bool> initializeProtocol(String printerModel) {
    return _protocolManager.initializeProtocol(printerModel);
  }

  /// Auto-detect and initialize protocol
  static Future<bool> autoDetectProtocol({
    String? deviceName,
    String? deviceAddress,
    Map<String, dynamic>? deviceProperties,
  }) {
    return _protocolManager.autoDetectProtocol(
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      deviceProperties: deviceProperties,
    );
  }

  /// Get current protocol information
  static Map<String, dynamic> getProtocolInfo() {
    return {
      'isInitialized': _protocolManager.isProtocolInitialized,
      'currentProtocol': _protocolManager.currentProtocol?.protocolName,
      'currentPrinterModel': _protocolManager.currentPrinterModel,
      'capabilities': _protocolManager.getProtocolCapabilities(),
    };
  }

  /// Get all supported printer models
  static List<String> getSupportedPrinterModels() {
    return _protocolManager.getSupportedPrinterModels();
  }

  /// Check if a printer model is supported
  static bool isPrinterSupported(String printerModel) {
    return _protocolManager.isPrinterSupported(printerModel);
  }

  /// Print single label using protocol system
  static Future<bool> printSingleLabelWithProtocol({
    required String qrData,
    required String textData,
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int copies,
    required int textSize,
  }) {
    return _protocolManager.printSingleLabel(
      qrData: qrData,
      textData: textData,
      labelWidth: labelWidth,
      labelHeight: labelHeight,
      unit: unit,
      dpi: dpi,
      copies: copies,
      textSize: textSize,
    );
  }

  /// Print multiple labels using protocol system
  static Future<bool> printMultipleLabelsWithProtocol({
    required List<Map<String, dynamic>> labelDataList,
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int copiesPerLabel,
    required int textSize,
  }) {
    return _protocolManager.printMultipleLabels(
      labelDataList: labelDataList,
      labelWidth: labelWidth,
      labelHeight: labelHeight,
      unit: unit,
      dpi: dpi,
      copiesPerLabel: copiesPerLabel,
      textSize: textSize,
    );
  }

  /// Initialize printer using protocol system
  static Future<bool> initializePrinterWithProtocol({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) {
    return _protocolManager.initializePrinter(
      labelWidth: labelWidth,
      labelHeight: labelHeight,
      unit: unit,
      dpi: dpi,
    );
  }

  /// Clear buffer using protocol system
  static Future<bool> clearBufferWithProtocol() {
    return _protocolManager.clearBuffer();
  }

  /// Get printer status using protocol system
  static Future<Map<String, dynamic>> getPrinterStatusWithProtocol() {
    return _protocolManager.getPrinterStatus();
  }

  /// Feed paper using protocol system
  static Future<bool> feedPaperWithProtocol() {
    return _protocolManager.feedPaper();
  }

  /// Send gap detection commands using protocol system
  static Future<bool> sendGapDetectionCommandsWithProtocol({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) {
    return _protocolManager.sendGapDetectionCommands(
      labelWidth: labelWidth,
      labelHeight: labelHeight,
      unit: unit,
      dpi: dpi,
    );
  }

  /// Reset protocol manager
  static void resetProtocol() {
    _protocolManager.reset();
  }

  // ===========================================================================
  // Bluetooth connection (instance API, unchanged)
  // ===========================================================================

  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  /// Check if Bluetooth is available on the device
  Future<bool> isBluetoothAvailable() {
    return _platform.isBluetoothAvailable();
  }

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermissions() {
    return _platform.requestBluetoothPermissions();
  }

  /// Check device pairing status
  Future<String> checkDevicePairingStatus(String address) {
    return _platform.checkDevicePairingStatus(address);
  }

  /// Request device pairing
  Future<String> requestDevicePairing(String address) {
    return _platform.requestDevicePairing(address);
  }

  /// Request device pairing with PIN code
  Future<String> requestDevicePairingWithPin(String address, String pinCode) {
    return _platform.requestDevicePairingWithPin(address, pinCode);
  }

  /// Get stored PIN code for a device
  Future<String?> getStoredPinCode(String address) {
    return _platform.getStoredPinCode(address);
  }

  /// Remove stored PIN code for a device
  Future<bool> removeStoredPinCode(String address) {
    return _platform.removeStoredPinCode(address);
  }

  /// Start scanning for Bluetooth devices. Completes when the scan window
  /// has ended; call [getDiscoveredDevices] afterwards.
  Future<void> startScan() {
    return _platform.startScan();
  }

  /// Stop scanning for Bluetooth devices
  Future<void> stopScan() {
    return _platform.stopScan();
  }

  /// Get list of discovered devices
  Future<List<BluetoothDevice>> getDiscoveredDevices() {
    return _platform.getDiscoveredDevices();
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(BluetoothDevice device) {
    return _platform.connectToDevice(device);
  }

  /// Disconnect from current device
  Future<bool> disconnect() {
    return _platform.disconnect();
  }

  /// Check if connected to a device
  Future<bool> isConnected() {
    return _platform.isConnected();
  }

  /// Get connection status
  Future<String> getConnectionStatus() {
    return _platform.getConnectionStatus();
  }

  /// Get detailed connection status for debugging
  Future<Map<String, dynamic>> getDetailedConnectionStatus() {
    return _platform.getDetailedConnectionStatus();
  }

  /// Get printer status as a map (see [PrinterStatus.toMap]).
  Future<Map<String, dynamic>> getPrinterStatus() async {
    final status = await queryPrinterStatus();
    return status.toMap();
  }

  /// Clear the print buffer (TSPL `CLS`).
  Future<bool> clearBuffer() {
    return sendTspl(TsplBuilder().cls().build());
  }

  /// Feed paper by the given number of dots.
  Future<bool> feedPaper(int dots) {
    return sendTspl(TsplBuilder().feed(dots).build());
  }

  // ===========================================================================
  // Legacy simple printing (instance API, unchanged)
  // ===========================================================================

  /// Print text or commands
  Future<bool> print(List<PrintCommand> commands) {
    return _platform.print(commands);
  }

  /// Print a simple text string
  Future<bool> printText(String text) {
    return _platform.printText(text);
  }

  /// Print a barcode
  Future<bool> printBarcode(String data) {
    return _platform.printBarcode(data);
  }

  /// Print a QR code
  Future<bool> printQRCode(String data) {
    return _platform.printQRCode(data);
  }

  Future<bool> printTextAdvanced(
    String text, {
    double? x,
    double? y,
    int? fontNumber,
    String? codePage,
    int? rotation,
    double? xMultiplication,
    double? yMultiplication,
  }) {
    return _platform.printTextAdvanced(
      text,
      x: x,
      y: y,
      fontNumber: fontNumber,
      codePage: codePage,
      rotation: rotation,
      xMultiplication: xMultiplication,
      yMultiplication: yMultiplication,
    );
  }

  Future<bool> printBarcodeAdvanced(
    String data, {
    double? x,
    double? y,
    int? rotation,
    String? codePage,
  }) {
    return _platform.printBarcodeAdvanced(
      data,
      x: x,
      y: y,
      rotation: rotation,
      codePage: codePage,
    );
  }

  Future<bool> printQRCodeAdvanced(
    String data, {
    double? x,
    double? y,
    String? size,
    String? errorCorrection,
    String? model,
    int? rotation,
  }) {
    return _platform.printQRCodeAdvanced(
      data,
      x: x,
      y: y,
      size: size,
      errorCorrection: errorCorrection,
      model: model,
      rotation: rotation,
    );
  }

  Future<bool> printImage(
    String imagePath, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return _platform.printImage(
      imagePath,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  Future<bool> printBlock(
    String text, {
    double? x,
    double? y,
    double? width,
    double? height,
    int? lineWidth,
    int? lineStyle,
  }) {
    return _platform.printBlock(
      text,
      x: x,
      y: y,
      width: width,
      height: height,
      lineWidth: lineWidth,
      lineStyle: lineStyle,
    );
  }

  Future<bool> setPrintArea(double width, double height) {
    return _platform.setPrintArea(width, height);
  }

  Future<bool> clearPrintBuffer() {
    return _platform.clearPrintBuffer();
  }

  Future<bool> executePrint(int copies, int labels) {
    return _platform.executePrint(copies, labels);
  }

  /// Print barcode with text below it in one operation
  Future<bool> printBarcodeWithText(
    String barcodeData,
    String textData, {
    double? x,
    double? y,
    int? barcodeHeight,
    int? textFont,
    double? textScale,
  }) {
    return _platform.printBarcodeWithText(
      barcodeData,
      textData,
      x: x,
      y: y,
      barcodeHeight: barcodeHeight,
      textFont: textFont,
      textScale: textScale,
    );
  }

  /// Print professional label with QR code and text positioning
  Future<bool> printProfessionalLabel({
    required String qrData,
    required String textData,
    required double labelWidth,
    required double labelHeight,
    String? labelUnit,
    int? dpi,
    int? copies,
    String? speedMode,
  }) {
    return _platform.printProfessionalLabel(
      qrData: qrData,
      textData: textData,
      labelWidth: labelWidth,
      labelHeight: labelHeight,
      labelUnit: labelUnit,
      dpi: dpi,
      copies: copies,
      speedMode: speedMode,
    );
  }

  /// Print sequence of labels from backend data
  Future<bool> printLabelSequence(List<Map<String, dynamic>> labelDataList) {
    return _platform.printLabelSequence(labelDataList);
  }

  /// Get label paper configuration for specific dimensions
  Future<Map<String, dynamic>> getLabelPaperConfig(
      double width, double height, String unit) {
    return _platform.getLabelPaperConfig(width, height, unit);
  }

  /// Print custom label with user-defined dimensions and sizes
  Future<bool> printCustomLabel({
    required String qrData,
    required String textData,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    double? qrSize,
    double? textSize,
  }) {
    return _platform.printCustomLabel(
      qrData: qrData,
      textData: textData,
      width: width,
      height: height,
      unit: unit,
      dpi: dpi,
      qrSize: qrSize,
      textSize: textSize,
    );
  }

  /// Print a smart label with automatic gap detection and positioning
  static Future<bool> printSmartLabel({
    required String qrData,
    required String textData,
    required double width,
    required double height,
    required String unit,
    required int dpi,
  }) {
    return _platform.printSmartLabel({
      'qrData': qrData,
      'textData': textData,
      'width': width,
      'height': height,
      'unit': unit,
      'dpi': dpi,
    });
  }

  /// Print a sequence of smart labels with gap detection
  static Future<bool> printSmartSequence(
      List<Map<String, dynamic>> labelDataList) {
    return _platform.printSmartSequence(labelDataList);
  }
}
