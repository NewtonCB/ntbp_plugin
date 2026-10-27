import 'label_print_config.dart';
import 'tspl_builder.dart';

/// What the QR code on a [CargoLabel] encodes.
enum CargoQrContent {
  /// A human readable summary of the shipment (default). Any phone camera
  /// shows it as text when scanned. See [CargoLabel.summaryText].
  summary,

  /// Only the tracking number.
  trackingNumber,

  /// The value of [CargoLabel.qrData] verbatim.
  custom,
}

/// Content of a cargo shipment label.
///
/// The layout (see [CargoLabelLayout]) is:
///
/// ```
/// CARGO SHIPMENT
/// ──────────────────────────────
/// BOOKING REFERENCE        ┌────┐
/// BK-1025                  │ QR │
/// ITEM                     │    │
/// ITEM-001 / 5             └────┘
/// ┌────────────────────────────┐
/// │ SENDER  (up to 4 lines)    │
/// ├────────────────────────────┤
/// │ RECEIVER (up to 4 lines)   │
/// ├──────────┬────────┬────────┤
/// │DESTINAT. │ WEIGHT │PACKAGE │
/// ├──────────┴───┬────┴────────┤
/// │ SERVICE TYPE │ DATE        │
/// ├──────────────┴─────────────┤
/// │        ║║║ barcode ║║║     │
/// │        TRACKING NO.        │
/// │        123456789012        │
/// └────────────────────────────┘
/// ```
class CargoLabel {
  final String title;
  final String bookingReference;
  final String item;

  /// Selects what the QR code encodes. Defaults to [CargoQrContent.summary].
  final CargoQrContent qrContent;

  /// Custom QR payload, used when [qrContent] is [CargoQrContent.custom].
  /// For backward compatibility a non-empty [qrData] with the default
  /// [qrContent] is also used verbatim.
  final String? qrData;

  /// Sender block, first entry is normally the name. Up to four lines are
  /// printed.
  final List<String> sender;

  /// Receiver block, up to four lines are printed.
  final List<String> receiver;

  final String destination;
  final String weight;
  final String package;
  final String serviceType;
  final String date;

  /// Printed as a Code 128 barcode and as text underneath it.
  final String trackingNumber;

  // Captions. Override to localise.
  final String bookingReferenceCaption;
  final String itemCaption;
  final String senderCaption;
  final String receiverCaption;
  final String destinationCaption;
  final String weightCaption;
  final String packageCaption;
  final String serviceTypeCaption;
  final String dateCaption;
  final String trackingCaption;

  const CargoLabel({
    this.title = 'CARGO SHIPMENT',
    required this.bookingReference,
    required this.item,
    this.qrContent = CargoQrContent.summary,
    this.qrData,
    required this.sender,
    required this.receiver,
    required this.destination,
    required this.weight,
    required this.package,
    required this.serviceType,
    required this.date,
    required this.trackingNumber,
    this.bookingReferenceCaption = 'BOOKING REFERENCE',
    this.itemCaption = 'ITEM',
    this.senderCaption = 'SENDER',
    this.receiverCaption = 'RECEIVER',
    this.destinationCaption = 'DESTINATION',
    this.weightCaption = 'WEIGHT',
    this.packageCaption = 'PACKAGE',
    this.serviceTypeCaption = 'SERVICE TYPE',
    this.dateCaption = 'DATE',
    this.trackingCaption = 'TRACKING NO.',
  });

  /// The text actually encoded in the QR code.
  String get effectiveQrData {
    switch (qrContent) {
      case CargoQrContent.trackingNumber:
        return trackingNumber;
      case CargoQrContent.custom:
        return (qrData == null || qrData!.isEmpty) ? trackingNumber : qrData!;
      case CargoQrContent.summary:
        if (qrData != null && qrData!.isNotEmpty) return qrData!;
        return summaryText();
    }
  }

