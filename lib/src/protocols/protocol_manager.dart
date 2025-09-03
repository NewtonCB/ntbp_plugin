import 'printer_protocol.dart';
import 'printer_factory.dart';

/// Protocol Manager that integrates the scalable architecture with the existing plugin
/// This class acts as a bridge between the old plugin methods and new protocol system
class ProtocolManager {
  static final ProtocolManager _instance = ProtocolManager._internal();
  factory ProtocolManager() => _instance;
  ProtocolManager._internal();
  
  PrinterProtocol? _currentProtocol;
  String? _currentPrinterModel;
  
  /// Initialize protocol for a specific printer
  Future<bool> initializeProtocol(String printerModel) async {
    try {
      final protocol = PrinterFactory.getProtocolForPrinter(printerModel);
      if (protocol == null) {
        print('ProtocolManager: No protocol found for $printerModel');
        return false;
      }
      
      _currentProtocol = protocol;
      _currentPrinterModel = printerModel;
      
      print('ProtocolManager: Initialized ${protocol.protocolName} for $printerModel');
      return true;
    } catch (e) {
      print('ProtocolManager: Error initializing protocol: $e');
      return false;
    }
  }
  
  /// Auto-detect and initialize protocol
  Future<bool> autoDetectProtocol({
    String? deviceName,
    String? deviceAddress,
    Map<String, dynamic>? deviceProperties,
  }) async {
    try {
      final protocol = PrinterFactory.autoDetectProtocol(
        deviceName: deviceName,
        deviceAddress: deviceAddress,
        deviceProperties: deviceProperties,
      );
      
      if (protocol == null) {
        print('ProtocolManager: Auto-detection failed');
        return false;
      }
      
      _currentProtocol = protocol;
      _currentPrinterModel = deviceName ?? 'Unknown';
      
      print('ProtocolManager: Auto-detected ${protocol.protocolName} protocol');
      return true;
    } catch (e) {
      print('ProtocolManager: Error in auto-detection: $e');
      return false;
    }
  }
  
  /// Get current protocol
  PrinterProtocol? get currentProtocol => _currentProtocol;
  
  /// Get current printer model
  String? get currentPrinterModel => _currentPrinterModel;
  
  /// Check if protocol is initialized
  bool get isProtocolInitialized => _currentProtocol != null;
  
  /// Get protocol capabilities
  Map<String, dynamic> getProtocolCapabilities() {
    if (_currentPrinterModel == null) {
      return {
        'supported': false,
        'error': 'No printer model set',
      };
    }
    
    return PrinterFactory.getProtocolCapabilities(_currentPrinterModel!);
  }
  
  /// Print single label using current protocol
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
    if (!isProtocolInitialized) {
      print('ProtocolManager: No protocol initialized');
      return false;
    }
    
    try {
      return await _currentProtocol!.printSingleLabel(
        qrData: qrData,
        textData: textData,
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
        copies: copies,
        textSize: textSize,
      );
    } catch (e) {
      print('ProtocolManager: Error printing single label: $e');
      return false;
    }
  }
  
  /// Print multiple labels using current protocol
  Future<bool> printMultipleLabels({
    required List<Map<String, dynamic>> labelDataList,
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
    required int copiesPerLabel,
    required int textSize,
  }) async {
    if (!isProtocolInitialized) {
      print('ProtocolManager: No protocol initialized');
      return false;
    }
    
    try {
      return await _currentProtocol!.printMultipleLabels(
        labelDataList: labelDataList,
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
        copiesPerLabel: copiesPerLabel,
        textSize: textSize,
      );
    } catch (e) {
      print('ProtocolManager: Error printing multiple labels: $e');
      return false;
    }
  }
  
  /// Initialize printer using current protocol
  Future<bool> initializePrinter({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) async {
    if (!isProtocolInitialized) {
      print('ProtocolManager: No protocol initialized');
      return false;
    }
    
    try {
      return await _currentProtocol!.initializePrinter(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
    } catch (e) {
      print('ProtocolManager: Error initializing printer: $e');
      return false;
    }
  }
  
  /// Clear buffer using current protocol
  Future<bool> clearBuffer() async {
    if (!isProtocolInitialized) {
      print('ProtocolManager: No protocol initialized');
      return false;
    }
    
    try {
      return await _currentProtocol!.clearBuffer();
    } catch (e) {
      print('ProtocolManager: Error clearing buffer: $e');
      return false;
    }
  }
  
  /// Get printer status using current protocol
  Future<Map<String, dynamic>> getPrinterStatus() async {
    if (!isProtocolInitialized) {
      return {
        'connected': false,
        'protocol': 'None',
        'error': 'No protocol initialized',
      };
    }
    
    try {
      return await _currentProtocol!.getPrinterStatus();
    } catch (e) {
      print('ProtocolManager: Error getting printer status: $e');
      return {
        'connected': false,
        'protocol': _currentProtocol!.protocolName,
        'error': e.toString(),
      };
    }
  }
  
  /// Feed paper using current protocol
  Future<bool> feedPaper() async {
    if (!isProtocolInitialized) {
      print('ProtocolManager: No protocol initialized');
      return false;
    }
    
    try {
      return await _currentProtocol!.feedPaper();
    } catch (e) {
      print('ProtocolManager: Error feeding paper: $e');
      return false;
    }
  }
  
  /// Send gap detection commands using current protocol
  Future<bool> sendGapDetectionCommands({
    required double labelWidth,
    required double labelHeight,
    required String unit,
    required int dpi,
  }) async {
    if (!isProtocolInitialized) {
      print('ProtocolManager: No protocol initialized');
      return false;
    }
    
    try {
      return await _currentProtocol!.sendGapDetectionCommands(
        labelWidth: labelWidth,
        labelHeight: labelHeight,
        unit: unit,
        dpi: dpi,
      );
    } catch (e) {
      print('ProtocolManager: Error sending gap detection commands: $e');
      return false;
    }
  }
  
  /// Reset protocol manager
  void reset() {
    _currentProtocol = null;
    _currentPrinterModel = null;
    print('ProtocolManager: Reset');
  }
  
  /// Get all supported printer models
  List<String> getSupportedPrinterModels() {
    return PrinterFactory.getSupportedPrinterModels();
  }
  
  /// Check if a printer model is supported
  bool isPrinterSupported(String printerModel) {
    return PrinterFactory.isPrinterSupported(printerModel);
  }
} 