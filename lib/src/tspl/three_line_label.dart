import 'label_print_config.dart';
import 'tspl_builder.dart';

/// The original NTBP label: a centred QR code with up to three left-aligned
/// text lines beneath it. This is a direct port of the positioning logic that
/// shipped in the Android implementation of version 2.0.0, so existing
/// callers get the same output on both platforms.
class ThreeLineQrLabel {
  final String qrData;
  final String line1;
  final String line2;
  final String line3;

  const ThreeLineQrLabel({
    required this.qrData,
    this.line1 = '',
    this.line2 = '',
    this.line3 = '',
  });

  factory ThreeLineQrLabel.fromMap(Map<String, dynamic> map, {int index = 0}) {
    return ThreeLineQrLabel(
      qrData: map['qrData'] as String? ?? 'Label${index + 1}',
      line1: map['textData1'] as String? ?? '',
      line2: map['textData2'] as String? ?? '',
      line3: map['textData3'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'qrData': qrData,
        'textData1': line1,
        'textData2': line2,
        'textData3': line3,
      };
}

class ThreeLineQrLayout {
  ThreeLineQrLayout._();

  /// Full print job for one label. [textFont] is the TSPL font name passed
  /// straight through (the v2 default was "9").
  static String buildJob(
    ThreeLineQrLabel label,
    LabelPrintConfig config, {
    String textFont = '9',
  }) {
    final b = TsplBuilder();
    config.writeHeader(b);
    writeContent(b, label, config, textFont: textFont);
    b.print(copies: config.copies);
    return b.build();
  }

  static void writeContent(
    TsplBuilder b,
    ThreeLineQrLabel label,
    LabelPrintConfig config, {
    String textFont = '9',
  }) {
    final p = positions(config);
    b.qrCode(p['qrX']!, p['qrY']!, label.qrData, ecLevel: 'H', cellWidth: 10);
    if (label.line1.isNotEmpty) {
      b.text(p['textX']!, p['textY1']!, textFont, label.line1);
    }
    if (label.line2.isNotEmpty) {
      b.text(p['textX']!, p['textY2']!, textFont, label.line2);
    }
    if (label.line3.isNotEmpty) {
      b.text(p['textX']!, p['textY3']!, textFont, label.line3);
    }
  }

  /// Same arithmetic as the Kotlin `calculateLabelPositions` in v2.0.0.
  static Map<String, int> positions(LabelPrintConfig config) {
    final width = config.widthMm;
    final widthInDots = config.widthDots;
    final heightInDots = config.heightDots;
    int mm(double v) => (v * config.dpi / 25.4).toInt();

    final margin = width <= 30
        ? mm(2.0)
        : width <= 60
            ? mm(3.0)
            : mm(4.0);

    final availableWidth = widthInDots - 2 * margin;
    final availableHeight = heightInDots - 2 * margin;

    var qrSize = (width <= 30
            ? availableWidth * 0.55
            : width <= 60
                ? availableWidth * 0.6
                : availableWidth * 0.65)
        .toInt();
    qrSize = qrSize.clamp(0, (availableHeight * 0.45).toInt());
    qrSize = qrSize.clamp(0, (availableWidth * 0.65).toInt());

    final qrX = margin + (availableWidth - qrSize) ~/ 2;
    final qrY = margin + (availableHeight * 0.08).toInt();
    final textX = qrX;

    var textY1 = qrY + qrSize + mm(8.0);
    var textY2 = textY1 + mm(4.0);
    var textY3 = textY2 + mm(4.0);

    final maxTextY = heightInDots - margin - mm(2.0);
    if (textY3 > maxTextY) {
      textY1 = maxTextY - mm(8.0);
      textY2 = maxTextY - mm(4.0);
      textY3 = maxTextY;
    }

    return {
      'qrX': qrX,
      'qrY': qrY,
      'qrSize': qrSize,
      'textX': textX,
      'textY1': textY1,
      'textY2': textY2,
      'textY3': textY3,
    };
  }
}
