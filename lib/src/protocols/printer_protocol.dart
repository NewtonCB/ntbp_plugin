/// Abstract interface for printer protocols
/// This allows the plugin to support multiple printer types (TSPL, ESC/POS, etc.)
abstract class PrinterProtocol {
  /// Protocol name identifier
  String get protocolName;
  
  /// Check if this protocol supports the given printer model
  bool supportsPrinter(String printerModel);
  
  /// Initialize printer with label dimensions and settings
  Future<bool> initializePrinter({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  });
  
  /// Print single label with QR code and text
  Future<bool> printSingleLabel({
    required String qrData,
    required String textData,
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int copies,
    required int textSize,
  });
  
  /// Print multiple labels with different content
  Future<bool> printMultipleLabels({
    required List<Map<String, dynamic>> labelDataList,
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int copiesPerLabel,
    required int textSize,
  });
  
  /// Clear printer buffer
  Future<bool> clearBuffer();
  
  /// Get printer status
  Future<Map<String, dynamic>> getPrinterStatus();
  
  /// Feed paper
  Future<bool> feedPaper();
  
  /// Send gap detection commands
  Future<bool> sendGapDetectionCommands({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  });
  
  /// Calculate optimal positioning for content
  Map<String, int> calculatePositions({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int qrSize,
  });
  
  /// Convert dimensions to dots
  int convertToDots(int dpi, double value, String unit);
  
  /// Build print commands
  List<int> buildPrintCommands({
    required String qrData,
    required String textData,
    required Map<String, int> positions,
    required int qrSize,
    required int textSize,
    required int copies,
  });
} 