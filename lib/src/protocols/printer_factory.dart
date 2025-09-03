import 'printer_protocol.dart';
import 'tspl_protocol.dart';
import 'escpos_protocol.dart';

/// Factory class for creating printer protocol instances
/// Automatically selects the best protocol based on printer model
/// For ESC/POS printers, we force TSPL commands for better compatibility
class PrinterFactory {
  static final List<PrinterProtocol> _availableProtocols = [
    TSPLProtocol(),
    ESCPOSProtocol(), // This now forces TSPL commands on ESC/POS printers
  ];
  
  /// Get the best protocol for the given printer model
  /// Returns null if no protocol supports the printer
  static PrinterProtocol? getProtocolForPrinter(String printerModel) {
    if (printerModel.isEmpty) return null;
    
    // Try to find a protocol that supports this printer
    for (final protocol in _availableProtocols) {
      if (protocol.supportsPrinter(printerModel)) {
        print('PrinterFactory: Selected ${protocol.protocolName} protocol for $printerModel');
        return protocol;
      }
    }
    
    print('PrinterFactory: No protocol found for printer: $printerModel');
    return null;
  }
  
  /// Get all available protocols
  static List<PrinterProtocol> getAvailableProtocols() {
    return List.unmodifiable(_availableProtocols);
  }
  
  /// Check if a printer model is supported by any protocol
  static bool isPrinterSupported(String printerModel) {
    return getProtocolForPrinter(printerModel) != null;
  }
  
  /// Get protocol information for a printer
  static Map<String, dynamic>? getProtocolInfo(String printerModel) {
    final protocol = getProtocolForPrinter(printerModel);
    if (protocol == null) return null;
    
    return {
      'protocolName': protocol.protocolName,
      'printerModel': printerModel,
      'supported': true,
      'forcedTSPL': protocol.protocolName.contains('TSPL Forced'),
    };
  }
  
  /// Get all supported printer models
  static List<String> getSupportedPrinterModels() {
    final models = <String>[];
    
    // TSPL supported models
    models.addAll([
      'N41', 'N41-001', 'N41-002', 'N41-003',
      'TSPL', 'TSPL2', 'TSPL3',
      'Godex', 'Zebra', 'TSC'
    ]);
    
    // ESC/POS supported models (will use forced TSPL commands)
    models.addAll([
      'KT58L', 'Romeson', 'ESC/POS', 'ESCPOS',
      'Thermal', 'Receipt', 'Label'
    ]);
    
    return models;
  }
  
  /// Auto-detect printer protocol from device name or characteristics
  static PrinterProtocol? autoDetectProtocol({
    String? deviceName,
    String? deviceAddress,
    Map<String, dynamic>? deviceProperties,
  }) {
    // Try to detect from device name first
    if (deviceName != null && deviceName.isNotEmpty) {
      final protocol = getProtocolForPrinter(deviceName);
      if (protocol != null) return protocol;
    }
    
    // Try to detect from device properties
    if (deviceProperties != null) {
      final model = deviceProperties['model'] as String?;
      final manufacturer = deviceProperties['manufacturer'] as String?;
      
      if (model != null) {
        final protocol = getProtocolForPrinter(model);
        if (protocol != null) return protocol;
      }
      
      if (manufacturer != null) {
        final protocol = getProtocolForPrinter(manufacturer);
        if (protocol != null) return protocol;
      }
    }
    
    // Default to TSPL if we can't determine
    print('PrinterFactory: Auto-detection failed, defaulting to TSPL');
    return TSPLProtocol();
  }
  
  /// Get protocol capabilities
  static Map<String, dynamic> getProtocolCapabilities(String printerModel) {
    final protocol = getProtocolForPrinter(printerModel);
    if (protocol == null) {
      return {
        'supported': false,
        'error': 'No protocol found for $printerModel',
      };
    }
    
    final capabilities = <String, dynamic>{
      'supported': true,
      'protocolName': protocol.protocolName,
      'printerModel': printerModel,
      'forcedTSPL': protocol.protocolName.contains('TSPL Forced'),
    };
    
    // Add protocol-specific capabilities
    switch (protocol.protocolName) {
      case 'TSPL':
        capabilities.addAll({
          'gapDetection': true,
          'autoPositioning': true,
          'bufferManagement': true,
          'labelPrinting': true,
          'qrCodeSupport': true,
          'barcodeSupport': true,
          'nativeTSPL': true,
        });
        break;
      case 'ESC/POS (TSPL Forced)':
        capabilities.addAll({
          'gapDetection': true, // Using forced TSPL commands
          'autoPositioning': true, // Using forced TSPL commands
          'bufferManagement': true, // Using forced TSPL commands
          'labelPrinting': true, // Using forced TSPL commands
          'qrCodeSupport': true, // Using forced TSPL commands
          'barcodeSupport': true, // Using forced TSPL commands
          'forcedTSPL': true, // Key difference: forcing TSPL on ESC/POS
          'receiptPrinting': true, // Can still do receipt printing
          'compatibilityMode': true, // Running in TSPL compatibility mode
        });
        break;
    }
    
    return capabilities;
  }
} 