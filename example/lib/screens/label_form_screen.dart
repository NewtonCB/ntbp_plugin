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

  late final TextEditingController _title;
  late final TextEditingController _booking;
  late final TextEditingController _item;
  late final TextEditingController _tracking;
  late final TextEditingController _date;
  late final TextEditingController _service;
  late final TextEditingController _destination;
  late final TextEditingController _weight;
  late final TextEditingController _package;
  late final List<TextEditingController> _sender;
  late final List<TextEditingController> _receiver;
  late final TextEditingController _customQr;
  late CargoQrContent _qrContent;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final idx = widget.suggestedIndex;
    final total = widget.suggestedTotal;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');

    _title = TextEditingController(text: i?.title ?? 'CARGO SHIPMENT');
    _booking = TextEditingController(text: i?.bookingReference ?? '');
    _item = TextEditingController(text: i?.item ?? 'ITEM-${idx.toString().padLeft(3, '0')} / $total');
    _tracking = TextEditingController(text: i?.trackingNumber ?? '');
    _date = TextEditingController(text: i?.date ?? '${now.year}-${two(now.month)}-${two(now.day)}');
    _service = TextEditingController(text: i?.serviceType ?? 'Standard');
    _destination = TextEditingController(text: i?.destination ?? '');
    _weight = TextEditingController(text: i?.weight ?? '');
    _package = TextEditingController(text: i?.package ?? '$idx / $total');
    _sender = List.generate(4, (k) => TextEditingController(text: _line(i?.sender, k)));
    _receiver = List.generate(4, (k) => TextEditingController(text: _line(i?.receiver, k)));
    _customQr = TextEditingController(text: i?.qrData ?? '');
    _qrContent = i?.qrContent ?? CargoQrContent.summary;
  }

  static String _line(List<String>? lines, int k) =>
      (lines != null && k < lines.length) ? lines[k] : '';

  @override
  void dispose() {
    for (final c in [
      _title, _booking, _item, _tracking, _date, _service, _destination, _weight, _package, _customQr,
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
      title: _title.text.trim().isEmpty ? 'CARGO SHIPMENT' : _title.text.trim(),
      bookingReference: _booking.text.trim(),
      item: _item.text.trim(),
      trackingNumber: _tracking.text.trim(),
      date: _date.text.trim(),
      serviceType: _service.text.trim(),
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
                _Field(controller: _title, label: 'Title', textCapitalization: TextCapitalization.characters),
                _Row2(
                  _Field(controller: _booking, label: 'Booking reference', validator: _required,
                      textCapitalization: TextCapitalization.characters, hint: 'BK-1025'),
                  _Field(controller: _item, label: 'Item', validator: _required,
                      textCapitalization: TextCapitalization.characters, hint: 'ITEM-001 / 5'),
                ),
                _Field(
                  controller: _tracking,
                  label: 'Tracking number',
                  validator: _required,
                  keyboardType: TextInputType.number,
                  hint: 'Printed as Code 128 barcode',
                  prefixIcon: Icons.qr_code_scanner_rounded,
                ),
                _Row2(
                  _Field(
                    controller: _date,
                    label: 'Date',
                    readOnly: true,
                    onTap: _pickDate,
                    prefixIcon: Icons.event_rounded,
                  ),
                  _Field(controller: _service, label: 'Service type', hint: 'Standard'),
                ),
              ],
            ),
            _Section(
              icon: Icons.outbox_rounded,
              title: 'Sender',
              children: [
                _Field(controller: _sender[0], label: 'Name / company', validator: _required),
                _Field(controller: _sender[1], label: 'Address line'),
                _Field(controller: _sender[2], label: 'City, country'),
                _Field(controller: _sender[3], label: 'Phone', keyboardType: TextInputType.phone, hint: 'Tel: +255 ...'),
              ],
            ),
            _Section(
              icon: Icons.move_to_inbox_rounded,
              title: 'Receiver',
              children: [
                _Field(controller: _receiver[0], label: 'Name', validator: _required),
                _Field(controller: _receiver[1], label: 'Address line'),
                _Field(controller: _receiver[2], label: 'City, country'),
                _Field(controller: _receiver[3], label: 'Phone', keyboardType: TextInputType.phone, hint: 'Tel: +255 ...'),
              ],
            ),
            _Section(
              icon: Icons.inventory_2_rounded,
              title: 'Package',
              children: [
                _Field(controller: _destination, label: 'Destination', validator: _required,
                    textCapitalization: TextCapitalization.characters, hint: 'DAR ES SALAAM'),
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
                    ButtonSegment(value: CargoQrContent.trackingNumber, label: Text('Tracking'), icon: Icon(Icons.tag)),
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
                        ? 'Scanning the QR shows the shipment details as text: booking, item, sender, receiver, destination, weight, package, service, date and tracking number.'
                        : 'Scanning the QR shows only the tracking number.',
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      ),
    );
  }
}
