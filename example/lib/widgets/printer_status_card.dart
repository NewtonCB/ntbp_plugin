import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

import '../sheets/device_sheet.dart';
import '../state/printer_controller.dart';

/// Gradient header showing the connected printer, its live status and the
/// primary printer actions.
class PrinterStatusCard extends StatelessWidget {
  const PrinterStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = PrinterScope.of(context);
    final connected = c.connected;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: connected != null
              ? [const Color(0xFF1F4FD8), const Color(0xFF3B7BFF)]
              : [const Color(0xFF2E3A59), const Color(0xFF4A5878)],
        ),
        boxShadow: [
          BoxShadow(
            color: (connected != null ? const Color(0xFF1F4FD8) : Colors.black)
                .withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  connected != null ? Icons.print_rounded : Icons.print_disabled_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected?.name ?? 'No printer connected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      connected?.address ?? 'Tap Connect to find your XP-420B',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ConnectionPill(connected: connected != null, connecting: c.connecting),
            ],
          ),
          if (c.permission != BluetoothPermission.granted) ...[
            const SizedBox(height: 16),
            _PermissionBanner(state: c.permission, busy: c.requestingPermission, onGrant: c.requestPermissions),
          ],
          const SizedBox(height: 18),
          _StatusStrip(status: c.status, checkedAt: c.statusCheckedAt, checking: c.checkingStatus,
              connected: connected != null),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _HeaderButton(
                  icon: connected != null ? Icons.link_off_rounded : Icons.bluetooth_searching_rounded,
                  label: connected != null ? 'Disconnect' : 'Connect',
                  primary: connected == null,
                  onPressed: c.connecting
                      ? null
                      : () async {
                          if (connected != null) {
                            await c.disconnect();
                          } else {
                            await showDeviceSheet(context);
                          }
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _HeaderButton(
                  icon: Icons.refresh_rounded,
                  label: 'Status',
                  onPressed: connected == null || c.checkingStatus ? null : c.refreshStatus,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _HeaderButton(
                  icon: Icons.straighten_rounded,
                  label: 'Calibrate',
                  onPressed: connected == null
                      ? null
                      : () async {
                          final go = await _confirmCalibrate(context);
                          if (go == true) await c.calibrate();
                        },
                ),
              ),
            ],
          ),
          if (c.lastMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.lastMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<bool?> _confirmCalibrate(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calibrate gap sensor?'),
        content: const Text(
          'The printer will feed two or three blank labels to measure the label '
          'length and the gap. Do this once after loading a new roll.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Calibrate')),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.state, required this.busy, required this.onGrant});
  final BluetoothPermission state;
  final bool busy;
  final Future<bool> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    final blocked = state == BluetoothPermission.blocked;
    final title = blocked ? 'Bluetooth is blocked for this app' : 'Bluetooth permission needed';
    final body = blocked
        ? 'Open Settings and switch Bluetooth on for this app.'
        : state == BluetoothPermission.unknown
            ? 'Checking permission…'
            : 'Allow Bluetooth so the app can find and talk to the printer.';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC857).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_disabled_rounded, color: Color(0xFFFFC857), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : () => onGrant(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFC857),
              foregroundColor: const Color(0xFF2E3A59),
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            child: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(blocked ? 'Settings' : 'Grant'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.connected, required this.connecting});
  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final label = connecting ? 'Connecting' : connected ? 'Online' : 'Offline';
    final color = connecting
        ? const Color(0xFFFFC857)
        : connected
            ? const Color(0xFF4ADE80)
            : Colors.white.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connecting)
            const SizedBox(
              width: 8, height: 8,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
            )
          else
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.status,
    required this.checkedAt,
    required this.checking,
    required this.connected,
  });
  final PrinterStatus? status;
  final DateTime? checkedAt;
  final bool checking;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = _describe();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: checking
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRINTER STATUS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(text,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (checkedAt != null)
            Text(
              _timeAgo(checkedAt!),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5),
            ),
        ],
      ),
    );
  }

  (IconData, Color, String) _describe() {
    if (!connected) return (Icons.power_off_rounded, Colors.white70, 'Not connected');
    final s = status;
    if (s == null) return (Icons.help_outline_rounded, Colors.white70, 'Unknown, tap Status');
    if (s.code == -1) return (Icons.sensors_off_rounded, const Color(0xFFFFC857), 'No response');
    if (s.isReady) return (Icons.check_circle_rounded, const Color(0xFF4ADE80), 'Ready');
    if (s.isPrinting) return (Icons.print_rounded, const Color(0xFF7DD3FC), 'Printing');
    if (s.isPaused) return (Icons.pause_circle_rounded, const Color(0xFFFFC857), 'Paused');
    return (Icons.error_rounded, const Color(0xFFFF6B6B), s.description);
  }

  static String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 5) return 'just now';
    if (d.inMinutes < 1) return '${d.inSeconds}s ago';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: primary ? Colors.white : Colors.white.withValues(alpha: enabled ? 0.16 : 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18,
                  color: primary ? const Color(0xFF1F4FD8) : Colors.white.withValues(alpha: enabled ? 1 : 0.5)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary ? const Color(0xFF1F4FD8) : Colors.white.withValues(alpha: enabled ? 1 : 0.5),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
