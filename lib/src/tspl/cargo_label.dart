import 'label_print_config.dart';
import 'logo_bitmap.dart';
import 'tspl_builder.dart';

/// What the QR code on a [CargoLabel] encodes.
enum CargoQrContent {
  /// A human readable summary of the shipment (default). Any phone camera
  /// shows it as text when scanned. See [CargoLabel.summaryText].
  summary,

  /// Only the item reference.
  itemReference,

  /// The value of [CargoLabel.qrData] verbatim.
  custom,
}

/// Content of a cargo shipment label.
///
/// The layout (see [CargoLabelLayout]) is:
///
/// ```
/// BRAND NAME               [LOGO]
/// ──────────────────────────────
/// BOOKING REFERENCE        ┌────┐
/// BK-1025                  │ QR │
/// ITEM                     │    │
/// BK1025-001               └────┘
/// ┌────────────────────────────┐
/// │ SENDER   name / phone      │
/// ├────────────────────────────┤
/// │ RECEIVER name / phone      │
/// ├──────────┬────────┬────────┤
/// │DESTINAT. │ WEIGHT │PACKAGE │
/// ├──────────┴───┬────┴────────┤
/// │ SOURCE       │ DATE        │
/// ├──────────────┴─────────────┤
/// │ CARGO NAME                 │
/// │ Spare parts (engine)       │
/// └────────────────────────────┘
/// ```
///
/// Use [generateReference] to create item references.
class CargoLabel {
  /// Company or brand name printed at the top left, opposite the logo.
  final String brandName;

  final String bookingReference;

  /// Item reference, e.g. `BK1025-001`, printed at the top.
  final String item;

  /// What the cargo is, e.g. `Spare parts (engine)`. Printed in the box at
  /// the bottom of the label.
  final String cargoName;

  /// Selects what the QR code encodes. Defaults to [CargoQrContent.summary].
  final CargoQrContent qrContent;

  /// Custom QR payload, used when [qrContent] is [CargoQrContent.custom].
  final String? qrData;

  /// Sender name and phone. Only the first two entries are printed.
  final List<String> sender;

  /// Receiver name and phone. Only the first two entries are printed.
  final List<String> receiver;

  final String destination;
  final String weight;
  final String package;

  /// Where the cargo comes from.
  final String source;
  final String date;

  // Captions. Override to localise.
  final String bookingReferenceCaption;
  final String itemCaption;
  final String senderCaption;
  final String receiverCaption;
  final String destinationCaption;
  final String weightCaption;
  final String packageCaption;
  final String sourceCaption;
  final String dateCaption;
  final String cargoNameCaption;

  const CargoLabel({
    this.brandName = '',
    required this.bookingReference,
    required this.item,
    this.cargoName = '',
    this.qrContent = CargoQrContent.summary,
    this.qrData,
    required this.sender,
    required this.receiver,
    required this.destination,
    required this.weight,
    required this.package,
    required this.source,
    required this.date,
    this.bookingReferenceCaption = 'BOOKING REFERENCE',
    this.itemCaption = 'ITEM',
    this.senderCaption = 'SENDER',
    this.receiverCaption = 'RECEIVER',
    this.destinationCaption = 'DESTINATION',
    this.weightCaption = 'WEIGHT',
    this.packageCaption = 'PACKAGE',
    this.sourceCaption = 'SOURCE',
    this.dateCaption = 'DATE',
    this.cargoNameCaption = 'CARGO NAME',
  });

  /// Builds an item reference from the booking reference and a running
  /// number, e.g. `BK-1025` + 1 → `BK1025-001`. Only letters and digits of
  /// the booking reference are kept so the result scans cleanly as Code 128.
  static String generateReference(String bookingReference, int index, {int digits = 3}) {
    final base = bookingReference.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final prefix = base.isEmpty ? 'ITEM' : base;
    return '$prefix-${index.toString().padLeft(digits, '0')}';
  }

  String get senderName => sender.isNotEmpty ? sender[0] : '';
  String get senderPhone => sender.length > 1 ? sender[1] : '';
  String get receiverName => receiver.isNotEmpty ? receiver[0] : '';
  String get receiverPhone => receiver.length > 1 ? receiver[1] : '';

