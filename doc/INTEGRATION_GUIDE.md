# NTBP Plugin - Integration Guide

## 🚀 Complete Integration Guide for Flutter Apps

This guide provides step-by-step instructions for integrating the NTBP Plugin into your Flutter applications, with real-world examples and best practices.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Basic Setup](#basic-setup)
4. [Simple Integration](#simple-integration)
5. [Advanced Integration](#advanced-integration)
6. [Real-World Examples](#real-world-examples)
7. [Troubleshooting](#troubleshooting)
8. [Performance Optimization](#performance-optimization)
9. [Testing](#testing)

## ✅ Prerequisites

Before integrating the NTBP Plugin, ensure you have:

- **Flutter SDK**: Version 3.19.0 or higher
- **Dart SDK**: Version 3.3.0 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Physical Android Device** for testing (Bluetooth functionality)
- **Thermal Printer** compatible with TSPL commands

### Supported Platforms

| Platform | Minimum Version | Status |
|----------|----------------|---------|
| Android | API 21 (Android 5.0) | ✅ Fully Supported |
| iOS | 12.0+ | 🚧 In Development |

## 📦 Installation

### 1. Add Dependency

Add the NTBP Plugin to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Add the NTBP Plugin
  ntbp_plugin: ^1.0.0
  
  # Optional: For better state management
  provider: ^6.0.0
  
  # Optional: For HTTP requests (if fetching data from backend)
  http: ^1.1.0
```

### 2. Install Dependencies

Run the following command in your project directory:

```bash
flutter pub get
```

### 3. Platform-Specific Setup

#### Android Setup

1. **Update AndroidManifest.xml** (`android/app/src/main/AndroidManifest.xml`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Bluetooth Permissions -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    
    <!-- Location Permissions (Required for Bluetooth scanning) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Bluetooth Features -->
    <uses-feature android:name="android.hardware.bluetooth" android:required="true" />
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />
    
    <application>
        <!-- Your app configuration -->
    </application>
</manifest>
```

2. **Update build.gradle** (`android/app/build.gradle.kts`):

```kotlin
android {
    compileSdk 34
    
    defaultConfig {
        minSdk 21
        targetSdk 34
        // ... other config
    }
    
    ndkVersion "27.0.12077973"
    
    // ... rest of config
}
```

#### iOS Setup

1. **Update Info.plist** (`ios/Runner/Info.plist`):

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to thermal printers for printing labels and receipts.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect to thermal printers for printing labels and receipts.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses location to scan for Bluetooth devices.</string>
```

2. **Add Bluetooth Capability** in Xcode:
   - Open `ios/Runner.xcworkspace`
   - Select Runner target → Signing & Capabilities
   - Click "+ Capability" → Add "Bluetooth"

## 🔧 Basic Setup

### 1. Import the Plugin

```dart
import 'package:ntbp_plugin/ntbp_plugin.dart';
```

### 2. Initialize the Plugin

```dart
class PrinterService {
  final NtbpPlugin _plugin = NtbpPlugin();
  
  Future<void> initialize() async {
    try {
      // Check Bluetooth availability
      final isAvailable = await _plugin.isBluetoothAvailable();
      if (!isAvailable) {
        throw Exception('Bluetooth not available');
      }
      
      // Request permissions
      final hasPermissions = await _plugin.requestBluetoothPermissions();
      if (!hasPermissions) {
        throw Exception('Bluetooth permissions denied');
      }
      
      print('✅ Plugin initialized successfully');
    } catch (e) {
      print('❌ Initialization failed: $e');
      rethrow;
    }
  }
}
```

### 3. Basic Usage Pattern

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final NtbpPlugin _printer = NtbpPlugin();
  BluetoothDevice? _connectedDevice;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializePrinter();
  }
  
  Future<void> _initializePrinter() async {
    try {
      await _printer.isBluetoothAvailable();
      await _printer.requestBluetoothPermissions();
      setState(() => _isInitialized = true);
    } catch (e) {
      print('Initialization error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('NTBP Plugin Demo')),
        body: _isInitialized 
          ? _buildMainContent() 
          : Center(child: CircularProgressIndicator()),
      ),
    );
  }
  
  Widget _buildMainContent() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _scanForDevices,
          child: Text('Scan for Printers'),
        ),
        if (_connectedDevice != null) ...[
          Text('Connected: ${_connectedDevice!.name}'),
          ElevatedButton(
            onPressed: _printTestLabel,
            child: Text('Print Test Label'),
          ),
        ],
      ],
    );
  }
}
```

## 🔗 Simple Integration

### 1. Basic Printer Integration

```dart
class SimplePrinterIntegration {
  final NtbpPlugin _plugin = NtbpPlugin();
  BluetoothDevice? _connectedDevice;
  
  // Initialize and scan
  Future<List<BluetoothDevice>> setupAndScan() async {
    try {
      // Initialize
      await _plugin.isBluetoothAvailable();
      await _plugin.requestBluetoothPermissions();
      
      // Scan for devices
      final devices = await _plugin.startScan();
      print('Found ${devices.length} devices');
      
      return devices;
    } catch (e) {
      print('Setup failed: $e');
      return [];
    }
  }
  
  // Connect to device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await _plugin.connectToDevice(device);
      _connectedDevice = device;
      
      final status = await _plugin.getConnectionStatus();
      return status == 'CONNECTED';
    } catch (e) {
      print('Connection failed: $e');
      return false;
    }
  }
  
  // Print simple label
  Future<bool> printLabel(String qrData, String textData) async {
    if (_connectedDevice == null) return false;
    
    try {
      return await _plugin.printSingleLabelWithGapDetection(
        qrData: qrData,
        textData: textData,
        width: 75.0,
        height: 50.0,
        unit: 'mm',
        dpi: 203,
      );
    } catch (e) {
      print('Printing failed: $e');
      return false;
    }
  }
}
```

### 2. Widget Integration

```dart
class PrinterWidget extends StatefulWidget {
  @override
  _PrinterWidgetState createState() => _PrinterWidgetState();
}

class _PrinterWidgetState extends State<PrinterWidget> {
  final SimplePrinterIntegration _printer = SimplePrinterIntegration();
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isPrinting = false;
  
  @override
  void initState() {
    super.initState();
    _scanForDevices();
  }
  
  Future<void> _scanForDevices() async {
    final devices = await _printer.setupAndScan();
    setState(() => _devices = devices);
  }
  
  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isPrinting = true);
    
    final success = await _printer.connectToDevice(device);
    
    setState(() {
      _isConnected = success;
      _selectedDevice = success ? device : null;
      _isPrinting = false;
    });
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Connected to ${device.name}')),
      );
    }
  }
  
  Future<void> _printLabel() async {
    if (!_isConnected) return;
    
    setState(() => _isPrinting = true);
    
    final success = await _printer.printLabel(
      'PROD001',
      'Sample Product',
    );
    
    setState(() => _isPrinting = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '✅ Label printed!' : '❌ Printing failed'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thermal Printer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            
            // Device List
            if (_devices.isNotEmpty) ...[
              Text('Available Devices:', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 8),
              ...(_devices.map((device) => ListTile(
                title: Text(device.name),
                subtitle: Text(device.address),
                trailing: _isConnected && _selectedDevice == device
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : TextButton(
                      onPressed: _isPrinting ? null : () => _connectToDevice(device),
                      child: Text('Connect'),
                    ),
              ))),
            ] else ...[
              Center(child: Text('No devices found')),
            ],
            
            SizedBox(height: 16),
            
            // Print Button
            if (_isConnected) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPrinting ? null : _printLabel,
                  child: _isPrinting 
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Printing...'),
                        ],
                      )
                    : Text('Print Test Label'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

## 🚀 Advanced Integration

### 1. State Management with Provider

```dart
// printer_provider.dart
import 'package:flutter/foundation.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

class PrinterProvider with ChangeNotifier {
  final NtbpPlugin _plugin = NtbpPlugin();
  
  BluetoothDevice? _connectedDevice;
  List<BluetoothDevice> _discoveredDevices = [];
  String _connectionStatus = 'DISCONNECTED';
  bool _isScanning = false;
  bool _isPrinting = false;
  String? _lastError;
  
  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  String get connectionStatus => _connectionStatus;
  bool get isScanning => _isScanning;
  bool get isPrinting => _isPrinting;
  String? get lastError => _lastError;
  bool get isConnected => _connectionStatus == 'CONNECTED';
  
  // Initialize
  Future<void> initialize() async {
    try {
      await _plugin.isBluetoothAvailable();
      await _plugin.requestBluetoothPermissions();
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }
  
  // Scan for devices
  Future<void> scanForDevices() async {
    if (_isScanning) return;
    
    _isScanning = true;
    _discoveredDevices.clear();
    notifyListeners();
    
    try {
      final devices = await _plugin.startScan();
      _discoveredDevices = devices;
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
  
  // Connect to device
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_isPrinting) return;
    
    _isPrinting = true;
    _connectionStatus = 'CONNECTING';
    notifyListeners();
    
    try {
      await _plugin.connectToDevice(device);
      
      final status = await _plugin.getConnectionStatus();
      _connectionStatus = status;
      
      if (status == 'CONNECTED') {
        _connectedDevice = device;
        _lastError = null;
      } else {
        _lastError = 'Connection failed: $status';
      }
    } catch (e) {
      _lastError = e.toString();
      _connectionStatus = 'ERROR';
    } finally {
      _isPrinting = false;
      notifyListeners();
    }
  }
  
  // Disconnect
  Future<void> disconnect() async {
    if (_connectedDevice == null) return;
    
    try {
      await _plugin.disconnect();
      _connectedDevice = null;
      _connectionStatus = 'DISCONNECTED';
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      notifyListeners();
    }
  }
  
  // Print single label
  Future<bool> printSingleLabel({
    required String qrData,
    required String textData,
    double width = 75.0,
    double height = 50.0,
    int copies = 1,
    int textSize = 9,
  }) async {
    if (!isConnected) return false;
    
    _isPrinting = true;
    notifyListeners();
    
    try {
      final success = await _plugin.printSingleLabelWithGapDetection(
        qrData: qrData,
        textData: textData,
        width: width,
        height: height,
        unit: 'mm',
        dpi: 203,
        copies: copies,
        textSize: textSize,
      );
      
      _lastError = success ? null : 'Printing failed';
      return success;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isPrinting = false;
      notifyListeners();
    }
  }
  
  // Print multiple labels
  Future<bool> printMultipleLabels(List<Map<String, String>> labelData) async {
    if (!isConnected) return false;
    
    _isPrinting = true;
    notifyListeners();
    
    try {
      final success = await _plugin.printMultipleLabelsWithGapDetection(
        labelDataList: labelData,
        width: 75.0,
        height: 50.0,
        unit: 'mm',
        dpi: 203,
        copiesPerLabel: 1,
        textSize: 9,
      );
      
      _lastError = success ? null : 'Multiple labels printing failed';
      return success;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isPrinting = false;
      notifyListeners();
    }
  }
  
  // Clear error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}
```

### 2. Advanced Widget with Provider

```dart
// advanced_printer_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'printer_provider.dart';

class AdvancedPrinterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PrinterProvider()..initialize(),
      child: Consumer<PrinterProvider>(
        builder: (context, printer, child) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, printer),
                  SizedBox(height: 16),
                  _buildDeviceList(context, printer),
                  SizedBox(height: 16),
                  _buildPrintingControls(context, printer),
                  if (printer.lastError != null) ...[
                    SizedBox(height: 16),
                    _buildErrorDisplay(context, printer),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, PrinterProvider printer) {
    return Row(
      children: [
        Icon(
          printer.isConnected ? Icons.print : Icons.print_disabled,
          color: printer.isConnected ? Colors.green : Colors.grey,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thermal Printer',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                printer.connectionStatus,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(printer.connectionStatus),
                ),
              ),
            ],
          ),
        ),
        if (printer.isConnected) ...[
          IconButton(
            onPressed: printer.disconnect,
            icon: Icon(Icons.disconnect),
            tooltip: 'Disconnect',
          ),
        ],
      ],
    );
  }
  
  Widget _buildDeviceList(BuildContext context, PrinterProvider printer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Available Devices', style: Theme.of(context).textTheme.titleMedium),
            Spacer(),
            if (printer.isScanning)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            TextButton(
              onPressed: printer.isScanning ? null : printer.scanForDevices,
              child: Text(printer.isScanning ? 'Scanning...' : 'Scan'),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (printer.discoveredDevices.isNotEmpty) ...[
          ...(printer.discoveredDevices.map((device) => _buildDeviceTile(context, printer, device))),
        ] else ...[
          Center(
            child: Text(
              'No devices found',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildDeviceTile(BuildContext context, PrinterProvider printer, BluetoothDevice device) {
    final isConnected = printer.connectedDevice?.address == device.address;
    
    return ListTile(
      leading: Icon(
        isConnected ? Icons.check_circle : Icons.bluetooth,
        color: isConnected ? Colors.green : Colors.blue,
      ),
      title: Text(device.name),
      subtitle: Text(device.address),
      trailing: isConnected
        ? Chip(
            label: Text('Connected'),
            backgroundColor: Colors.green.shade100,
            labelStyle: TextStyle(color: Colors.green.shade800),
          )
        : TextButton(
            onPressed: printer.isPrinting ? null : () => printer.connectToDevice(device),
            child: Text('Connect'),
          ),
    );
  }
  
  Widget _buildPrintingControls(BuildContext context, PrinterProvider printer) {
    if (!printer.isConnected) return SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Printing Controls', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 16),
        
        // Single Label Printing
        _buildPrintSection(
          context,
          title: 'Single Label',
          onPrint: () => _showSingleLabelDialog(context, printer),
        ),
        
        SizedBox(height: 16),
        
        // Multiple Labels Printing
        _buildPrintSection(
          context,
          title: 'Multiple Labels',
          onPrint: () => _showMultipleLabelsDialog(context, printer),
        ),
      ],
    );
  }
  
  Widget _buildPrintSection(BuildContext context, {
    required String title,
    required VoidCallback onPrint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPrint,
            child: Text('Print $title'),
          ),
        ),
      ],
    );
  }
  
  Widget _buildErrorDisplay(BuildContext context, PrinterProvider printer) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              printer.lastError!,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
          IconButton(
            onPressed: printer.clearError,
            icon: Icon(Icons.close, color: Colors.red),
            tooltip: 'Clear Error',
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'CONNECTED':
        return Colors.green;
      case 'CONNECTING':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  void _showSingleLabelDialog(BuildContext context, PrinterProvider printer) {
    final qrController = TextEditingController(text: 'PROD001');
    final textController = TextEditingController(text: 'Sample Product');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Print Single Label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qrController,
              decoration: InputDecoration(
                labelText: 'QR Code Data',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: 'Text Data',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await printer.printSingleLabel(
                qrData: qrController.text,
                textData: textController.text,
              );
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '✅ Label printed!' : '❌ Printing failed'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: Text('Print'),
          ),
        ],
      ),
    );
  }
  
  void _showMultipleLabelsDialog(BuildContext context, PrinterProvider printer) {
    final labels = <Map<String, String>>[
      {'qrData': 'QR001', 'textData': 'Product A'},
      {'qrData': 'QR002', 'textData': 'Product B'},
      {'qrData': 'QR003', 'textData': 'Product C'},
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Print Multiple Labels'),
        content: Text('Print ${labels.length} labels with different content?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await printer.printMultipleLabels(labels);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '✅ Labels printed!' : '❌ Printing failed'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: Text('Print'),
          ),
        ],
      ),
    );
  }
}
```

## 🌟 Real-World Examples

### 1. E-commerce Inventory App

```dart
// inventory_printer_service.dart
class InventoryPrinterService {
  final NtbpPlugin _plugin = NtbpPlugin();
  BluetoothDevice? _connectedDevice;
  
