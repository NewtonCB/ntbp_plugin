import 'dart:typed_data';
import 'printer_protocol.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

/// ESC/POS Protocol Implementation for Romeson KT58L
/// This service FORCES TSPL commands on ESC/POS printers for better compatibility
/// We adapt TSPL commands to work with the device's paper dimensions and capabilities
class ESCPOSProtocol implements PrinterProtocol {
  @override
  String get protocolName => 'ESC/POS (TSPL Forced)';
  
  @override
  bool supportsPrinter(String printerModel) {
    // ESC/POS supports most thermal printers including Romeson KT58L
    final supportedModels = [
      'KT58L', 'Romeson', 'ESC/POS', 'ESCPOS',
      'Thermal', 'Receipt', 'Label'
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
      // Force TSPL initialization commands (adapted for KT58L dimensions)
      final commands = _buildTSPLInitializationCommands(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
      
      // Send TSPL commands to printer
      return await _sendCommands(commands);
    } catch (e) {
      print('ESC/POS Protocol: Error initializing printer with TSPL: $e');
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
      // Calculate optimal positioning using TSPL logic
      final qrSize = _calculateOptimalQRSize(labelWidth, labelHeight, unit, dpi);
      final positions = calculatePositions(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
        qrSize: qrSize,
      );
      
      // Build TSPL commands (forced on KT58L)
      final commands = buildPrintCommands(
        qrData: qrData,
        textData: textData,
        positions: positions,
        qrSize: qrSize,
        textSize: textSize,
        copies: copies,
      );
      
      // Send TSPL commands to printer
      return await _sendCommands(commands);
    } catch (e) {
      print('ESC/POS Protocol: Error printing single label with TSPL: $e');
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
      // Initialize printer first with TSPL commands
      await initializePrinter(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
      
      // Send TSPL gap detection commands (forced on KT58L)
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
        
        // Clear buffer before each label using TSPL commands
        await clearBuffer();
        
        // Print single label using TSPL commands
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
          print('ESC/POS Protocol: Failed to print label with TSPL: $labelData');
          return false;
        }
        
        // Wait for print completion
        await Future.delayed(Duration(milliseconds: 500 * copiesPerLabel));
      }
      
      return true;
    } catch (e) {
      print('ESC/POS Protocol: Error printing multiple labels with TSPL: $e');
      return false;
    }
  }
  
  @override
  Future<bool> clearBuffer() async {
    try {
      // Force TSPL buffer clearing commands on KT58L
      final commands = [
        ..._stringToBytes('CLEAR\r\n'),
        ..._stringToBytes('CLS\r\n'),
        ..._stringToBytes('HOME\r\n'),
      ];
      
      return await _sendCommands(commands);
    } catch (e) {
      print('ESC/POS Protocol: Error clearing buffer with TSPL: $e');
      return false;
    }
  }
  
  @override
  Future<Map<String, dynamic>> getPrinterStatus() async {
    try {
      // Force TSPL status commands on KT58L
      final commands = _stringToBytes('STATUS\r\n');
      final response = await _sendCommands(commands);
      
      // Parse status response (simplified)
      return {
        'connected': response,
        'protocol': protocolName,
        'ready': response,
        'forcedTSPL': true, // Indicate we're forcing TSPL
      };
    } catch (e) {
      print('ESC/POS Protocol: Error getting printer status with TSPL: $e');
      return {
        'connected': false,
        'protocol': protocolName,
        'error': e.toString(),
        'forcedTSPL': true,
      };
    }
  }
  
