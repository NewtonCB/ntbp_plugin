import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

/// Label size, gap, darkness and copies. Pops with the new config or null.
class MediaSettingsScreen extends StatefulWidget {
  const MediaSettingsScreen({
    super.key,
    required this.initial,
    this.printLogo = true,
    this.hasLogo = false,
    this.onPrintLogoChanged,
  });
  final LabelPrintConfig initial;
  final bool printLogo;
  final bool hasLogo;
  final ValueChanged<bool>? onPrintLogoChanged;

  static Future<LabelPrintConfig?> open(
    BuildContext context,
    LabelPrintConfig initial, {
    bool printLogo = true,
    bool hasLogo = false,
    ValueChanged<bool>? onPrintLogoChanged,
  }) {
    return Navigator.of(context).push<LabelPrintConfig>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MediaSettingsScreen(
        initial: initial,
        printLogo: printLogo,
        hasLogo: hasLogo,
        onPrintLogoChanged: onPrintLogoChanged,
      ),
    ));
  }

  @override
  State<MediaSettingsScreen> createState() => _MediaSettingsScreenState();
}

class _MediaSettingsScreenState extends State<MediaSettingsScreen> {
  late final TextEditingController _width;
  late final TextEditingController _height;
  late final TextEditingController _gap;
  late int _copies;
  late int _density;
  late bool _blackMark;
  late bool _rotated;
  late bool _printLogo;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _width = TextEditingController(text: _fmt(c.widthMm));
    _height = TextEditingController(text: _fmt(c.heightMm));
    _gap = TextEditingController(text: _fmt(c.gapMm));
    _copies = c.copies;
    _density = c.density ?? 8;
    _blackMark = c.blackMark;
    _rotated = c.direction == 1;
    _printLogo = widget.printLogo;
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _gap.dispose();
    super.dispose();
  }

  void _save() {
    final config = widget.initial.copyWith(
      widthMm: double.tryParse(_width.text) ?? widget.initial.widthMm,
      heightMm: double.tryParse(_height.text) ?? widget.initial.heightMm,
      gapMm: double.tryParse(_gap.text) ?? widget.initial.gapMm,
      copies: _copies,
      density: _density,
      blackMark: _blackMark,
      direction: _rotated ? 1 : 0,
    );
    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media settings'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        actions: [TextButton(onPressed: _save, child: const Text('Save')), const SizedBox(width: 6)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Group(
            title: 'Label size',
            subtitle: 'The XP-420B prints up to 108 mm wide. The cargo layout is designed for 100 x 150 mm.',
            child: Row(
              children: [
                Expanded(child: _NumberField(controller: _width, label: 'Width', suffix: 'mm')),
                const SizedBox(width: 10),
                Expanded(child: _NumberField(controller: _height, label: 'Height', suffix: 'mm')),
              ],
            ),
          ),
          _Group(
            title: 'Media sensing',
            subtitle: 'Gap between die-cut labels, or the black mark height. Run Calibrate once after loading a roll.',
            child: Column(
              children: [
                _NumberField(controller: _gap, label: _blackMark ? 'Black mark height' : 'Gap', suffix: 'mm'),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Black mark paper'),
                  subtitle: const Text('Use BLINE instead of GAP sensing'),
                  value: _blackMark,
                  onChanged: (v) => setState(() => _blackMark = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rotate 180°'),
                  subtitle: const Text('If labels come out upside down'),
                  value: _rotated,
                  onChanged: (v) => setState(() => _rotated = v),
                ),
              ],
            ),
          ),
          _Group(
            title: 'Logo',
            subtitle: widget.hasLogo
                ? 'Printed centred at the top of every label.'
                : 'No logo loaded (assets/logo.png missing).',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Print logo'),
              value: _printLogo && widget.hasLogo,
              onChanged: widget.hasLogo
                  ? (v) {
                      setState(() => _printLogo = v);
                      widget.onPrintLogoChanged?.call(v);
                    }
                  : null,
            ),
          ),
          _Group(
            title: 'Darkness',
            subtitle: 'Higher is darker. 8 to 10 suits most thermal label stock.',
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _density.toDouble(),
                    min: 0,
                    max: 15,
                    divisions: 15,
                    label: '$_density',
                    onChanged: (v) => setState(() => _density = v.round()),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('$_density',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
          ),
          _Group(
            title: 'Copies per label',
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Text('$_copies',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                ),
                IconButton.filledTonal(
                  onPressed: _copies < 20 ? () => setState(() => _copies++) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: const Text('Save settings')),
          const SizedBox(height: 12),
          Text(
            'Tip: use Calibrate on the home screen after changing the roll so the printer learns the exact gap.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ).withBottomGap();
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label, this.suffix});
  final TextEditingController controller;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

extension on Widget {
  Widget withBottomGap() => Padding(padding: const EdgeInsets.only(bottom: 12), child: this);
}