  /// The text actually encoded in the QR code.
  String get effectiveQrData {
    switch (qrContent) {
      case CargoQrContent.itemReference:
        return item;
      case CargoQrContent.custom:
        return (qrData == null || qrData!.isEmpty) ? item : qrData!;
      case CargoQrContent.summary:
        if (qrData != null && qrData!.isNotEmpty) return qrData!;
        return summaryText();
    }
  }

  /// Human readable summary of the shipment. This is what a phone shows
  /// after scanning the QR code.
  ///
  /// TSPL cannot carry line breaks inside a quoted string, so the fields are
  /// joined with [separator].
  String summaryText({String separator = ' | '}) {
    String join(List<String> lines) =>
        lines.where((l) => l.trim().isNotEmpty).map((l) => l.trim()).join(', ');
    final parts = <String>[
      '$bookingReferenceCaption: $bookingReference',
      '$itemCaption: $item',
      if (cargoName.trim().isNotEmpty) '$cargoNameCaption: $cargoName',
      if (sender.isNotEmpty) '$senderCaption: ${join(sender)}',
      if (receiver.isNotEmpty) '$receiverCaption: ${join(receiver)}',
      '$sourceCaption: $source',
      '$destinationCaption: $destination',
      '$weightCaption: $weight',
      '$packageCaption: $package',
      '$dateCaption: $date',
    ];
    return parts.map((p) => p.replaceAll('\n', ' ')).join(separator);
  }

  factory CargoLabel.fromMap(Map<String, dynamic> map) {
    List<String> lines(dynamic value) {
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String) return value.split('\n');
      return const [];
    }

    return CargoLabel(
      brandName: map['brandName'] as String? ?? '',
      bookingReference: map['bookingReference'] as String? ?? '',
      item: map['item'] as String? ?? '',
      cargoName: map['cargoName'] as String? ?? '',
      qrContent: CargoQrContent.values.firstWhere(
        (v) => v.name == map['qrContent'],
        orElse: () => CargoQrContent.summary,
      ),
      qrData: map['qrData'] as String?,
      sender: lines(map['sender']),
      receiver: lines(map['receiver']),
      destination: map['destination'] as String? ?? '',
      weight: map['weight'] as String? ?? '',
      package: map['package'] as String? ?? '',
      source: map['source'] as String? ?? map['serviceType'] as String? ?? '',
      date: map['date'] as String? ?? '',
      bookingReferenceCaption:
          map['bookingReferenceCaption'] as String? ?? 'BOOKING REFERENCE',
      itemCaption: map['itemCaption'] as String? ?? 'ITEM',
      senderCaption: map['senderCaption'] as String? ?? 'SENDER',
      receiverCaption: map['receiverCaption'] as String? ?? 'RECEIVER',
      destinationCaption: map['destinationCaption'] as String? ?? 'DESTINATION',
      weightCaption: map['weightCaption'] as String? ?? 'WEIGHT',
      packageCaption: map['packageCaption'] as String? ?? 'PACKAGE',
      sourceCaption: map['sourceCaption'] as String? ?? 'SOURCE',
      dateCaption: map['dateCaption'] as String? ?? 'DATE',
      cargoNameCaption: map['cargoNameCaption'] as String? ?? 'CARGO NAME',
    );
  }

  Map<String, dynamic> toMap() => {
        'brandName': brandName,
        'bookingReference': bookingReference,
        'item': item,
        'cargoName': cargoName,
        'qrContent': qrContent.name,
        'qrData': qrData,
        'sender': sender,
        'receiver': receiver,
        'destination': destination,
        'weight': weight,
        'package': package,
        'source': source,
        'date': date,
        'bookingReferenceCaption': bookingReferenceCaption,
        'itemCaption': itemCaption,
        'senderCaption': senderCaption,
        'receiverCaption': receiverCaption,
        'destinationCaption': destinationCaption,
        'weightCaption': weightCaption,
        'packageCaption': packageCaption,
        'sourceCaption': sourceCaption,
        'dateCaption': dateCaption,
        'cargoNameCaption': cargoNameCaption,
      };

  CargoLabel copyWith({
    String? brandName,
    String? bookingReference,
    String? item,
    String? cargoName,
    CargoQrContent? qrContent,
    String? qrData,
    List<String>? sender,
    List<String>? receiver,
    String? destination,
    String? weight,
    String? package,
    String? source,
    String? date,
  }) {
    return CargoLabel.fromMap({
      ...toMap(),
      if (brandName != null) 'brandName': brandName,
      if (bookingReference != null) 'bookingReference': bookingReference,
      if (item != null) 'item': item,
      if (cargoName != null) 'cargoName': cargoName,
      if (qrContent != null) 'qrContent': qrContent.name,
      if (qrData != null) 'qrData': qrData,
      if (sender != null) 'sender': sender,
      if (receiver != null) 'receiver': receiver,
      if (destination != null) 'destination': destination,
      if (weight != null) 'weight': weight,
      if (package != null) 'package': package,
      if (source != null) 'source': source,
      if (date != null) 'date': date,
    });
  }

  @override
  String toString() => 'CargoLabel($bookingReference, $item)';
}

