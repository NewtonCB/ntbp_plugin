# NTBP Plugin - Comprehensive Integration Guide

## 🎯 **Overview**

This guide provides comprehensive instructions for integrating the NTBP Plugin into any Flutter application, regardless of the UI framework or design system you're using. The plugin is designed to be **UI-agnostic** - it handles all the complex thermal printing logic while you focus on your app's design.

## 📋 **Table of Contents**

1. [Quick Integration](#quick-integration)
2. [UI Framework Examples](#ui-framework-examples)
3. [Advanced Integration Patterns](#advanced-integration-patterns)
4. [State Management Integration](#state-management-integration)
5. [Error Handling & User Experience](#error-handling--user-experience)
6. [Testing & Debugging](#testing--debugging)
7. [Production Considerations](#production-considerations)

## 🚀 **Quick Integration**

### **Step 1: Add Dependency**

```yaml
dependencies:
  ntbp_plugin: ^1.0.0
```

### **Step 2: Basic Service Class**

Create a service class that handles all printer operations:

```dart
import 'package:ntbp_plugin/ntbp_plugin.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final NtbpPlugin _plugin = NtbpPlugin();
  
  // Singleton pattern for easy access
  static PrinterService get instance => _instance;

  // Connection state
  bool _isConnected = false;
  Map<String, dynamic>? _connectedDevice;
  
  // Getters
  bool get isConnected => _isConnected;
  Map<String, dynamic>? get connectedDevice => _connectedDevice;

  // Initialize the plugin
  Future<bool> initialize() async {
    try {
      final isAvailable = await _plugin.isBluetoothAvailable();
      if (!isAvailable) return false;
      
      final hasPermission = await _plugin.requestBluetoothPermissions();
      return hasPermission;
    } catch (e) {
      print('Initialization failed: $e');
      return false;
    }
  }

  // Scan for devices
  Future<List<Map<String, dynamic>>> scanForDevices() async {
    try {
      return await _plugin.startScan();
    } catch (e) {
      print('Scan failed: $e');
      return [];
    }
  }

  // Connect to device
  Future<bool> connectToDevice(Map<String, dynamic> device) async {
    try {
      await _plugin.connectToDevice(device);
      _connectedDevice = device;
      _isConnected = true;
      return true;
    } catch (e) {
      print('Connection failed: $e');
      return false;
    }
  }

  // Disconnect
  Future<bool> disconnect() async {
    try {
      final success = await _plugin.disconnect();
      if (success) {
        _connectedDevice = null;
        _isConnected = false;
      }
      return success;
    } catch (e) {
      print('Disconnect failed: $e');
      return false;
    }
  }

  // Print single label
  Future<bool> printSingleLabel({
    required String qrData,
    required String textData,
    double width = 75.0,
    double height = 50.0,
    String unit = 'mm',
    int dpi = 203,
    int copies = 1,
    int textSize = 9,
  }) async {
    try {
      if (!_isConnected) return false;
      
      return await _plugin.printSingleLabelWithGapDetection(
        qrData: qrData,
        textData: textData,
        width: width,
        height: height,
        unit: unit,
        dpi: dpi,
        copies: copies,
        textSize: textSize,
      );
    } catch (e) {
      print('Print failed: $e');
      return false;
    }
  }

  // Print multiple labels
  Future<bool> printMultipleLabels({
    required List<Map<String, dynamic>> labelData,
    double width = 75.0,
    double height = 50.0,
    String unit = 'mm',
    int dpi = 203,
    int copiesPerLabel = 1,
    int textSize = 9,
  }) async {
    try {
      if (!_isConnected) return false;
      
      return await _plugin.printMultipleLabelsWithGapDetection(
        labelDataList: labelData,
        width: width,
        height: height,
        unit: unit,
        dpi: dpi,
        copiesPerLabel: copiesPerLabel,
        textSize: textSize,
      );
    } catch (e) {
      print('Multiple labels print failed: $e');
      return false;
    }
  }

  // Utility methods
  Future<bool> clearBuffer() async {
    try {
      return await _plugin.clearBuffer();
    } catch (e) {
      print('Buffer clear failed: $e');
      return false;
    }
  }

  Future<String> getPrinterStatus() async {
    try {
      return await _plugin.getPrinterStatus();
    } catch (e) {
      print('Status check failed: $e');
      return 'ERROR';
    }
  }
}
```

### **Step 3: Use in Your UI**

```dart
class MyPrinterScreen extends StatefulWidget {
  @override
  _MyPrinterScreenState createState() => _MyPrinterScreenState();
}

class _MyPrinterScreenState extends State<MyPrinterScreen> {
  final PrinterService _printerService = PrinterService.instance;
  List<Map<String, dynamic>> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializePrinter();
  }

  Future<void> _initializePrinter() async {
    final success = await _printerService.initialize();
    if (!success) {
      // Handle initialization failure
      print('Printer initialization failed');
    }
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      final devices = await _printerService.scanForDevices();
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      // Handle error
    }
  }

  Future<void> _connectToDevice(Map<String, dynamic> device) async {
    final success = await _printerService.connectToDevice(device);
    if (success) {
      setState(() {}); // Refresh UI
      // Show success message
    } else {
      // Show error message
    }
  }

  Future<void> _printLabel() async {
    final success = await _printerService.printSingleLabel(
      qrData: "QR_${DateTime.now().millisecondsSinceEpoch}",
      textData: "Sample Label",
    );
    
    if (success) {
      // Show success message
    } else {
      // Show error message
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Printer')),
      body: Column(
        children: [
          // Status indicator
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _printerService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: _printerService.isConnected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(_printerService.isConnected ? 'Connected' : 'Disconnected'),
              ],
            ),
          ),
          
          // Scan button
          ElevatedButton(
            onPressed: _isScanning ? null : _startScan,
            child: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
          ),
          
          // Device list
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  title: Text(device['name'] ?? 'Unknown'),
                  subtitle: Text(device['address'] ?? ''),
                  trailing: ElevatedButton(
                    onPressed: () => _connectToDevice(device),
                    child: Text('Connect'),
                  ),
                );
              },
            ),
          ),
          
          // Print button
          if (_printerService.isConnected)
            ElevatedButton(
              onPressed: _printLabel,
              child: Text('Print Label'),
            ),
        ],
      ),
    );
  }
}
```

## 🎨 **UI Framework Examples**

### **Material Design (Material 3)**

```dart
import 'package:flutter/material.dart';

class Material3PrinterScreen extends StatefulWidget {
  @override
  _Material3PrinterScreenState createState() => _Material3PrinterScreenState();
}

class _Material3PrinterScreenState extends State<Material3PrinterScreen> {
  final PrinterService _printerService = PrinterService.instance;
  List<Map<String, dynamic>> _devices = [];
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thermal Printer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _printerService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: _printerService.isConnected ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Printer Status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _printerService.isConnected 
                                ? 'Connected to ${_printerService.connectedDevice?['name']}'
                                : 'Not Connected',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Scan Button
            FilledButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: Icon(_isScanning ? Icons.stop : Icons.search),
              label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
              style: FilledButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Device List
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Press scan to discover devices',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(Icons.bluetooth),
                            title: Text(device['name'] ?? 'Unknown Device'),
                            subtitle: Text(device['address'] ?? ''),
                            trailing: FilledButton(
                              onPressed: () => _connectToDevice(device),
                              child: Text('Connect'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // Print Buttons
            if (_printerService.isConnected) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _printSingleLabel,
                      icon: Icon(Icons.print),
                      label: Text('Single Label'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _printMultipleLabels,
                      icon: Icon(Icons.print_disabled),
                      label: Text('Multiple Labels'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Implementation methods...
  Future<void> _startScan() async { /* ... */ }
  Future<void> _connectToDevice(Map<String, dynamic> device) async { /* ... */ }
  Future<void> _printSingleLabel() async { /* ... */ }
  Future<void> _printMultipleLabels() async { /* ... */ }
}
```

### **Cupertino (iOS Style)**

```dart
import 'package:flutter/cupertino.dart';

class CupertinoPrinterScreen extends StatefulWidget {
  @override
  _CupertinoPrinterScreenState createState() => _CupertinoPrinterScreenState();
}

class _CupertinoPrinterScreenState extends State<CupertinoPrinterScreen> {
  final PrinterService _printerService = PrinterService.instance;
  List<Map<String, dynamic>> _devices = [];
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Thermal Printer'),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Status Container
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _printerService.isConnected ? CupertinoIcons.bluetooth : CupertinoIcons.bluetooth_slash,
                      color: _printerService.isConnected ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Printer Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _printerService.isConnected 
                                ? 'Connected to ${_printerService.connectedDevice?['name']}'
                                : 'Not Connected',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Scan Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _isScanning ? null : _startScan,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isScanning ? CupertinoIcons.stop : CupertinoIcons.search),
                      SizedBox(width: 8),
                      Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Device List
              Expanded(
                child: _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.bluetooth_searching,
                              size: 64,
                              color: CupertinoColors.systemGrey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No devices found',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Press scan to discover devices',
                              style: TextStyle(color: CupertinoColors.systemGrey),
                            ),
                          ],
                        ),
                      )
                    : CupertinoScrollbar(
                        child: ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Icon(CupertinoIcons.bluetooth),
                                title: Text(device['name'] ?? 'Unknown Device'),
                                subtitle: Text(device['address'] ?? ''),
                                trailing: CupertinoButton(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  onPressed: () => _connectToDevice(device),
                                  child: Text('Connect'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              
              // Print Buttons
              if (_printerService.isConnected) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: _printSingleLabel,
                        child: Text('Single Label'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: _printMultipleLabels,
                        child: Text('Multiple Labels'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Implementation methods...
  Future<void> _startScan() async { /* ... */ }
  Future<void> _connectToDevice(Map<String, dynamic> device) async { /* ... */ }
  Future<void> _printSingleLabel() async { /* ... */ }
  Future<void> _printMultipleLabels() async { /* ... */ }
}
```

## 🔄 **Advanced Integration Patterns**

### **Provider Pattern Integration**

```dart
import 'package:flutter/foundation.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

class PrinterProvider extends ChangeNotifier {
  final NtbpPlugin _plugin = NtbpPlugin();
  
  bool _isConnected = false;
  Map<String, dynamic>? _connectedDevice;
  List<Map<String, dynamic>> _devices = [];
  bool _isScanning = false;
  String _status = 'Initializing';
  
  // Getters
  bool get isConnected => _isConnected;
  Map<String, dynamic>? get connectedDevice => _connectedDevice;
  List<Map<String, dynamic>> get devices => _devices;
  bool get isScanning => _isScanning;
  String get status => _status;
  
  // Initialize
  Future<void> initialize() async {
    _updateStatus('Initializing...');
    
    try {
      final isAvailable = await _plugin.isBluetoothAvailable();
      if (!isAvailable) {
        _updateStatus('Bluetooth not available');
        return;
      }
      
      final hasPermission = await _plugin.requestBluetoothPermissions();
      if (!hasPermission) {
        _updateStatus('Permission denied');
        return;
      }
      
      _updateStatus('Ready to scan');
    } catch (e) {
      _updateStatus('Initialization failed: $e');
    }
  }
  
  // Scan for devices
  Future<void> scanForDevices() async {
    if (_isScanning) return;
    
    _setScanning(true);
    _updateStatus('Scanning for devices...');
    
    try {
      final devices = await _plugin.startScan();
      _devices = devices;
      _updateStatus('Found ${devices.length} devices');
    } catch (e) {
      _updateStatus('Scan failed: $e');
    } finally {
      _setScanning(false);
    }
  }
  
  // Connect to device
  Future<void> connectToDevice(Map<String, dynamic> device) async {
    _updateStatus('Connecting to ${device['name']}...');
    
    try {
      await _plugin.connectToDevice(device);
      _connectedDevice = device;
      _isConnected = true;
      _updateStatus('Connected to ${device['name']}');
    } catch (e) {
      _updateStatus('Connection failed: $e');
    }
  }
  
  // Disconnect
  Future<void> disconnect() async {
    if (!_isConnected) return;
    
    _updateStatus('Disconnecting...');
    
    try {
      final success = await _plugin.disconnect();
      if (success) {
        _connectedDevice = null;
        _isConnected = false;
        _updateStatus('Disconnected');
      }
    } catch (e) {
      _updateStatus('Disconnect failed: $e');
    }
  }
  
  // Print single label
  Future<void> printSingleLabel({
    required String qrData,
    required String textData,
    double width = 75.0,
    double height = 50.0,
    String unit = 'mm',
    int dpi = 203,
    int copies = 1,
    int textSize = 9,
  }) async {
    if (!_isConnected) {
      _updateStatus('Not connected to printer');
      return;
    }
    
    _updateStatus('Printing label...');
    
    try {
      final success = await _plugin.printSingleLabelWithGapDetection(
        qrData: qrData,
        textData: textData,
        width: width,
        height: height,
        unit: unit,
        dpi: dpi,
        copies: copies,
        textSize: textSize,
      );
      
      if (success) {
        _updateStatus('Label printed successfully!');
      } else {
        _updateStatus('Print failed');
      }
    } catch (e) {
      _updateStatus('Print error: $e');
    }
  }
  
  // Print multiple labels
  Future<void> printMultipleLabels({
    required List<Map<String, dynamic>> labelData,
    double width = 75.0,
    double height = 50.0,
    String unit = 'mm',
    int dpi = 203,
    int copiesPerLabel = 1,
    int textSize = 9,
  }) async {
    if (!_isConnected) {
      _updateStatus('Not connected to printer');
      return;
    }
    
    _updateStatus('Printing ${labelData.length} labels...');
    
    try {
      final success = await _plugin.printMultipleLabelsWithGapDetection(
        labelDataList: labelData,
        width: width,
        height: height,
        unit: unit,
        dpi: dpi,
        copiesPerLabel: copiesPerLabel,
        textSize: textSize,
      );
      
      if (success) {
        _updateStatus('All labels printed successfully!');
      } else {
        _updateStatus('Some labels failed to print');
      }
    } catch (e) {
      _updateStatus('Print error: $e');
    }
  }
  
  // Utility methods
  Future<void> clearBuffer() async {
    if (!_isConnected) return;
    
    _updateStatus('Clearing buffer...');
    
    try {
      final success = await _plugin.clearBuffer();
      if (success) {
        _updateStatus('Buffer cleared');
      } else {
        _updateStatus('Buffer clear failed');
      }
    } catch (e) {
      _updateStatus('Buffer clear error: $e');
    }
  }
  
  // Private methods
  void _setScanning(bool scanning) {
    _isScanning = scanning;
    notifyListeners();
  }
  
  void _updateStatus(String status) {
    _status = status;
    notifyListeners();
  }
}
```

### **Riverpod Integration**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

// Provider for printer service
final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});

// Provider for printer state
final printerStateProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  return PrinterNotifier(ref.read(printerServiceProvider));
});

// Printer state class
class PrinterState {
  final bool isConnected;
  final Map<String, dynamic>? connectedDevice;
  final List<Map<String, dynamic>> devices;
  final bool isScanning;
  final String status;
  final bool isLoading;
  
  const PrinterState({
    this.isConnected = false,
    this.connectedDevice,
    this.devices = const [],
    this.isScanning = false,
    this.status = 'Initializing',
    this.isLoading = false,
  });
  
  PrinterState copyWith({
    bool? isConnected,
    Map<String, dynamic>? connectedDevice,
    List<Map<String, dynamic>>? devices,
    bool? isScanning,
    String? status,
    bool? isLoading,
  }) {
    return PrinterState(
      isConnected: isConnected ?? this.isConnected,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Printer notifier
class PrinterNotifier extends StateNotifier<PrinterState> {
  final PrinterService _printerService;
  
  PrinterNotifier(this._printerService) : super(const PrinterState()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true, status: 'Initializing...');
    
    try {
      final success = await _printerService.initialize();
      if (success) {
        state = state.copyWith(status: 'Ready to scan', isLoading: false);
      } else {
        state = state.copyWith(status: 'Initialization failed', isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(status: 'Error: $e', isLoading: false);
    }
  }
  
  Future<void> scanForDevices() async {
    if (state.isScanning) return;
    
    state = state.copyWith(isScanning: true, status: 'Scanning...');
    
    try {
      final devices = await _printerService.scanForDevices();
      state = state.copyWith(
        devices: devices,
        isScanning: false,
        status: 'Found ${devices.length} devices',
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        status: 'Scan failed: $e',
      );
    }
  }
  
  Future<void> connectToDevice(Map<String, dynamic> device) async {
    state = state.copyWith(status: 'Connecting...');
    
    try {
      final success = await _printerService.connectToDevice(device);
      if (success) {
        state = state.copyWith(
          isConnected: true,
          connectedDevice: device,
          status: 'Connected to ${device['name']}',
        );
      } else {
        state = state.copyWith(status: 'Connection failed');
      }
    } catch (e) {
      state = state.copyWith(status: 'Error: $e');
    }
  }
  
  Future<void> disconnect() async {
    if (!state.isConnected) return;
    
    state = state.copyWith(status: 'Disconnecting...');
    
    try {
      final success = await _printerService.disconnect();
      if (success) {
        state = state.copyWith(
          isConnected: false,
          connectedDevice: null,
          status: 'Disconnected',
        );
      }
    } catch (e) {
      state = state.copyWith(status: 'Error: $e');
    }
  }
  
  Future<void> printSingleLabel({
    required String qrData,
    required String textData,
    double width = 75.0,
    double height = 50.0,
    String unit = 'mm',
    int dpi = 203,
    int copies = 1,
    int textSize = 9,
  }) async {
    if (!state.isConnected) {
      state = state.copyWith(status: 'Not connected');
      return;
    }
    
    state = state.copyWith(status: 'Printing...');
    
    try {
      final success = await _printerService.printSingleLabel(
        qrData: qrData,
        textData: textData,
        width: width,
        height: height,
        unit: unit,
        dpi: dpi,
        copies: copies,
        textSize: textSize,
      );
      
      if (success) {
        state = state.copyWith(status: 'Print successful!');
      } else {
        state = state.copyWith(status: 'Print failed');
      }
    } catch (e) {
      state = state.copyWith(status: 'Error: $e');
    }
  }
  
  Future<void> printMultipleLabels({
    required List<Map<String, dynamic>> labelData,
    double width = 75.0,
    double height = 50.0,
    String unit = 'mm',
    int dpi = 203,
    int copiesPerLabel = 1,
    int textSize = 9,
  }) async {
    if (!state.isConnected) {
      state = state.copyWith(status: 'Not connected');
      return;
    }
    
    state = state.copyWith(status: 'Printing ${labelData.length} labels...');
    
    try {
      final success = await _printerService.printMultipleLabels(
        labelData: labelData,
        width: width,
        height: height,
        unit: unit,
        dpi: dpi,
        copiesPerLabel: copiesPerLabel,
        textSize: textSize,
      );
      
      if (success) {
        state = state.copyWith(status: 'All labels printed!');
      } else {
        state = state.copyWith(status: 'Some labels failed');
      }
    } catch (e) {
      state = state.copyWith(status: 'Error: $e');
    }
  }
}
```

## 🚨 **Error Handling & User Experience**

### **Comprehensive Error Handling**

```dart
class PrinterErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    }
    
    if (error.toString().contains('BLUETOOTH_NOT_AVAILABLE')) {
      return 'Bluetooth is not available on this device';
    }
    
    if (error.toString().contains('BLUETOOTH_UNAUTHORIZED')) {
      return 'Bluetooth permission denied. Please enable in settings.';
    }
    
    if (error.toString().contains('NOT_CONNECTED')) {
      return 'Not connected to printer. Please connect first.';
    }
    
    if (error.toString().contains('DEVICE_NOT_FOUND')) {
      return 'Printer not found. Please ensure it\'s powered on and in pairing mode.';
    }
    
    if (error.toString().contains('CONNECTION_FAILED')) {
      return 'Connection failed. Please try again.';
    }
    
    if (error.toString().contains('PRINTING_ERROR')) {
      return 'Printing failed. Please check printer status and try again.';
    }
    
    return 'An unexpected error occurred: $error';
  }
  
  static String getErrorTitle(dynamic error) {
    if (error.toString().contains('BLUETOOTH')) {
      return 'Bluetooth Error';
    }
    
    if (error.toString().contains('CONNECTION')) {
      return 'Connection Error';
    }
    
    if (error.toString().contains('PRINTING')) {
      return 'Printing Error';
    }
    
    return 'Error';
  }
  
  static IconData getErrorIcon(dynamic error) {
    if (error.toString().contains('BLUETOOTH')) {
      return Icons.bluetooth_disabled;
    }
    
    if (error.toString().contains('CONNECTION')) {
      return Icons.link_off;
    }
    
    if (error.toString().contains('PRINTING')) {
      return Icons.print_disabled;
    }
    
    return Icons.error;
  }
}
```

### **User-Friendly Error Display**

```dart
class ErrorDialog extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  
  const ErrorDialog({
    Key? key,
    required this.error,
    this.onRetry,
    this.onDismiss,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        PrinterErrorHandler.getErrorIcon(error),
        color: Colors.red,
        size: 48,
      ),
      title: Text(PrinterErrorHandler.getErrorTitle(error)),
      content: Text(PrinterErrorHandler.getErrorMessage(error)),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: Text('Dismiss'),
          ),
        if (onRetry != null)
          ElevatedButton(
            onPressed: onRetry,
            child: Text('Retry'),
          ),
      ],
    );
  }
}
```

### **Loading States & Progress Indicators**

```dart
class PrinterLoadingOverlay extends StatelessWidget {
  final String message;
  final bool showProgress;
  final double? progress;
  