  Future<void> printProductLabel(Product product) async {
    if (_connectedDevice == null) {
      throw Exception('No printer connected');
    }
    
    final success = await _plugin.printSingleLabelWithGapDetection(
      qrData: product.sku,
      textData: '${product.name}\n\$${product.price}',
      width: 75.0,
      height: 50.0,
      unit: 'mm',
      dpi: 203,
      copies: product.labelCopies,
      textSize: 9,
    );
    
    if (!success) {
      throw Exception('Failed to print product label');
    }
  }
  
  Future<void> printBatchLabels(List<Product> products) async {
    if (_connectedDevice == null) {
      throw Exception('No printer connected');
    }
    
    final labelData = products.map((product) => {
      'qrData': product.sku,
      'textData': '${product.name}\n\$${product.price}',
    }).toList();
    
    final success = await _plugin.printMultipleLabelsWithGapDetection(
      labelDataList: labelData,
      width: 75.0,
      height: 50.0,
      unit: 'mm',
      dpi: 203,
      copiesPerLabel: 1,
      textSize: 9,
    );
    
    if (!success) {
      throw Exception('Failed to print batch labels');
    }
  }
}

// inventory_screen.dart
class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryPrinterService _printerService = InventoryPrinterService();
  List<Product> _products = [];
  bool _isPrinting = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Management'),
        actions: [
          IconButton(
            onPressed: _showPrinterSetup,
            icon: Icon(Icons.print),
            tooltip: 'Printer Setup',
          ),
        ],
      ),
      body: Column(
        children: [
          // Product list
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('SKU: ${product.sku} - \$${product.price}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${product.quantity}'),
                      IconButton(
                        onPressed: _isPrinting ? null : () => _printProductLabel(product),
                        icon: Icon(Icons.print),
                        tooltip: 'Print Label',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Batch printing
          if (_products.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPrinting ? null : _printAllLabels,
                  child: _isPrinting 
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Printing...'),
                        ],
                      )
                    : Text('Print All Labels (${_products.length})'),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _printProductLabel(Product product) async {
    setState(() => _isPrinting = true);
    
    try {
      await _printerService.printProductLabel(product);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Label printed for ${product.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to print label: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isPrinting = false);
    }
  }
  
  Future<void> _printAllLabels() async {
    setState(() => _isPrinting = true);
    
    try {
      await _printerService.printBatchLabels(_products);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ All labels printed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to print labels: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isPrinting = false);
    }
  }
  
  void _showPrinterSetup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: AdvancedPrinterWidget(),
      ),
    );
  }
}
```

### 2. Restaurant Order System

```dart
// order_printer_service.dart
class OrderPrinterService {
  final NtbpPlugin _plugin = NtbpPlugin();
  BluetoothDevice? _connectedDevice;
  
