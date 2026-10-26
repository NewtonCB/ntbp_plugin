/// Lightweight TSPL (Thermal Script Programming Language) command builder.
///
/// Every method appends one command line and returns `this` so calls can be
/// chained. [build] returns the finished script and [toBytes] the raw bytes
/// that are written to the printer.
///
/// All coordinates and sizes are in printer dots unless the method name says
/// otherwise (`...Mm`).
class TsplBuilder {
  final StringBuffer _buffer = StringBuffer();

  /// Appends a raw command line. A CRLF terminator is added automatically.
  TsplBuilder raw(String command) {
    _buffer.write(command);
    _buffer.write('\r\n');
    return this;
  }

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  TsplBuilder sizeMm(double width, double height) =>
      raw('SIZE ${_mm(width)} mm,${_mm(height)} mm');

  TsplBuilder sizeDots(int width, int height) =>
      raw('SIZE $width dot,$height dot');

  /// Gap between labels. [gap] is the physical gap height, [offset] the extra
  /// feed after the gap sensor sees the gap (usually 0).
  TsplBuilder gapMm(double gap, [double offset = 0]) =>
      raw('GAP ${_mm(gap)} mm,${_mm(offset)} mm');

  /// Black-mark media instead of gap media.
  TsplBuilder blineMm(double mark, [double offset = 0]) =>
      raw('BLINE ${_mm(mark)} mm,${_mm(offset)} mm');

  TsplBuilder offsetMm(double offset) => raw('OFFSET ${_mm(offset)} mm');

  TsplBuilder speed(double inchesPerSecond) =>
      raw('SPEED ${_mm(inchesPerSecond)}');

  TsplBuilder density(int level) => raw('DENSITY ${level.clamp(0, 15)}');

  /// 0 = default orientation, 1 = rotated 180 degrees.
  TsplBuilder direction(int direction, {bool mirror = false}) =>
      raw('DIRECTION ${direction == 1 ? 1 : 0},${mirror ? 1 : 0}');

  TsplBuilder reference(int x, int y) => raw('REFERENCE $x,$y');

  TsplBuilder shift(int dots) => raw('SHIFT $dots');

  TsplBuilder cls() => raw('CLS');

  // ---------------------------------------------------------------------------
  // Drawing
  // ---------------------------------------------------------------------------

  /// Prints [content] with a built-in bitmap font. See [TsplFont].
  TsplBuilder text(
    int x,
    int y,
    String font,
    String content, {
    int rotation = 0,
    int xMul = 1,
    int yMul = 1,
  }) =>
      raw('TEXT $x,$y,"$font",$rotation,$xMul,$yMul,"${escape(content)}"');

  /// QR code. [ecLevel] is L, M, Q or H. [cellWidth] 1..10 dots per module.
  TsplBuilder qrCode(
    int x,
    int y,
    String content, {
    String ecLevel = 'M',
    int cellWidth = 6,
    String mode = 'A',
    int rotation = 0,
  }) =>
      raw('QRCODE $x,$y,$ecLevel,${cellWidth.clamp(1, 10)},$mode,$rotation,'
          '"${escape(content)}"');

  /// 1D barcode. [readable] 0 = no human readable text, 1 left, 2 centre,
  /// 3 right. [narrow]/[wide] are module widths in dots.
  TsplBuilder barcode(
    int x,
    int y,
    String content, {
    String type = '128',
    int height = 100,
    int readable = 0,
    int rotation = 0,
    int narrow = 2,
    int wide = 2,
  }) =>
      raw('BARCODE $x,$y,"$type",$height,$readable,$rotation,$narrow,$wide,'
          '"${escape(content)}"');

  /// Rectangle outline. Note TSPL takes the END corner, not width/height.
  TsplBuilder box(int x1, int y1, int x2, int y2, {int thickness = 2}) =>
      raw('BOX $x1,$y1,$x2,$y2,$thickness');

  /// Filled rectangle.
  TsplBuilder bar(int x, int y, int width, int height) =>
      raw('BAR $x,$y,$width,$height');

  // ---------------------------------------------------------------------------
  // Job control
  // ---------------------------------------------------------------------------