  const PrinterLoadingOverlay({
    Key? key,
    required this.message,
    this.showProgress = false,
    this.progress,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (showProgress && progress != null) ...[
                  SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  SizedBox(height: 8),
                  Text('${(progress! * 100).toInt()}%'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

## 🧪 **Testing & Debugging**

### **Unit Tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

void main() {
  group('PrinterService Tests', () {
    late PrinterService printerService;
    
    setUp(() {
      printerService = PrinterService();
    });
    
    test('should initialize successfully', () async {
      // Mock the plugin calls
      // Test initialization flow
    });
    
    test('should scan for devices', () async {
      // Mock device discovery
      // Test scan functionality
    });
    
    test('should connect to device', () async {
      // Mock connection
      // Test connection flow
    });
    
    test('should print single label', () async {
      // Mock printing
      // Test print functionality
    });
    
    test('should print multiple labels', () async {
      // Mock batch printing
      // Test multiple labels functionality
    });
  });
}
```

### **Integration Tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Printer Integration Tests', () {
    testWidgets('should scan and connect to printer', (tester) async {
      // Test full integration flow
      // Scan, connect, print
    });
    
    testWidgets('should handle connection errors gracefully', (tester) async {
      // Test error scenarios
      // Network issues, printer offline, etc.
    });
    
    testWidgets('should print labels successfully', (tester) async {
      // Test actual printing
      // Verify output quality
    });
  });
}
```

## 🚀 **Production Considerations**

### **Performance Optimization**

```dart
class OptimizedPrinterService {
  // Cache connection state
  static bool _isConnected = false;
  static Map<String, dynamic>? _connectedDevice;
  
  // Debounce scan operations
  static Timer? _scanDebounceTimer;
  
  // Connection pooling
  static final Map<String, DateTime> _connectionCache = {};
  
  // Optimized scan with debouncing
  static Future<List<Map<String, dynamic>>> scanForDevices() async {
    if (_scanDebounceTimer?.isActive ?? false) {
      _scanDebounceTimer!.cancel();
    }
    
    return Future.delayed(Duration(milliseconds: 300), () async {
      // Perform actual scan
      return await _performScan();
    });
  }
  
  // Connection caching
  static Future<bool> connectToDevice(Map<String, dynamic> device) async {
    final deviceId = device['address'];
    final now = DateTime.now();
    
    // Check if we have a recent connection
    if (_connectionCache.containsKey(deviceId)) {
      final lastConnection = _connectionCache[deviceId]!;
      if (now.difference(lastConnection).inMinutes < 5) {
        // Reuse existing connection
        return true;
      }
    }
    
    // Perform new connection
    final success = await _performConnection(device);
    if (success) {
      _connectionCache[deviceId] = now;
    }
    
    return success;
  }
}
```

### **Error Recovery & Resilience**

```dart
class ResilientPrinterService {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Retry mechanism for critical operations
  static Future<bool> printWithRetry({
    required Future<bool> Function() printOperation,
    int maxAttempts = maxRetries,
  }) async {
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      try {
        final result = await printOperation();
        if (result) return true;
        
        attempts++;
        if (attempts < maxAttempts) {
          await Future.delayed(retryDelay * attempts);
        }
      } catch (e) {
        attempts++;
        if (attempts < maxAttempts) {
          await Future.delayed(retryDelay * attempts);
        } else {
          rethrow;
        }
      }
    }
    
    return false;
  }
  
  // Automatic reconnection
  static Future<bool> ensureConnection() async {
    if (_isConnected) return true;
    
    // Try to reconnect to last known device
    if (_connectedDevice != null) {
      return await connectToDevice(_connectedDevice!);
    }
    
    return false;
  }
}
```

## 📱 **Platform-Specific Considerations**

### **Android Specific**

```dart
class AndroidPrinterService extends PrinterService {
  @override
  Future<bool> initialize() async {
    // Android-specific initialization
    // Handle runtime permissions
    // Check Android version compatibility
    
    if (Platform.isAndroid) {
      // Request location permission for Bluetooth scanning
      final locationPermission = await Permission.location.request();
      if (!locationPermission.isGranted) {
        return false;
      }
    }
    
    return await super.initialize();
  }
}
```

### **iOS Specific**

```dart
class IOSPrinterService extends PrinterService {
  @override
  Future<bool> initialize() async {
    // iOS-specific initialization
    // Handle CoreBluetooth permissions
    // Check iOS version compatibility
    
    if (Platform.isIOS) {
      // iOS handles Bluetooth permissions automatically
      // Just check availability
    }
    
    return await super.initialize();
  }
}
```

## 🎯 **Best Practices Summary**

1. **Always use the service pattern** - Keep printer logic separate from UI
2. **Handle errors gracefully** - Provide user-friendly error messages
3. **Show loading states** - Keep users informed of operation progress
4. **Cache connection state** - Avoid unnecessary reconnections
5. **Implement retry logic** - Handle transient failures automatically
6. **Test thoroughly** - Unit tests, integration tests, and real device testing
7. **Monitor performance** - Track connection times and success rates
8. **Provide fallbacks** - Graceful degradation when features aren't available

---

This comprehensive guide ensures that your NTBP Plugin integration will work seamlessly with any UI implementation while providing a robust, user-friendly experience. The plugin handles all the complex thermal printing logic, allowing you to focus on creating beautiful, intuitive interfaces for your users. 