  Future<void> printOrderReceipt(Order order) async {
    if (_connectedDevice == null) {
      throw Exception('No printer connected');
    }
    
    // Print order header
    await _printOrderHeader(order);
    
    // Print order items
    for (final item in order.items) {
      await _printOrderItem(item);
    }
    
    // Print order total
    await _printOrderTotal(order);
  }
  
  Future<void> printKitchenLabel(Order order) async {
    if (_connectedDevice == null) {
      throw Exception('No printer connected');
    }
    
    final success = await _plugin.printSingleLabelWithGapDetection(
      qrData: order.orderNumber,
      textData: '${order.tableNumber}\n${order.items.length} items',
      width: 75.0,
      height: 50.0,
      unit: 'mm',
      dpi: 203,
      copies: 1,
      textSize: 9,
    );
    
    if (!success) {
      throw Exception('Failed to print kitchen label');
    }
  }
  
  Future<void> _printOrderHeader(Order order) async {
    // Implementation for printing order header
  }
  
  Future<void> _printOrderItem(OrderItem item) async {
    // Implementation for printing order item
  }
  
  Future<void> _printOrderTotal(Order order) async {
    // Implementation for printing order total
  }
}
```

## 🐛 Troubleshooting

### Common Integration Issues

#### 1. Plugin Not Found
```
Error: Could not find package: ntbp_plugin
```

**Solution:**
- Ensure `flutter pub get` was run
- Check `pubspec.yaml` for correct dependency
- Restart your IDE/editor

#### 2. Platform Channel Errors
```
Error: MissingPluginException
```

**Solution:**
- Clean and rebuild project: `flutter clean && flutter pub get`
- Ensure platform-specific setup is complete
- Check Android/iOS configuration

#### 3. Permission Issues
```
Error: Bluetooth permissions denied
```

**Solution:**
- Check AndroidManifest.xml permissions
- Request permissions at runtime
- Guide users to app settings

#### 4. Connection Failures
```
Error: Connection failed
```

**Solution:**
- Verify Bluetooth is enabled
- Check device compatibility
- Implement retry logic

### Debug Checklist

- [ ] Dependencies installed (`flutter pub get`)
- [ ] Platform-specific setup complete
- [ ] Permissions properly configured
- [ ] Bluetooth enabled on device
- [ ] Printer in pairing mode
- [ ] Error handling implemented
- [ ] Logging enabled for debugging

## ⚡ Performance Optimization

### 1. Connection Management
```dart
class OptimizedPrinterService {
  final NtbpPlugin _plugin = NtbpPlugin();
  BluetoothDevice? _connectedDevice;
  Timer? _connectionCheckTimer;
  