  /// Human readable summary of the shipment, one field per line. This is
  /// what a phone shows after scanning the QR code.
  ///
  /// TSPL cannot carry line breaks inside a quoted string, so when the text
  /// is encoded for the printer the lines are joined with [separator].
  String summaryText({String separator = ' | '}) {
    String join(List<String> lines) =>
        lines.where((l) => l.trim().isNotEmpty).map((l) => l.trim()).join(', ');
    final parts = <String>[
      title,
      '$bookingReferenceCaption: $bookingReference',
      '$itemCaption: $item',
      if (sender.isNotEmpty) '$senderCaption: ${join(sender)}',
      if (receiver.isNotEmpty) '$receiverCaption: ${join(receiver)}',
      '$destinationCaption: $destination',
      '$weightCaption: $weight',
      '$packageCaption: $package',
      '$serviceTypeCaption: $serviceType',
      '$dateCaption: $date',
      '$trackingCaption: $trackingNumber',
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
      title: map['title'] as String? ?? 'CARGO SHIPMENT',
      bookingReference: map['bookingReference'] as String? ?? '',
      item: map['item'] as String? ?? '',
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
      serviceType: map['serviceType'] as String? ?? '',
      date: map['date'] as String? ?? '',
      trackingNumber: map['trackingNumber'] as String? ?? '',
      bookingReferenceCaption:
          map['bookingReferenceCaption'] as String? ?? 'BOOKING REFERENCE',
      itemCaption: map['itemCaption'] as String? ?? 'ITEM',
      senderCaption: map['senderCaption'] as String? ?? 'SENDER',
      receiverCaption: map['receiverCaption'] as String? ?? 'RECEIVER',
      destinationCaption: map['destinationCaption'] as String? ?? 'DESTINATION',
      weightCaption: map['weightCaption'] as String? ?? 'WEIGHT',
      packageCaption: map['packageCaption'] as String? ?? 'PACKAGE',
      serviceTypeCaption: map['serviceTypeCaption'] as String? ?? 'SERVICE TYPE',
      dateCaption: map['dateCaption'] as String? ?? 'DATE',
      trackingCaption: map['trackingCaption'] as String? ?? 'TRACKING NO.',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'bookingReference': bookingReference,
        'item': item,
        'qrContent': qrContent.name,
        'qrData': qrData,
        'sender': sender,
        'receiver': receiver,
        'destination': destination,
        'weight': weight,
        'package': package,
        'serviceType': serviceType,
        'date': date,
        'trackingNumber': trackingNumber,
        'bookingReferenceCaption': bookingReferenceCaption,
        'itemCaption': itemCaption,
        'senderCaption': senderCaption,
        'receiverCaption': receiverCaption,
        'destinationCaption': destinationCaption,
        'weightCaption': weightCaption,
        'packageCaption': packageCaption,
        'serviceTypeCaption': serviceTypeCaption,
        'dateCaption': dateCaption,
        'trackingCaption': trackingCaption,
      };

  CargoLabel copyWith({
    String? title,
    String? bookingReference,
    String? item,
    CargoQrContent? qrContent,
    String? qrData,
    List<String>? sender,
    List<String>? receiver,
    String? destination,
    String? weight,
    String? package,
    String? serviceType,
    String? date,
    String? trackingNumber,
  }) {
    return CargoLabel.fromMap({
      ...toMap(),
      if (title != null) 'title': title,
      if (bookingReference != null) 'bookingReference': bookingReference,
      if (item != null) 'item': item,
      if (qrContent != null) 'qrContent': qrContent.name,
      if (qrData != null) 'qrData': qrData,
      if (sender != null) 'sender': sender,
      if (receiver != null) 'receiver': receiver,
      if (destination != null) 'destination': destination,
      if (weight != null) 'weight': weight,
      if (package != null) 'package': package,
      if (serviceType != null) 'serviceType': serviceType,
      if (date != null) 'date': date,
      if (trackingNumber != null) 'trackingNumber': trackingNumber,
    });
  }

  @override
  String toString() =>
      'CargoLabel($bookingReference, $item, $trackingNumber)';
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

  /// Full print job: header, content and PRINT command.
  static String buildJob(CargoLabel label, LabelPrintConfig config) {
    final b = TsplBuilder();
    config.writeHeader(b);
    writeContent(b, label, config);
    b.print(copies: config.copies);
    return b.build();
  }

  /// Only the drawing commands, so callers can compose their own job.
  static void writeContent(
    TsplBuilder b,
    CargoLabel label,
    LabelPrintConfig config,
  ) {
    final sx = config.widthDots / _refWidth;
    final sy = config.heightDots / _refHeight;
    int x(num v) => (v * sx).round();
    int y(num v) => (v * sy).round();

    const left = 40;
    const right = 760;
    const contentWidth = right - left;
    final thickness = (3 * sx).round().clamp(2, 6);

    // --- Title and rule -------------------------------------------------
    final titleFont = TsplFont.fit(label.title, x(contentWidth));
    b.text(x(left), y(48), titleFont, label.title);
    b.bar(x(left), y(110), x(contentWidth), (3 * sy).round().clamp(2, 6));

    // --- QR code (right) ------------------------------------------------
    final qrData = label.effectiveQrData;
    final qrModules = _qrModules(qrData);
    final qrTarget = y(236);
    final cell = (qrTarget ~/ qrModules).clamp(3, 10);
    final qrSize = cell * qrModules;
    final qrX = x(right) - qrSize;
    b.qrCode(qrX, y(136), qrData, ecLevel: 'M', cellWidth: cell);

    // --- Booking reference and item (left) ------------------------------
    final leftColWidth = qrX - x(left) - x(16);
    final captionFont = TsplFont.f12x20;

    b.text(x(left), y(140), captionFont,
        TsplFont.clip(captionFont, label.bookingReferenceCaption, leftColWidth));
    final bookingFont = TsplFont.fit(label.bookingReference, leftColWidth);
    b.text(x(left), y(170), bookingFont,
        TsplFont.clip(bookingFont, label.bookingReference, leftColWidth));

    b.text(x(left), y(254), captionFont,
        TsplFont.clip(captionFont, label.itemCaption, leftColWidth));
    final itemFont = TsplFont.fit(label.item, leftColWidth);
    b.text(x(left), y(284), itemFont,
        TsplFont.clip(itemFont, label.item, leftColWidth));

    // --- Sender / receiver boxes ----------------------------------------
    _addressBox(b, x, y, thickness,
        top: 376, bottom: 558, caption: label.senderCaption, lines: label.sender);
    _addressBox(b, x, y, thickness,
        top: 558, bottom: 736, caption: label.receiverCaption, lines: label.receiver);

    // --- Row 1: destination | weight | package ---------------------------
    const row1Top = 736;
    const row1Bottom = 844;
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
          captionY: 752,
          valueY: 782,
          preferred: TsplFont.f32x48);
    }

