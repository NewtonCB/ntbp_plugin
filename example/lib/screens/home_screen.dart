import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

import '../state/printer_controller.dart';
import '../widgets/label_card.dart';
import '../widgets/printer_status_card.dart';
import 'label_form_screen.dart';
import 'media_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PrinterScope.of(context).syncConnection();
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addLabel() async {
    final c = PrinterScope.of(context);
    final label = await LabelFormScreen.open(
      context,
      suggestedIndex: c.labels.length + 1,
      suggestedTotal: c.labels.length + 1,
    );
    if (label != null) c.addLabel(label);
  }

  Future<void> _onLabelAction(int index, LabelAction action) async {
    final c = PrinterScope.of(context);
    final label = c.labels[index];
    switch (action) {
      case LabelAction.edit:
        final edited = await LabelFormScreen.open(context, initial: label);
        if (edited != null) c.updateLabel(index, edited);
      case LabelAction.duplicate:
        c.duplicateLabel(index);
      case LabelAction.delete:
        c.removeLabel(index);
        _toast('Removed ${label.bookingReference}');
      case LabelAction.preview:
        await _showTspl(label);
      case LabelAction.print:
        if (!c.isConnected) {
          _toast('Connect a printer first');
          return;
        }
        final ok = await c.printLabel(label);
        _toast(ok ? 'Sent ${label.bookingReference} to the printer' : (c.lastMessage ?? 'Print failed'));
    }
  }

  Future<void> _printAll() async {
    final c = PrinterScope.of(context);
    final result = await c.printAll();
    if (!mounted) return;
    if (result == null) {
      _toast(c.lastMessage ?? 'Print failed');
    } else if (result.success) {
      _toast('Printed ${result.printed} label${result.printed == 1 ? '' : 's'}');
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
          title: const Text('Series stopped'),
          content: Text(
            '${result.printed} of ${result.total} labels printed.'
            '${result.stoppedBy != null ? '\n\nPrinter reported: ${result.stoppedBy!.description}.' : ''}'
            '\n\nFix the printer and print the remaining labels again.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _showTspl(CargoLabel label) async {
    final c = PrinterScope.of(context);
    final tspl = NtbpPlugin.previewCargoLabel(label, config: c.config, logo: c.printLogo ? c.logo : null);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TSPL preview'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(tspl, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: tspl));
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    final c = PrinterScope.of(context);
    final updated = await MediaSettingsScreen.open(
      context,
      c.config,
      printLogo: c.printLogo,
      hasLogo: c.logo != null,
      onPrintLogoChanged: c.setPrintLogo,
    );
    if (updated != null) c.setConfig(updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = PrinterScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final labels = c.labels;
    final canPrint = c.isConnected && labels.isNotEmpty && !c.printing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Label Printer'),
        actions: [
          IconButton(
            tooltip: 'Media settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'samples':
                  c.loadSampleLabels();
                case 'clear':
                  c.clearLabels();
                case 'feed':
                  c.formFeed();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'samples', child: Text('Load sample labels')),
              const PopupMenuItem(value: 'clear', child: Text('Clear all labels')),
              PopupMenuItem(value: 'feed', enabled: c.isConnected, child: const Text('Feed one label')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          const PrinterStatusCard(),
          const SizedBox(height: 20),
          _MediaSummary(config: c.config, onTap: _openSettings),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: Row(
              children: [
                Text('Labels in series',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${labels.length}',
                      style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addLabel,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          if (labels.isEmpty)
            _EmptyLabels(onAdd: _addLabel, onSamples: c.loadSampleLabels)
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: labels.length,
              onReorderItem: c.moveLabel,
              proxyDecorator: (child, _, __) => Material(color: Colors.transparent, child: child),
              itemBuilder: (context, i) => Padding(
                key: ValueKey('label-$i-${labels[i].item}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: ReorderableDelayedDragStartListener(
                  index: i,
                  child: LabelCard(
                    index: i,
                    label: labels[i],
                    busy: c.printing && c.printingIndex == i,
                    enabled: !c.printing,
                    onAction: (a) => _onLabelAction(i, a),
                  ),
                ),
              ),
            ),
          if (labels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text('Hold and drag a card to reorder. Tap a card to edit it.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Tooltip(
                message: 'New label',
                child: OutlinedButton(
                  onPressed: c.printing ? null : _addLabel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(54, 50),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.add_rounded, size: 26),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canPrint ? _printAll : null,
                  icon: c.printing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print_rounded),
                  label: Text(
                    c.printing
                        ? 'Printing ${c.printingIndex + 1}/${labels.length}…'
                        : !c.isConnected
                            ? 'Connect printer'
                            : labels.isEmpty
                                ? 'Print'
                                : 'Print ${labels.length}'
                                    '${c.config.copies > 1 ? ' × ${c.config.copies}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _MediaSummary extends StatelessWidget {
  const _MediaSummary({required this.config, required this.onTap});
  final LabelPrintConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    final items = <(IconData, String)>[
      (Icons.crop_portrait_rounded, '${n(config.widthMm)} × ${n(config.heightMm)} mm'),
      (config.blackMark ? Icons.horizontal_rule_rounded : Icons.space_bar_rounded,
          '${config.blackMark ? 'Mark' : 'Gap'} ${n(config.gapMm)} mm'),
      (Icons.contrast_rounded, 'Darkness ${config.density ?? 'auto'}'),
      (Icons.copy_all_rounded, '${config.copies} cop${config.copies == 1 ? 'y' : 'ies'}'),
    ];
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final (icon, text) in items)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: scheme.primary),
                          const SizedBox(width: 5),
                          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLabels extends StatelessWidget {
  const _EmptyLabels({required this.onAdd, required this.onSamples});
  final VoidCallback onAdd;
  final VoidCallback onSamples;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(Icons.label_outline_rounded, size: 44, color: scheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            const Text('No labels yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Add labels with different shipment data, then print them all in one series.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(onPressed: onSamples, child: const Text('Load samples')),
                const SizedBox(width: 10),
                FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('New label')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