  /// `PRINT sets,copies`. The image is printed [copies] times for each of
  /// [sets] sets.
  TsplBuilder print({int sets = 1, int copies = 1}) =>
      raw('PRINT ${sets < 1 ? 1 : sets},${copies < 1 ? 1 : copies}');

  TsplBuilder formFeed() => raw('FORMFEED');

  TsplBuilder home() => raw('HOME');

  TsplBuilder feed(int dots) => raw('FEED ${dots.clamp(1, 9999)}');

  TsplBuilder backFeed(int dots) => raw('BACKFEED ${dots.clamp(1, 9999)}');

  /// Runs the gap sensor calibration. Feeds a few labels.
  TsplBuilder gapDetect() => raw('GAPDETECT');

  /// Runs the black-mark sensor calibration.
  TsplBuilder blineDetect() => raw('BLINEDETECT');

  /// Runs automatic media calibration (gap or black mark).
  TsplBuilder autoDetect() => raw('AUTODETECT');

  TsplBuilder cut() => raw('CUT');

  TsplBuilder codePage(String codePage) => raw('CODEPAGE $codePage');

  // ---------------------------------------------------------------------------
  // Output
  // ---------------------------------------------------------------------------

  String build() => _buffer.toString();

  List<int> toBytes() => build().codeUnits;

  bool get isEmpty => _buffer.isEmpty;

  @override
  String toString() => build();

  /// TSPL strings are delimited by double quotes and have no escape
  /// sequence, so quotes are replaced and line breaks removed.
  static String escape(String value) {
    return value
        .replaceAll('"', "'")
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');
  }

  static String _mm(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

/// Built-in TSPL bitmap fonts and their glyph metrics (width x height in
/// dots at 1x magnification). These are the fonts every TSPL printer ships
/// with, including the Xprinter XP-420B.
class TsplFont {
  TsplFont._();

  static const String f8x12 = '1';
  static const String f12x20 = '2';
  static const String f16x24 = '3';
  static const String f24x32 = '4';
  static const String f32x48 = '5';
  static const String ocrB14x19 = '6';
  static const String ocrB21x27 = '7';
  static const String ocrA14x25 = '8';

  static const Map<String, int> _widths = {
    f8x12: 8,
    f12x20: 12,
    f16x24: 16,
    f24x32: 24,
    f32x48: 32,
    ocrB14x19: 14,
    ocrB21x27: 21,
    ocrA14x25: 14,
  };

  static const Map<String, int> _heights = {
    f8x12: 12,
    f12x20: 20,
    f16x24: 24,
    f24x32: 32,
    f32x48: 48,
    ocrB14x19: 19,
    ocrB21x27: 27,
    ocrA14x25: 25,
  };

  /// Fonts ordered from largest to smallest, used for fit-to-width selection.
  static const List<String> sizedLargestFirst = [
    f32x48,
    f24x32,
    f16x24,
    f12x20,
    f8x12,
  ];

  static int charWidth(String font, {int xMul = 1}) =>
      (_widths[font] ?? 12) * xMul;

  static int charHeight(String font, {int yMul = 1}) =>
      (_heights[font] ?? 20) * yMul;

  static int textWidth(String font, String text, {int xMul = 1}) =>
      charWidth(font, xMul: xMul) * text.length;

  /// Largest font (no bigger than [preferred]) whose rendering of [text]
  /// fits inside [maxWidth] dots. Falls back to the smallest font.
  static String fit(String text, int maxWidth, {String preferred = f32x48}) {
    final start = sizedLargestFirst.indexOf(preferred);
    final candidates = sizedLargestFirst.sublist(start < 0 ? 0 : start);
    for (final font in candidates) {
      if (textWidth(font, text) <= maxWidth) return font;
    }
    return candidates.last;
  }

  /// Truncates [text] so it fits in [maxWidth] dots with [font].
  static String clip(String font, String text, int maxWidth) {
    final maxChars = maxWidth ~/ charWidth(font);
    if (maxChars <= 0) return '';
    return text.length <= maxChars ? text : text.substring(0, maxChars);
  }
}
