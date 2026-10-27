import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../state/printer_controller.dart';

/// Opens the Bluetooth printer picker as a smooth_sheets modal sheet.
/// Starts a scan immediately. Resolves to true when a printer connected.
Future<bool?> showDeviceSheet(BuildContext context) {
  final controller = PrinterScope.of(context);
  final route = ModalSheetRoute<bool>(
    swipeDismissible: true,
    builder: (_) => PrinterScope(controller: controller, child: const _DeviceSheet()),
  );
  return Navigator.of(context, rootNavigator: true).push(route);
}

class _DeviceSheet extends StatefulWidget {
  const _DeviceSheet();

  @override
  State<_DeviceSheet> createState() => _DeviceSheetState();
}

class _DeviceSheetState extends State<_DeviceSheet> {
  String? _connectingAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = PrinterScope.of(context);
      if (!c.scanning) c.scan();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _connect(BluetoothDevice device) async {
    final c = PrinterScope.of(context);
    setState(() => _connectingAddress = device.address);
    await c.stopScan();
    final ok = await c.connect(device);
    if (!mounted) return;
    setState(() => _connectingAddress = null);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(c.connectionError ?? 'Could not connect to ${device.name}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PrinterScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final devices = c.devices;

    return Sheet(
      decoration: MaterialSheetDecoration(
        size: SheetSize.fit,
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        elevation: 8,
      ),
      snapGrid: const SheetSnapGrid(snaps: [SheetOffset(0.62), SheetOffset(1)]),
      scrollConfiguration: const SheetScrollConfiguration(),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bluetooth printers',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          c.scanning
                              ? 'Scanning… printers appear as they are found'
                              : devices.isEmpty
                                  ? 'No printers found. Make sure the XP-420B is on.'
                                  : '${devices.length} device${devices.length == 1 ? '' : 's'} found',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Scan again',
                    onPressed: c.scanning ? null : c.scan,
                    icon: c.scanning
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            if (c.scanning)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: LinearProgressIndicator(minHeight: 3, borderRadius: BorderRadius.all(Radius.circular(2))),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: devices.isEmpty
                  ? _EmptyState(scanning: c.scanning)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final d = devices[i];
                        final isConnected = c.connected?.address == d.address;
                        final isConnecting = _connectingAddress == d.address;
                        return _DeviceTile(
                          device: d,
                          connected: isConnected,
                          connecting: isConnecting,
                          enabled: _connectingAddress == null && !isConnected,
                          onTap: () => _connect(d),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.connected,
    required this.connecting,
    required this.enabled,
    required this.onTap,
  });
  final BluetoothDevice device;
  final bool connected;
  final bool connecting;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final printerLike = _isPrinter(device.name);
    return Material(
      color: connected ? scheme.primaryContainer.withValues(alpha: 0.5) : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: printerLike ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  printerLike ? Icons.print_rounded : Icons.bluetooth_rounded,
                  color: printerLike ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name.isEmpty ? 'Unknown device' : device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(device.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (connecting)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else if (connected)
                Icon(Icons.check_circle_rounded, color: scheme.primary)
              else
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isPrinter(String name) {
    final n = name.toLowerCase();
    return n.contains('xp') || n.contains('print') || n.contains('n41') || n.contains('label');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scanning});
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(scanning ? Icons.bluetooth_searching_rounded : Icons.bluetooth_disabled_rounded,
                size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              scanning ? 'Looking for printers…' : 'Nothing found yet',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              scanning
                  ? 'Keep the printer close to the phone.'
                  : 'Turn the printer on, then tap the refresh button.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