    // --- Row 2: service type | date -------------------------------------
    const row2Top = 844;
    const row2Bottom = 933;
    const row2Cols = [left, 455, right];
    final row2 = [
      (label.serviceTypeCaption, label.serviceType),
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
          captionY: 860,
          valueY: 890,
          preferred: TsplFont.f24x32);
    }

    // --- Barcode box ----------------------------------------------------
    const bcTop = 933;
    const bcBottom = 1150;
    b.box(x(left), y(bcTop), x(right), y(bcBottom), thickness: thickness);

    final tracking = label.trackingNumber;
    if (tracking.isNotEmpty) {
      final modules = _code128Modules(tracking);
      final maxBarWidth = x(640);
      final narrow = (maxBarWidth ~/ modules).clamp(2, 6);
      final barWidth = modules * narrow;
      final centre = x((left + right) / 2);
      b.barcode(centre - barWidth ~/ 2, y(950), tracking,
          type: '128', height: y(100), readable: 0, narrow: narrow, wide: narrow);
    }

    _centredText(b, centre: x((left + right) / 2), yPos: y(1064),
        font: captionFont, text: label.trackingCaption, maxWidth: x(688));
    final trackingFont = TsplFont.fit(tracking, x(688));
    _centredText(b, centre: x((left + right) / 2), yPos: y(1090),
        font: trackingFont, text: tracking, maxWidth: x(688));
  }

  static void _addressBox(
    TsplBuilder b,
    int Function(num) x,
    int Function(num) y,
    int thickness, {
    required int top,
    required int bottom,
    required String caption,
    required List<String> lines,
  }) {
    const left = 40;
    const right = 760;
    const pad = 16;
    const bodyFont = TsplFont.f16x24;
    final innerWidth = x(right - left - 2 * pad);

    b.box(x(left), y(top), x(right), y(bottom), thickness: thickness);
    b.text(x(left + pad), y(top + 14), bodyFont,
        TsplFont.clip(bodyFont, caption, innerWidth));

    final visible = lines.where((l) => l.trim().isNotEmpty).take(4).toList();
    for (var i = 0; i < visible.length; i++) {
      b.text(x(left + pad), y(top + 46 + i * 32), bodyFont,
          TsplFont.clip(bodyFont, visible[i], innerWidth));
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

  static void _centredText(
    TsplBuilder b, {
    required int centre,
    required int yPos,
    required String font,
    required String text,
    required int maxWidth,
  }) {
    final clipped = TsplFont.clip(font, text, maxWidth);
    if (clipped.isEmpty) return;
    final width = TsplFont.textWidth(font, clipped);
    b.text(centre - width ~/ 2, yPos, font, clipped);
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

  /// Width in modules of a Code 128 symbol for [data] (start + data + check
  /// + stop). Digit-only data is packed two per symbol (subset C).
  static int _code128Modules(String data) {
    final numeric = RegExp(r'^\d+$').hasMatch(data);
    int symbols;
    if (numeric) {
      symbols = data.length ~/ 2 + (data.length.isOdd ? 2 : 0);
    } else {
      symbols = data.length;
    }
    return 11 * (symbols + 2) + 13;
  }
}