/// Converts a [CargoLabel] into TSPL commands.
///
/// The geometry is defined on a reference grid of 800 x 1200 dots (a 100 x
/// 150 mm label at 203 dpi) and scaled to the actual label size. Fonts are
/// the printer's built-in bitmap fonts, chosen per field so the text fits
/// its cell.
class CargoLabelLayout {
  CargoLabelLayout._();

  static const double _refWidth = 800;
  static const double _refHeight = 1200;

  /// Maximum logo box on the reference grid, in dots. The logo sits at the
  /// right of the header band, the brand name at the left.
  static const int logoMaxWidth = 360;
  static const int logoMaxHeight = 110;

  /// Full print job: header, content and PRINT command. [logo] is printed
  /// at the top right, opposite [CargoLabel.brandName].
  static String buildJob(CargoLabel label, LabelPrintConfig config, {CargoLogo? logo}) {
    final b = TsplBuilder();
    config.writeHeader(b);
    writeContent(b, label, config, logo: logo);
    b.print(copies: config.copies);
    return b.build();
  }

  /// Only the drawing commands, so callers can compose their own job.
  static void writeContent(
    TsplBuilder b,
    CargoLabel label,
    LabelPrintConfig config, {
    CargoLogo? logo,
  }) {
    final sx = config.widthDots / _refWidth;
    final sy = config.heightDots / _refHeight;
    int x(num v) => (v * sx).round();
    int y(num v) => (v * sy).round();

    const left = 40;
    const right = 760;
    const contentWidth = right - left;
    const centreX = (left + right) / 2;
    final thickness = (3 * sx).round().clamp(2, 6);
    const captionFont = TsplFont.f12x20;

    // --- Header band: brand name (left) and logo (right), then a rule -----
    const logoTop = 36;
    const logoBottom = logoTop + logoMaxHeight;
    final bandMidY = y(logoTop) + y(logoMaxHeight) ~/ 2;
    var brandMaxWidth = x(contentWidth);
    if (logo != null) {
      final mono = logo.toMono(maxWidth: x(logoMaxWidth), maxHeight: y(logoMaxHeight));
      final lx = x(right) - mono.width;
      final ly = bandMidY - mono.height ~/ 2;
      b.bitmap(lx, ly, mono);
      brandMaxWidth = lx - x(left) - x(24);
    }
    final brand = label.brandName.trim();
    if (brand.isNotEmpty && brandMaxWidth > 0) {
      final brandFont = TsplFont.fit(brand, brandMaxWidth);
      final brandText = TsplFont.clip(brandFont, brand, brandMaxWidth);
      b.text(x(left), bandMidY - TsplFont.charHeight(brandFont) ~/ 2, brandFont, brandText);
    }
    b.bar(x(left), y(logoBottom + 14), x(contentWidth), (3 * sy).round().clamp(2, 6));

    // --- QR code (right) ------------------------------------------------
    const topBlock = logoBottom + 40; // 186
    final qrData = label.effectiveQrData;
    final qrModules = _qrModules(qrData);
    final qrTarget = y(236);
    final cell = (qrTarget ~/ qrModules).clamp(3, 10);
    final qrSize = cell * qrModules;
    final qrX = x(right) - qrSize;
    b.qrCode(qrX, y(topBlock), qrData, ecLevel: 'M', cellWidth: cell);

    // --- Booking reference and item (left) ------------------------------
    final leftColWidth = qrX - x(left) - x(16);

    b.text(x(left), y(topBlock + 4), captionFont,
        TsplFont.clip(captionFont, label.bookingReferenceCaption, leftColWidth));
    final bookingFont = TsplFont.fit(label.bookingReference, leftColWidth);
    b.text(x(left), y(topBlock + 34), bookingFont,
        TsplFont.clip(bookingFont, label.bookingReference, leftColWidth));

    b.text(x(left), y(topBlock + 118), captionFont,
        TsplFont.clip(captionFont, label.itemCaption, leftColWidth));
    final itemFont = TsplFont.fit(label.item, leftColWidth);
    b.text(x(left), y(topBlock + 148), itemFont,
        TsplFont.clip(itemFont, label.item, leftColWidth));

    // --- Sender / receiver boxes ----------------------------------------
    const senderTop = 440;
    const boxHeight = 130;
    _partyBox(b, x, y, thickness,
        top: senderTop,
        bottom: senderTop + boxHeight,
        caption: label.senderCaption,
        name: label.senderName,
        phone: label.senderPhone);
    _partyBox(b, x, y, thickness,
        top: senderTop + boxHeight,
        bottom: senderTop + 2 * boxHeight,
        caption: label.receiverCaption,
        name: label.receiverName,
        phone: label.receiverPhone);

    // --- Row 1: destination | weight | package ---------------------------
    const row1Top = senderTop + 2 * boxHeight; // 700
    const row1Bottom = row1Top + 112;
    const row1Cols = [left, 420, 600, right];
    final row1 = [
      (label.destinationCaption, label.destination),
      (label.weightCaption, label.weight),
      (label.packageCaption, label.package),
    ];
    for (var i = 0; i < row1.length; i++) {
      _cell(b, x, y, thickness,
          x1: row1Cols[i],
          x2: row1Cols[i + 1],
          top: row1Top,
          bottom: row1Bottom,
          caption: row1[i].$1,
          value: row1[i].$2,
          captionY: row1Top + 16,
          valueY: row1Top + 46,
          preferred: TsplFont.f32x48);
    }

    // --- Row 2: source | date -------------------------------------------
    const row2Top = row1Bottom; // 812
    const row2Bottom = row2Top + 93;
    const row2Cols = [left, 455, right];
    final row2 = [
      (label.sourceCaption, label.source),
      (label.dateCaption, label.date),
    ];
    for (var i = 0; i < row2.length; i++) {
      _cell(b, x, y, thickness,
          x1: row2Cols[i],
          x2: row2Cols[i + 1],
          top: row2Top,
          bottom: row2Bottom,
          caption: row2[i].$1,
          value: row2[i].$2,
          captionY: row2Top + 16,
          valueY: row2Top + 46,
          preferred: TsplFont.f24x32);
    }

    // --- Cargo name box -------------------------------------------------
    const nameTop = row2Bottom; // 905
    const nameBottom = 1160;
    _cargoNameBox(b, x, y, thickness,
        top: nameTop,
        bottom: nameBottom,
        caption: label.cargoNameCaption,
        name: label.cargoName);
  }

