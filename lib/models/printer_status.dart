/// Status reported by a TSPL printer in response to the `ESC ! ?` query.
///
/// The raw byte is a bit field: 0x01 head open, 0x02 paper jam, 0x04 out of
/// paper, 0x08 out of ribbon, 0x10 paused, 0x20 printing. Zero means ready.
class PrinterStatus {
  /// Raw status byte, or a negative value when no answer was received.
  final int code;

  const PrinterStatus(this.code);

  /// Returned when the printer did not answer within the timeout.
  static const PrinterStatus noResponse = PrinterStatus(-1);

  /// Returned when there is no open connection.
  static const PrinterStatus notConnected = PrinterStatus(-2);

  bool get responded => code >= 0;
  bool get isReady => code == 0;
  bool get isHeadOpen => code > 0 && (code & 0x01) != 0;
  bool get isPaperJam => code > 0 && (code & 0x02) != 0;
  bool get isOutOfPaper => code > 0 && (code & 0x04) != 0;
  bool get isOutOfRibbon => code > 0 && (code & 0x08) != 0;
  bool get isPaused => code > 0 && (code & 0x10) != 0;
  bool get isPrinting => code > 0 && (code & 0x20) != 0;

  /// True when the printer reported a condition that stops printing.
  bool get hasError =>
      isHeadOpen || isPaperJam || isOutOfPaper || isOutOfRibbon;

  /// Short machine-friendly name, e.g. `ready`, `out_of_paper`.
  String get name {
    if (code == -2) return 'not_connected';
    if (code < 0) return 'no_response';
    if (code == 0) return 'ready';
    final parts = <String>[];
    if (isHeadOpen) parts.add('head_open');
    if (isPaperJam) parts.add('paper_jam');
    if (isOutOfPaper) parts.add('out_of_paper');
    if (isOutOfRibbon) parts.add('out_of_ribbon');
    if (isPaused) parts.add('paused');
    if (isPrinting) parts.add('printing');
    return parts.isEmpty ? 'unknown' : parts.join('+');
  }

  /// Human readable description.
  String get description {
    switch (code) {
      case -2:
        return 'Not connected';
      case -1:
        return 'No response from printer';
      case 0:
        return 'Ready';
    }
    final parts = <String>[];
    if (isHeadOpen) parts.add('Head opened');
    if (isPaperJam) parts.add('Paper jam');
    if (isOutOfPaper) parts.add('Out of paper');
    if (isOutOfRibbon) parts.add('Out of ribbon');
    if (isPaused) parts.add('Paused');
    if (isPrinting) parts.add('Printing');
    return parts.isEmpty ? 'Unknown status ($code)' : parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'status': name,
        'description': description,
        'ready': isReady,
        'printing': isPrinting,
        'error': hasError,
        'responded': responded,
      };

  @override
  String toString() => 'PrinterStatus($code: $name)';

  @override
  bool operator ==(Object other) => other is PrinterStatus && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Result of printing a batch of labels.
class PrintBatchResult {
  final int total;
  final int printed;
  final List<int> failedIndexes;

  /// Status that stopped the batch, if any.
  final PrinterStatus? stoppedBy;

  const PrintBatchResult({
    required this.total,
    required this.printed,
    this.failedIndexes = const [],
    this.stoppedBy,
  });

  bool get success => failedIndexes.isEmpty && printed == total;

  @override
  String toString() =>
      'PrintBatchResult($printed/$total printed, failed $failedIndexes'
      '${stoppedBy != null ? ', stopped by $stoppedBy' : ''})';
}
