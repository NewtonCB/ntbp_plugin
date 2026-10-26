import 'tspl_builder.dart';

/// Media and printer settings shared by every label job.
///
/// Defaults match a 100 x 150 mm (4" x 6") die-cut label on a 203 dpi
/// printer such as the Xprinter XP-420B.
class LabelPrintConfig {
  /// Label width in millimetres.
  final double widthMm;

  /// Label height in millimetres.
  final double heightMm;

  /// Printer resolution. The XP-420B and N41 are 203 dpi.
  final int dpi;

  /// Physical gap between labels in millimetres. Common die-cut rolls use
  /// 2 to 3 mm. Set to 0 for continuous paper.
  final double gapMm;

  /// Extra feed after the gap in millimetres. Normally 0.
  final double gapOffsetMm;

  /// Use black-mark sensing instead of gap sensing. When true [gapMm] is
  /// sent as the black mark height.
  final bool blackMark;

  /// 0 = default orientation, 1 = rotated 180 degrees.
  final int direction;

  /// Print darkness 0..15, or null to leave the printer setting alone.
  final int? density;

  /// Print speed in inches per second, or null to leave the printer setting.
  final double? speed;

  /// Vertical offset applied after each label in millimetres.
  final double offsetMm;

  /// Number of copies for each label.
  final int copies;

  const LabelPrintConfig({
    this.widthMm = 100,
    this.heightMm = 150,
    this.dpi = 203,
    this.gapMm = 3,
    this.gapOffsetMm = 0,
    this.blackMark = false,
    this.direction = 0,
    this.density,
    this.speed,
    this.offsetMm = 0,
    this.copies = 1,
  });

  int get widthDots => mmToDots(widthMm);

  int get heightDots => mmToDots(heightMm);

  int mmToDots(double mm) => (mm * dpi / 25.4).round();

  LabelPrintConfig copyWith({
    double? widthMm,
    double? heightMm,
    int? dpi,
    double? gapMm,
    double? gapOffsetMm,
    bool? blackMark,
    int? direction,
    int? density,
    double? speed,
    double? offsetMm,
    int? copies,
  }) {
    return LabelPrintConfig(
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      dpi: dpi ?? this.dpi,
      gapMm: gapMm ?? this.gapMm,
      gapOffsetMm: gapOffsetMm ?? this.gapOffsetMm,
      blackMark: blackMark ?? this.blackMark,
      direction: direction ?? this.direction,
      density: density ?? this.density,
      speed: speed ?? this.speed,
      offsetMm: offsetMm ?? this.offsetMm,
      copies: copies ?? this.copies,
    );
  }

  /// Writes the setup commands (SIZE, GAP/BLINE, DIRECTION, REFERENCE, CLS)
  /// that start every job.
  TsplBuilder writeHeader(TsplBuilder b) {
    b.sizeMm(widthMm, heightMm);
    if (blackMark) {
      b.blineMm(gapMm, gapOffsetMm);
    } else {
      b.gapMm(gapMm, gapOffsetMm);
    }
    if (offsetMm != 0) b.offsetMm(offsetMm);
    if (speed != null) b.speed(speed!);
    if (density != null) b.density(density!);
    b.direction(direction);
    b.reference(0, 0);
    b.cls();
    return b;
  }

  Map<String, dynamic> toMap() => {
        'widthMm': widthMm,
        'heightMm': heightMm,
        'dpi': dpi,
        'gapMm': gapMm,
        'gapOffsetMm': gapOffsetMm,
        'blackMark': blackMark,
        'direction': direction,
        'density': density,
        'speed': speed,
        'offsetMm': offsetMm,
        'copies': copies,
      };

  @override
  String toString() =>
      'LabelPrintConfig(${widthMm}x${heightMm}mm, $dpi dpi, gap ${gapMm}mm, '
      'copies $copies)';
}