  @override
  Future<bool> feedPaper() async {
    try {
      // Force TSPL paper feed commands on KT58L
      final commands = [
        ..._stringToBytes('FORMFEED\r\n'),
        ..._stringToBytes('FEED\r\n'),
      ];
      
      return await _sendCommands(commands);
    } catch (e) {
      print('ESC/POS Protocol: Error feeding paper with TSPL: $e');
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
      // Force TSPL gap detection commands on KT58L (adapted for device dimensions)
      final commands = _buildTSPLGapDetectionCommands(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
      
      return await _sendCommands(commands);
    } catch (e) {
      print('ESC/POS Protocol: Error sending TSPL gap detection commands: $e');
      return false;
    }
  }
  
  @override
  Map<String, int> calculatePositions({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int qrSize,
    required int dpi,
  }) {
    final widthInDots = convertToDots(dpi, labelWidth, unit);
    final heightInDots = convertToDots(dpi, labelHeight, unit);
    
    // Calculate margins (dynamic based on label size) - TSPL-style
    final marginInDots = _calculateMargin(labelWidth, unit, dpi);
    
    final availableWidth = widthInDots - 2 * marginInDots;
    final availableHeight = heightInDots - 2 * marginInDots;
    
    // Calculate positions with TSPL-style spacing
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
    
    // Force TSPL commands on KT58L device
    commands.addAll(_stringToBytes('REFERENCE 0,0\r\n')); // Set reference point
    commands.addAll(_stringToBytes('DIRECTION 0\r\n')); // Normal direction
    
    // Add QR code using TSPL command
    commands.addAll(_stringToBytes('QRCODE ${positions['qrX']},${positions['qrY']},H,10,A,0,"$qrData"\r\n'));
    
    // Add text below QR code using TSPL command
    commands.addAll(_stringToBytes('TEXT ${positions['textX']},${positions['textY']},"$textSize",0,1,1,"$textData"\r\n'));
    
    // Print specified number of copies using TSPL command
    commands.addAll(_stringToBytes('PRINT $copies\r\n'));
    
    return commands;
  }
  
  // Private helper methods - TSPL commands adapted for KT58L
  
  List<int> _buildTSPLInitializationCommands({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) {
    final widthInDots = convertToDots(dpi, labelWidth, unit);
    final heightInDots = convertToDots(dpi, labelHeight, unit);
    
    final commands = <int>[];
    
    // TSPL initialization commands (forced on KT58L)
    commands.addAll(_stringToBytes('CLEAR\r\n')); // Clear buffer first
    commands.addAll(_stringToBytes('SIZE $widthInDots dot,$heightInDots dot\r\n')); // Set label size
    commands.addAll(_stringToBytes('CLS\r\n')); // Clear screen
    
    // KT58L-specific adaptations
    commands.addAll(_stringToBytes('DENSITY 15\r\n')); // Set print density (KT58L supports this)
    commands.addAll(_stringToBytes('SPEED 3\r\n')); // Set print speed (KT58L supports this)
    
    return commands;
  }
  
  List<int> _buildTSPLGapDetectionCommands({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) {
    final widthInDots = convertToDots(dpi, labelWidth, unit);
    final heightInDots = convertToDots(dpi, labelHeight, unit);
    
    // Calculate gap size (typically 2-3mm for labels) - adapted for KT58L
    final gapSize = _calculateGapSize(labelHeight, unit, dpi);
    
    final commands = <int>[];
    
    // Force TSPL gap detection commands on KT58L
    commands.addAll(_stringToBytes('CLEAR\r\n')); // Clear buffer first
    commands.addAll(_stringToBytes('SIZE $widthInDots dot,$heightInDots dot\r\n')); // Set label size in dots
    commands.addAll(_stringToBytes('GAP $gapSize dot,0\r\n')); // Set gap between labels
    commands.addAll(_stringToBytes('GAPDETECT ON\r\n')); // Enable gap detection
    commands.addAll(_stringToBytes('AUTODETECT ON\r\n')); // Enable auto-detection
    commands.addAll(_stringToBytes('CLS\r\n')); // Clear screen
    
    // KT58L-specific gap detection adaptations
    commands.addAll(_stringToBytes('OFFSET 0\r\n')); // Set offset (KT58L supports this)
    
    return commands;
  }
  
  int _calculateOptimalQRSize(double labelWidth, double labelHeight, String unit, int dpi) {
    final widthInDots = convertToDots(dpi, labelWidth, unit);
    final heightInDots = convertToDots(dpi, labelHeight, unit);
    
    final marginInDots = _calculateMargin(labelWidth, unit, dpi);
    final availableWidth = widthInDots - 2 * marginInDots;
    final availableHeight = heightInDots - 2 * marginInDots;
    
    // Calculate QR size (proportional to label size) - TSPL-style
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
  
  // Send TSPL commands using the method channel to native code
  Future<bool> _sendCommands(List<int> commands) async {
    try {
      // Use the method channel to send TSPL commands to native code
      // Note: We're sending TSPL commands but marking them as ESC/POS protocol
      // This allows the native layer to handle them appropriately
      return await NtbpPluginPlatform.instance.sendProtocolCommands(commands, protocolName);
    } catch (e) {
      print('ESC/POS Protocol: Error sending TSPL commands via method channel: $e');
      return false;
    }
  }
} 