  // Implement connection pooling
  Future<void> maintainConnection() async {
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_connectedDevice != null) {
        final status = await _plugin.getConnectionStatus();
        if (status != 'CONNECTED') {
          await _reconnect();
        }
      }
    });
  }
  
  Future<void> _reconnect() async {
    if (_connectedDevice != null) {
      try {
        await _plugin.connectToDevice(_connectedDevice!);
      } catch (e) {
        print('Reconnection failed: $e');
      }
    }
  }
  
  void dispose() {
    _connectionCheckTimer?.cancel();
  }
}
```

### 2. Batch Operations
```dart
// Optimize multiple label printing
Future<void> printOptimizedBatch(List<Map<String, String>> labels) async {
  // Group labels by type for better performance
  final groupedLabels = _groupLabelsByType(labels);
  
  for (final group in groupedLabels.entries) {
    await _plugin.printMultipleLabelsWithGapDetection(
      labelDataList: group.value,
      width: 75.0,
      height: 50.0,
      unit: 'mm',
      dpi: 203,
      copiesPerLabel: 1,
      textSize: 9,
    );
    
    // Add delay between groups to prevent buffer overflow
    await Future.delayed(Duration(milliseconds: 500));
  }
}

Map<String, List<Map<String, String>>> _groupLabelsByType(List<Map<String, String>> labels) {
  final grouped = <String, List<Map<String, String>>>{};
  
  for (final label in labels) {
    final type = label['type'] ?? 'default';
    grouped.putIfAbsent(type, () => []).add(label);
  }
  
  return grouped;
}
```

## 🧪 Testing

### 1. Unit Tests
```dart
// test/printer_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