  /// Caption plus the cargo name in the largest font that fits, wrapping to
  /// two or three lines when necessary.
  static void _cargoNameBox(
    TsplBuilder b,
    int Function(num) x,
    int Function(num) y,
    int thickness, {
    required int top,
    required int bottom,
    required String caption,
    required String name,
  }) {
    const left = 40;
    const right = 760;
    const pad = 16;
    final innerWidth = x(right - left - 2 * pad);

    b.box(x(left), y(top), x(right), y(bottom), thickness: thickness);
    b.text(x(left + pad), y(top + 16), TsplFont.f12x20,
        TsplFont.clip(TsplFont.f12x20, caption, innerWidth));

    final text = name.trim();
    if (text.isEmpty) return;

    // Candidate (font, max lines, line pitch on the reference grid).
    const candidates = [
      (TsplFont.f32x48, 1, 0),
      (TsplFont.f24x32, 1, 0),
      (TsplFont.f24x32, 2, 44),
      (TsplFont.f16x24, 3, 34),
      (TsplFont.f12x20, 4, 28),
    ];
    for (final (font, maxLines, pitch) in candidates) {
      final lines = wrapText(text, innerWidth ~/ TsplFont.charWidth(font));
      if (lines.length > maxLines) continue;
      for (var i = 0; i < lines.length; i++) {
        b.text(x(left + pad), y(top + 50 + i * pitch), font, lines[i]);
      }
      return;
    }
    // Longer than every candidate allows: print what fits in the smallest.
    final lines = wrapText(text, innerWidth ~/ TsplFont.charWidth(TsplFont.f12x20)).take(4).toList();
    for (var i = 0; i < lines.length; i++) {
      b.text(x(left + pad), y(top + 50 + i * 28), TsplFont.f12x20, lines[i]);
    }
  }

