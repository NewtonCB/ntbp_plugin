import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

/// Create or edit one [CargoLabel]. Pops with the label, or null on cancel.
class LabelFormScreen extends StatefulWidget {
  const LabelFormScreen({super.key, this.initial, this.suggestedIndex = 1, this.suggestedTotal = 1});

  final CargoLabel? initial;
  final int suggestedIndex;
  final int suggestedTotal;

  static Future<CargoLabel?> open(
    BuildContext context, {
    CargoLabel? initial,
    int suggestedIndex = 1,
    int suggestedTotal = 1,
  }) {
    return Navigator.of(context).push<CargoLabel>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LabelFormScreen(
        initial: initial,
        suggestedIndex: suggestedIndex,
        suggestedTotal: suggestedTotal,
      ),
    ));
  }

  @override
  State<LabelFormScreen> createState() => _LabelFormScreenState();
}

class _LabelFormScreenState extends State<LabelFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brand;
  late final TextEditingController _booking;
  late final TextEditingController _item;
  late final TextEditingController _cargoName;
  late final TextEditingController _date;
  late final TextEditingController _source;
  late final TextEditingController _destination;
  late final TextEditingController _weight;
  late final TextEditingController _package;
  late final List<TextEditingController> _sender;
  late final List<TextEditingController> _receiver;
  late final TextEditingController _customQr;
  late CargoQrContent _qrContent;

  /// True while the item reference follows the booking reference
  /// automatically (until the user edits it by hand).
  bool _autoItem = true;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final idx = widget.suggestedIndex;
    final total = widget.suggestedTotal;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');

    _brand = TextEditingController(text: i?.brandName ?? 'BM Coach');
    _booking = TextEditingController(text: i?.bookingReference ?? '');
    _item = TextEditingController(
        text: i?.item ?? CargoLabel.generateReference(i?.bookingReference ?? '', idx));
    _cargoName = TextEditingController(text: i?.cargoName ?? '');
    _date = TextEditingController(text: i?.date ?? '${now.year}-${two(now.month)}-${two(now.day)}');
    _source = TextEditingController(text: i?.source ?? '');
    _destination = TextEditingController(text: i?.destination ?? '');
    _weight = TextEditingController(text: i?.weight ?? '');
    _package = TextEditingController(text: i?.package ?? '$idx / $total');
    _sender = List.generate(2, (k) => TextEditingController(text: _line(i?.sender, k)));
    _receiver = List.generate(2, (k) => TextEditingController(text: _line(i?.receiver, k)));
    _customQr = TextEditingController(text: i?.qrData ?? '');
    _qrContent = i?.qrContent ?? CargoQrContent.summary;
    _autoItem = i == null ||
        i.item == CargoLabel.generateReference(i.bookingReference, idx);

    _booking.addListener(_syncItemReference);
  }

  void _syncItemReference() {
    if (!_autoItem) return;
    final generated = CargoLabel.generateReference(_booking.text, widget.suggestedIndex);
    if (_item.text != generated) {
      _item.value = _item.value.copyWith(
        text: generated,
        selection: TextSelection.collapsed(offset: generated.length),
      );
    }
  }

  static String _line(List<String>? lines, int k) =>
      (lines != null && k < lines.length) ? lines[k] : '';

  @override
  void dispose() {
    _booking.removeListener(_syncItemReference);
    for (final c in [
      _brand, _booking, _item, _cargoName, _date, _source, _destination, _weight, _package, _customQr,
      ..._sender, ..._receiver,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the highlighted fields')),
      );
      return;
    }
    List<String> lines(List<TextEditingController> cs) =>
        cs.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    final label = CargoLabel(
      brandName: _brand.text.trim(),
      bookingReference: _booking.text.trim(),
      item: _item.text.trim(),
      cargoName: _cargoName.text.trim(),
      date: _date.text.trim(),
      source: _source.text.trim(),
      destination: _destination.text.trim(),
      weight: _weight.text.trim(),
      package: _package.text.trim(),
      sender: lines(_sender),
      receiver: lines(_receiver),
      qrContent: _qrContent,
      qrData: _qrContent == CargoQrContent.custom ? _customQr.text.trim() : null,
    );
    Navigator.of(context).pop(label);
  }

  Future<void> _pickDate() async {
    final parsed = DateTime.tryParse(_date.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      String two(int v) => v.toString().padLeft(2, '0');
      setState(() => _date.text = '${picked.year}-${two(picked.month)}-${two(picked.day)}');
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit label' : 'New label'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(width: 6),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Section(
              icon: Icons.local_shipping_rounded,
              title: 'Shipment',
              children: [
                _Field(
                  controller: _brand,
                  label: 'Brand name',
                  hint: 'Printed top left, opposite the logo',
                  prefixIcon: Icons.business_rounded,
                ),
                _Field(controller: _booking, label: 'Booking reference', validator: _required,
                    textCapitalization: TextCapitalization.characters, hint: 'BK-1025'),
                _Field(
                  controller: _item,
                  label: 'Item reference',
                  validator: _required,
                  textCapitalization: TextCapitalization.characters,
                  hint: 'BK1025-001',
                  prefixIcon: Icons.qr_code_scanner_rounded,
                  helper: 'Generated from the booking reference. Printed at the top of the label.',
                  onChanged: (_) => _autoItem = false,
                  suffix: IconButton(
                    tooltip: 'Regenerate',
                    icon: const Icon(Icons.autorenew_rounded, size: 20),
                    onPressed: () {
                      _autoItem = true;
                      _syncItemReference();
                    },
                  ),
                ),
                _Field(
                  controller: _cargoName,
                  label: 'Cargo name',
                  validator: _required,
                  hint: 'Spare parts (engine)',
                  prefixIcon: Icons.inventory_rounded,
                  helper: 'Printed large in the box at the bottom of the label.',
                ),
                _Field(
                  controller: _date,
                  label: 'Date',
                  readOnly: true,
                  onTap: _pickDate,
                  prefixIcon: Icons.event_rounded,
                ),
              ],
            ),
            _Section(
              icon: Icons.outbox_rounded,
              title: 'Sender',
              children: [
                _Field(controller: _sender[0], label: 'Name / company', validator: _required),
                _Field(controller: _sender[1], label: 'Phone', keyboardType: TextInputType.phone,
                    hint: 'Tel: +255 ...', prefixIcon: Icons.phone_rounded),
              ],
            ),
            _Section(
              icon: Icons.move_to_inbox_rounded,
              title: 'Receiver',
              children: [
                _Field(controller: _receiver[0], label: 'Name', validator: _required),
                _Field(controller: _receiver[1], label: 'Phone', keyboardType: TextInputType.phone,
                    hint: 'Tel: +255 ...', prefixIcon: Icons.phone_rounded),
              ],
            ),
            _Section(
              icon: Icons.inventory_2_rounded,
              title: 'Package',
              children: [
                _Row2(
                  _Field(controller: _source, label: 'Source', validator: _required,
                      textCapitalization: TextCapitalization.characters, hint: 'MWANZA'),
                  _Field(controller: _destination, label: 'Destination', validator: _required,
                      textCapitalization: TextCapitalization.characters, hint: 'DAR ES SALAAM'),
                ),
                _Row2(
                  _Field(controller: _weight, label: 'Weight', hint: '5.0 KG'),
                  _Field(controller: _package, label: 'Package', hint: '1 / 5'),
                ),
              ],
            ),
            _Section(
              icon: Icons.qr_code_2_rounded,
              title: 'QR code',
              children: [
                SegmentedButton<CargoQrContent>(
                  segments: const [
                    ButtonSegment(value: CargoQrContent.summary, label: Text('Summary'), icon: Icon(Icons.article_outlined)),
                    ButtonSegment(value: CargoQrContent.itemReference, label: Text('Item ref'), icon: Icon(Icons.tag)),
                    ButtonSegment(value: CargoQrContent.custom, label: Text('Custom'), icon: Icon(Icons.link)),
                  ],
                  selected: {_qrContent},
                  onSelectionChanged: (s) => setState(() => _qrContent = s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 10),
                if (_qrContent == CargoQrContent.custom)
                  _Field(controller: _customQr, label: 'QR payload', hint: 'https://... or any text', maxLines: 3)
                else
                  Text(
                    _qrContent == CargoQrContent.summary
                        ? 'Scanning the QR shows the shipment details as text: booking, item, cargo name, sender, receiver, source, destination, weight, package and date.'
                        : 'Scanning the QR shows only the item reference.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_editing ? 'Save changes' : 'Add to series'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    )),
              ],
            ),
          ),
          ...children.expand((w) => [w, const SizedBox(height: 10)]).toList()..removeLast(),
        ],
      ),
    );
  }
}

class _Row2 extends StatelessWidget {
  const _Row2(this.a, this.b);
  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.readOnly = false,
    this.onTap,
    this.prefixIcon,
    this.maxLines = 1,
    this.helper,
    this.suffix,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final int maxLines;
  final String? helper;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffix,
      ),
    );
  }
}