void main() {
  group('PrinterService Tests', () {
    test('should initialize plugin successfully', () async {
      // Test implementation
    });
    
    test('should handle connection failures gracefully', () async {
      // Test implementation
    });
    
    test('should print labels with correct parameters', () async {
      // Test implementation
    });
  });
}
```

### 2. Integration Tests
```dart
// test/integration/printer_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Printer Integration Tests', () {
    testWidgets('should connect to printer and print label', (tester) async {
      // Test implementation
    });
  });
}
```

### 3. Test Commands
```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/

# Run specific test file
flutter test test/printer_service_test.dart
```

## 📚 Additional Resources

### Documentation
- [API Reference](API_REFERENCE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Development Guide](DEVELOPMENT.md)

### Examples
- [Basic Example](example/lib/main.dart)
- [Advanced Example](example/lib/advanced_example.dart)
- [Integration Examples](example/lib/integration_examples/)

### Support
- [GitHub Issues](https://github.com/yourusername/ntbp_plugin/issues)
- [GitHub Discussions](https://github.com/yourusername/ntbp_plugin/discussions)
- [Documentation](https://github.com/yourusername/ntbp_plugin/docs)

---

This integration guide provides comprehensive instructions for integrating the NTBP Plugin into your Flutter applications. Follow the examples and best practices to create robust, efficient printing solutions for your apps. 