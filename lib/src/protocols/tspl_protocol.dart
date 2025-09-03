import 'dart:typed_data';
import 'printer_protocol.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

/// TSPL (Thermal Script Programming Language) Protocol Implementation
/// This service handles TSPL commands for printers like N41
class TSPLProtocol implements PrinterProtocol {
  @override
  String get protocolName => 'TSPL';
  
  @override
  bool supportsPrinter(String printerModel) {
    // TSPL supports most thermal label printers
    final supportedModels = [
      'N41', 'N41-001', 'N41-002', 'N41-003',
      'TSPL', 'TSPL2', 'TSPL3',
      'Godex', 'Zebra', 'TSC'
    ];
    
    return supportedModels.any((model) => 
      printerModel.toUpperCase().contains(model.toUpperCase())
    );
  }
  
  @override
  Future<bool> initializePrinter({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) async {
    try {
      // TSPL initialization commands
      final commands = _buildInitializationCommands(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
      
      // Send commands to printer using the method channel
      return await _sendCommands(commands);
    } catch (e) {
      print('TSPL Protocol: Error initializing printer: $e');
      return false;
    }
  }
  
  @override
  Future<bool> printSingleLabel({
    required String qrData,
    required String textData,
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int copies,
    required int textSize,
  }) async {
    try {
      // Calculate optimal positioning
      final qrSize = _calculateOptimalQRSize(labelWidth, labelHeight, unit, dpi);
      final positions = calculatePositions(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
        qrSize: qrSize,
      );
      
      // Build TSPL commands
      final commands = buildPrintCommands(
        qrData: qrData,
        textData: textData,
        positions: positions,
        qrSize: qrSize,
        textSize: textSize,
        copies: copies,
      );
      
      // Send commands to printer
      return await _sendCommands(commands);
    } catch (e) {
      print('TSPL Protocol: Error printing single label: $e');
      return false;
    }
  }
  
  @override
  Future<bool> printMultipleLabels({
    required List<Map<String, dynamic>> labelDataList,
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int copiesPerLabel,
    required int textSize,
  }) async {
    try {
      // Initialize printer first
      await initializePrinter(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
      
      // Send gap detection commands
      await sendGapDetectionCommands(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
      
      // Print each label
      for (final labelData in labelDataList) {
        final qrData = labelData['qrData'] as String? ?? '';
        final textData = labelData['textData'] as String? ?? '';
        
        // Clear buffer before each label to prevent content bleeding
        await clearBuffer();
        
        // Print single label
        final success = await printSingleLabel(
          qrData: qrData,
          textData: textData,
          labelWidth: labelWidth,
          labelHeight: labelHeight,
          unit: unit,
          dpi: dpi,
          copies: copiesPerLabel,
          textSize: textSize,
        );
        
        if (!success) {
          print('TSPL Protocol: Failed to print label: $labelData');
          return false;
        }
        
        // Wait for print completion
        await Future.delayed(Duration(milliseconds: 500 * copiesPerLabel));
      }
      
      return true;
    } catch (e) {
      print('TSPL Protocol: Error printing multiple labels: $e');
      return false;
    }
  }
  
  @override
  Future<bool> clearBuffer() async {
    try {
      // TSPL buffer clearing commands
      final commands = [
        ..._stringToBytes('CLEAR\r\n'),
        ..._stringToBytes('CLS\r\n'),
        ..._stringToBytes('HOME\r\n'),
      ];
      
      return await _sendCommands(commands);
    } catch (e) {
      print('TSPL Protocol: Error clearing buffer: $e');
      return false;
    }
  }
  
  @override
  Future<Map<String, dynamic>> getPrinterStatus() async {
    try {
      // TSPL status commands
      final commands = _stringToBytes('STATUS\r\n');
      final response = await _sendCommands(commands);
      
      // Parse status response (simplified)
      return {
        'connected': response,
        'protocol': protocolName,
        'ready': response,
      };
    } catch (e) {
      print('TSPL Protocol: Error getting printer status: $e');
      return {
        'connected': false,
        'protocol': protocolName,
        'error': e.toString(),
      };
    }
  }
  
  @override
  Future<bool> feedPaper() async {
    try {
      // TSPL paper feed commands
      final commands = [
        ..._stringToBytes('FORMFEED\r\n'),
        ..._stringToBytes('FEED\r\n'),
      ];
      
      return await _sendCommands(commands);
    } catch (e) {
      print('TSPL Protocol: Error feeding paper: $e');
      return false;
    }
  }
  
  @override
  Future<bool> sendGapDetectionCommands({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) async {
    try {
      final commands = _buildGapDetectionCommands(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
      
      return await _sendCommands(commands);
    } catch (e) {
      print('TSPL Protocol: Error sending gap detection commands: $e');
      return false;
    }
  }
  
  @override
  Map<String, int> calculatePositions({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int qrSize,
  }) {
    final widthInDots = convertToDots(dpi, labelWidth, unit);
    final heightInDots = convertToDots(dpi, labelHeight, unit);
    
    // Calculate margins (dynamic based on label size)
    final marginInDots = _calculateMargin(labelWidth, unit, dpi);
    
    final availableWidth = widthInDots - 2 * marginInDots;
    final availableHeight = heightInDots - 2 * marginInDots;
    
    // Calculate positions with better spacing
    final qrX = marginInDots + (availableWidth - qrSize) ~/ 2; // Center horizontally
    final qrY = marginInDots + (availableHeight * 0.15).round(); // Position QR code in upper portion
    final textX = marginInDots + (availableWidth - convertToDots(dpi, 20.0, unit)) ~/ 2; // Center text horizontally
    final textY = qrY + qrSize + convertToDots(dpi, 8.0, unit); // Text below QR with proper spacing
    
    return {
      'qrX': qrX,
      'qrY': qrY,
      'textX': textX,
      'textY': textY,
      'widthInDots': widthInDots,
      'heightInDots': heightInDots,
    };
  }
  
  @override
  int convertToDots(int dpi, double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'mm':
        return (value * dpi / 25.4).round();
      case 'inch':
        return (value * dpi).round();
      case 'dot':
        return value.round();
      default:
        return (value * dpi / 25.4).round(); // Default to mm
    }
  }
  
  @override
  List<int> buildPrintCommands({
    required String qrData,
    required String textData,
    required Map<String, int> positions,
    required int qrSize,
    required int textSize,
    required int copies,
  }) {
    final commands = <int>[];
    
    // TSPL commands for label printing
    commands.addAll(_stringToBytes('REFERENCE 0,0\r\n')); // Set reference point
    commands.addAll(_stringToBytes('DIRECTION 0\r\n')); // Normal direction
    
    // Add QR code
    commands.addAll(_stringToBytes('QRCODE ${positions['qrX']},${positions['qrY']},H,10,A,0,"$qrData"\r\n'));
    
    // Add text below QR code
    commands.addAll(_stringToBytes('TEXT ${positions['textX']},${positions['textY']},"$textSize",0,1,1,"$textData"\r\n'));
    
    // Print specified number of copies
    commands.addAll(_stringToBytes('PRINT $copies\r\n'));
    
    return commands;
  }
  
  // Private helper methods
  
  List<int> _buildInitializationCommands({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) {
    final widthInDots = convertToDots(dpi, labelWidth, unit);
    final heightInDots = convertToDots(dpi, labelHeight, unit);
    
    final commands = <int>[];
    commands.addAll(_stringToBytes('CLEAR\r\n')); // Clear buffer first
    commands.addAll(_stringToBytes('SIZE $widthInDots dot,$heightInDots dot\r\n')); // Set label size
    commands.addAll(_stringToBytes('CLS\r\n')); // Clear screen
    
    return commands;
  }
  
  List<int> _buildGapDetectionCommands({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) {
    final widthInDots = convertToDots(dpi, labelWidth, unit);
    final heightInDots = convertToDots(dpi, labelHeight, unit);
    
    // Calculate gap size (typically 2-3mm for labels)
    final gapSize = _calculateGapSize(labelHeight, unit, dpi);
    
    final commands = <int>[];
    commands.addAll(_stringToBytes('CLEAR\r\n')); // Clear buffer first
    commands.addAll(_stringToBytes('SIZE $widthInDots dot,$heightInDots dot\r\n')); // Set label size in dots
    commands.addAll(_stringToBytes('GAP $gapSize dot,0\r\n')); // Set gap between labels
    commands.addAll(_stringToBytes('GAPDETECT ON\r\n')); // Enable gap detection
    commands.addAll(_stringToBytes('AUTODETECT ON\r\n')); // Enable auto-detection
    commands.addAll(_stringToBytes('CLS\r\n')); // Clear screen
    
    return commands;
  }
  
  int _calculateOptimalQRSize(double labelWidth, double labelHeight, String unit, int dpi) {
    final widthInDots = convertToDots(dpi, labelWidth, unit);
    final heightInDots = convertToDots(dpi, labelHeight, unit);
    
    final marginInDots = _calculateMargin(labelWidth, unit, dpi);
    final availableWidth = widthInDots - 2 * marginInDots;
    final availableHeight = heightInDots - 2 * marginInDots;
    
    // Calculate QR size (proportional to label size)
    double qrSize = 0.0;
    if (labelWidth <= 30) {
      qrSize = availableWidth * 0.6;
    } else if (labelWidth <= 60) {
      qrSize = availableWidth * 0.65;
    } else {
      qrSize = availableWidth * 0.7;
    }
    
    // Ensure QR fits in height and doesn't exceed width
    qrSize = qrSize.clamp(0.0, (availableHeight * 0.6).clamp(0.0, availableWidth * 0.7));
    
    return qrSize.round();
  }
  
  int _calculateMargin(double labelWidth, String unit, int dpi) {
    if (labelWidth <= 30) {
      return convertToDots(dpi, 2.0, unit);
    } else if (labelWidth <= 60) {
      return convertToDots(dpi, 3.0, unit);
    } else {
      return convertToDots(dpi, 4.0, unit);
    }
  }
  
  int _calculateGapSize(double labelHeight, String unit, int dpi) {
    if (labelHeight <= 20) {
      return convertToDots(dpi, 2.0, unit); // Small labels: 2mm gap
    } else if (labelHeight <= 40) {
      return convertToDots(dpi, 2.5, unit); // Medium labels: 2.5mm gap
    } else {
      return convertToDots(dpi, 3.0, unit); // Large labels: 3mm gap
    }
  }
  
  List<int> _stringToBytes(String str) {
    return str.codeUnits;
  }
  
  // Send commands using the method channel to native code
  Future<bool> _sendCommands(List<int> commands) async {
    try {
      // Use the method channel to send protocol commands to native code
      return await NtbpPluginPlatform.instance.sendProtocolCommands(commands, protocolName);
    } catch (e) {
      print('TSPL Protocol: Error sending commands via method channel: $e');
      return false;
    }
  }
} 