  /// Greedy word wrap to at most [maxChars] per line. Words longer than a
  /// line are split.
  static List<String> wrapText(String text, int maxChars) {
    if (maxChars <= 0) return [text];
    final lines = <String>[];
    var current = StringBuffer();
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      var w = word;
      while (w.length > maxChars) {
        if (current.isNotEmpty) {
          lines.add(current.toString());
          current = StringBuffer();
        }
        lines.add(w.substring(0, maxChars));
        w = w.substring(maxChars);
      }
      final candidate = current.isEmpty ? w : '${current.toString()} $w';
      if (candidate.length <= maxChars) {
        current = StringBuffer(candidate);
      } else {
        lines.add(current.toString());
        current = StringBuffer(w);
      }
    }
    if (current.isNotEmpty) lines.add(current.toString());
    return lines;
  }

  static void _partyBox(
    TsplBuilder b,
    int Function(num) x,
    int Function(num) y,
    int thickness, {
    required int top,
    required int bottom,
    required String caption,
    required String name,
    required String phone,
  }) {
    const left = 40;
    const right = 760;
    const pad = 16;
    final innerWidth = x(right - left - 2 * pad);

    b.box(x(left), y(top), x(right), y(bottom), thickness: thickness);
    b.text(x(left + pad), y(top + 14), TsplFont.f12x20,
        TsplFont.clip(TsplFont.f12x20, caption, innerWidth));
    if (name.trim().isNotEmpty) {
      final font = TsplFont.fit(name, innerWidth, preferred: TsplFont.f24x32);
      b.text(x(left + pad), y(top + 42), font, TsplFont.clip(font, name, innerWidth));
    }
    if (phone.trim().isNotEmpty) {
      b.text(x(left + pad), y(top + 86), TsplFont.f16x24,
          TsplFont.clip(TsplFont.f16x24, phone, innerWidth));
    }
  }

  static void _cell(
    TsplBuilder b,
    int Function(num) x,
    int Function(num) y,
    int thickness, {
    required int x1,
    required int x2,
    required int top,
    required int bottom,
    required String caption,
    required String value,
    required int captionY,
    required int valueY,
    required String preferred,
  }) {
    const pad = 16;
    final innerWidth = x(x2 - x1 - 2 * pad);
    b.box(x(x1), y(top), x(x2), y(bottom), thickness: thickness);
    b.text(x(x1 + pad), y(captionY), TsplFont.f12x20,
        TsplFont.clip(TsplFont.f12x20, caption, innerWidth));
    final font = TsplFont.fit(value, innerWidth, preferred: preferred);
    b.text(x(x1 + pad), y(valueY), font, TsplFont.clip(font, value, innerWidth));
  }

  /// Number of modules on one side of a QR code able to hold [data] in
  /// byte mode at error correction level M. Byte mode is the conservative
  /// choice, so the real symbol is never larger than estimated.
  static int _qrModules(String data) {
    const capacities = [
      14, 26, 42, 62, 84, 106, 122, 152, 180, 213, // v1..v10
      251, 287, 331, 362, 412, 450, 504, 560, 624, 666, // v11..v20
    ];
    final bytes = data.codeUnits.length;
    for (var v = 0; v < capacities.length; v++) {
      if (bytes <= capacities[v]) return 17 + 4 * (v + 1);
    }
    return 17 + 4 * capacities.length;
  }
}
