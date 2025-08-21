# NTBP Plugin - Flutter Thermal Bluetooth Label Printer

[![Flutter](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://flutter.dev/docs/development/platform-integration)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-orange.svg)](https://pub.dev/packages/ntbp_plugin)

A comprehensive, production-ready Flutter plugin for thermal Bluetooth label printing with advanced features including gap detection, precise positioning, and support for multiple label formats. **Works with any UI implementation** - the plugin handles all the complexity behind the scenes.

## 🎯 **Why Choose NTBP Plugin?**

- **🔄 UI-Agnostic**: Works seamlessly with any Flutter UI framework (Material, Cupertino, custom)
- **🚀 Production Ready**: Tested extensively with real thermal printers
- **📱 Cross-Platform**: Full Android and iOS support
- **🛡️ Robust**: Advanced error handling and buffer management
- **📚 Well-Documented**: Comprehensive guides and examples
- **🔧 Maintainable**: Clean architecture and extensible design

## 🚀 **Core Features**

- **Bluetooth Connectivity**: Support for both Classic Bluetooth (SPP) and BLE
- **Thermal Printing**: TSPL language support for professional label printing
- **Smart Positioning**: Automatic content centering based on label dimensions
- **Gap Detection**: Intelligent label boundary detection and frame management
- **Multiple Formats**: QR codes, barcodes, text, and combined content printing
- **Batch Processing**: Sequence printing with proper label separation
- **Buffer Management**: Advanced buffer clearing strategies for reliable printing
- **Cross-Platform**: Android and iOS support with identical APIs

## 📱 **Supported Printers**

- **TSPL-Compatible Printers**: N41, N42, and similar thermal label printers
- **Resolution**: 203 DPI (8 dots/mm) and higher
- **Label Sizes**: 2" (50mm) to 4.65" (118mm) width
- **Media Types**: Die-cut labels, continuous paper, black mark paper

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App                             │
│              (Any UI Framework)                            │
├─────────────────────────────────────────────────────────────┤
│                 ntbp_plugin.dart                           │
│              (Public API Interface)                        │
├─────────────────────────────────────────────────────────────┤
│           ntbp_plugin_platform_interface.dart              │
│              (Abstract Platform Interface)                 │
├─────────────────────────────────────────────────────────────┤
│           ntbp_plugin_method_channel.dart                  │
│              (Flutter Method Channel)                     │
├─────────────────────────────────────────────────────────────┤
│                    Native Implementation                    │
│  ┌─────────────────┐    ┌─────────────────┐               │
│  │   Android       │    │      iOS        │               │
│  │   (Kotlin)      │    │   (Swift)       │               │
│  │                 │    │                 │               │
│  │ • Bluetooth     │    │ • CoreBluetooth │               │
│  │ • TSPL Commands │    │ • TSPL Commands │               │
│  │ • Buffer Mgmt   │    │ • Buffer Mgmt   │               │
│  └─────────────────┘    └─────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

## 📋 **Table of Contents**

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Advanced Features](#advanced-features)
5. [API Reference](#api-reference)
6. [Integration Guide](#integration-guide)
7. [UI Implementation Examples](#ui-implementation-examples)
8. [Troubleshooting](#troubleshooting)
9. [Development Guide](#development-guide)
10. [Contributing](#contributing)

## 🚀 **Quick Start**

### **1. Add Dependency**

```yaml
dependencies:
  ntbp_plugin: ^1.0.0
```

### **2. Basic Implementation (UI-Agnostic)**

```dart
import 'package:ntbp_plugin/ntbp_plugin.dart';

class PrinterService {
  final NtbpPlugin _plugin = NtbpPlugin();
  
  Future<void> printLabel() async {
    try {
      // Initialize plugin
      final isAvailable = await _plugin.isBluetoothAvailable();
      if (!isAvailable) {
        throw Exception('Bluetooth not available');
      }
      
      // Check permissions
      final hasPermission = await _plugin.requestBluetoothPermissions();
      if (!hasPermission) {
        throw Exception('Bluetooth permission denied');
      }
      
      // Scan for devices
      final devices = await _plugin.startScan();
      if (devices.isEmpty) {
        throw Exception('No devices found');
      }
      
      // Connect to device
      await _plugin.connectToDevice(devices.first);
      
      // Print single label
      final success = await _plugin.printSingleLabelWithGapDetection(
        qrData: "QR123456",
        textData: "Sample Label",
        width: 75.0,
        height: 50.0,
        unit: 'mm',
        dpi: 203,
        copies: 1,
        textSize: 9,
      );
      
      if (success) {
        print('Label printed successfully!');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
```

### **3. Advanced Usage - Multiple Labels**

```dart
Future<void> printMultipleLabels() async {
  final labelData = [
    {'qrData': 'QR001', 'textData': 'Product A'},
    {'qrData': 'QR002', 'textData': 'Product B'},
    {'qrData': 'QR003', 'textData': 'Product C'},
  ];
  
  final success = await _plugin.printMultipleLabelsWithGapDetection(
    labelDataList: labelData,
    width: 75.0,
    height: 50.0,
    unit: 'mm',
    dpi: 203,
    copiesPerLabel: 1,
    textSize: 9,
  );
  
  if (success) {
    print('All labels printed successfully!');
  }
}
```

## 📦 **Installation**

### **Flutter Dependencies**

```yaml
dependencies:
  flutter:
    sdk: flutter
  ntbp_plugin: ^1.0.0
```

### **Android Configuration**

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### **iOS Configuration**

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to thermal printers for label printing.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect to thermal printers for label printing.</string>
```

Create `ios/Runner/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryBluetooth</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>This app uses Bluetooth to connect to thermal printers for label printing functionality.</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

## 🎨 **UI Implementation Examples**

### **Example 1: Material Design UI**

```dart
import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

class MaterialPrinterScreen extends StatefulWidget {
  @override
  _MaterialPrinterScreenState createState() => _MaterialPrinterScreenState();
}

class _MaterialPrinterScreenState extends State<MaterialPrinterScreen> {
  final NtbpPlugin _plugin = NtbpPlugin();
  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _connectedDevice;
  bool _isScanning = false;
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Thermal Printer')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Bluetooth Status
            Card(
              child: ListTile(
                leading: Icon(Icons.bluetooth),
                title: Text('Bluetooth Status'),
                subtitle: Text(_connectedDevice?['name'] ?? 'Not Connected'),
                trailing: _connectedDevice != null
                    ? IconButton(
                        icon: Icon(Icons.disconnect),
                        onPressed: _disconnect,
                      )
                    : null,
              ),
            ),
            
            // Scan Button
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: Icon(_isScanning ? Icons.stop : Icons.search),
              label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
            ),
            
            // Device List
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    title: Text(device['name'] ?? 'Unknown Device'),
                    subtitle: Text(device['address'] ?? ''),
                    trailing: ElevatedButton(
                      onPressed: () => _connectToDevice(device),
                      child: Text('Connect'),
                    ),
                  );
                },
              ),
            ),
            
            // Print Buttons
            if (_connectedDevice != null) ...[
              ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printSingleLabel,
                icon: Icon(Icons.print),
                label: Text('Print Single Label'),
              ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printMultipleLabels,
                icon: Icon(Icons.print_disabled),
                label: Text('Print Multiple Labels'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      final devices = await _plugin.startScan();
      setState(() {
        _devices = devices.cast<Map<String, dynamic>>();
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  Future<void> _connectToDevice(Map<String, dynamic> device) async {
    try {
      await _plugin.connectToDevice(device);
      setState(() => _connectedDevice = device);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device['name']}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      await _plugin.disconnect();
      setState(() => _connectedDevice = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e')),
      );
    }
  }

  Future<void> _printSingleLabel() async {
    setState(() => _isPrinting = true);
    try {
      final success = await _plugin.printSingleLabelWithGapDetection(
        qrData: "QR_${DateTime.now().millisecondsSinceEpoch}",
        textData: "Sample Label",
        width: 75.0,
        height: 50.0,
        unit: 'mm',
        dpi: 203,
        copies: 1,
        textSize: 9,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Label printed successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _printMultipleLabels() async {
    setState(() => _isPrinting = true);
    try {
      final labelData = [
        {'qrData': 'QR001', 'textData': 'Product A'},
        {'qrData': 'QR002', 'textData': 'Product B'},
        {'qrData': 'QR003', 'textData': 'Product C'},
      ];
      
      final success = await _plugin.printMultipleLabelsWithGapDetection(
        labelDataList: labelData,
        width: 75.0,
        height: 50.0,
        unit: 'mm',
        dpi: 203,
        copiesPerLabel: 1,
        textSize: 9,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All labels printed successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    } finally {
      setState(() => _isPrinting = false);
    }
  }
}
```

### **Example 2: Cupertino (iOS Style) UI**

```dart
import 'package:flutter/cupertino.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

class CupertinoPrinterScreen extends StatefulWidget {
  @override
  _CupertinoPrinterScreenState createState() => _CupertinoPrinterScreenState();
}

class _CupertinoPrinterScreenState extends State<CupertinoPrinterScreen> {
  final NtbpPlugin _plugin = NtbpPlugin();
  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _connectedDevice;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Thermal Printer'),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Status Card
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.bluetooth),
                    SizedBox(width: 8.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bluetooth Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_connectedDevice?['name'] ?? 'Not Connected'),
                        ],
                      ),
                    ),
                    if (_connectedDevice != null)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _disconnect,
                        child: Icon(CupertinoIcons.clear),
                      ),
                  ],
                ),
              ),
              
              SizedBox(height: 16.0),
              
              // Scan Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _startScan,
                  child: Text('Scan for Devices'),
                ),
              ),
              
              SizedBox(height: 16.0),
              
              // Device List
              Expanded(
                child: CupertinoScrollbar(
                  child: ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 8.0),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ListTile(
                          title: Text(device['name'] ?? 'Unknown Device'),
                          subtitle: Text(device['address'] ?? ''),
                          trailing: CupertinoButton(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
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
              if (_connectedDevice != null) ...[
                SizedBox(height: 16.0),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _printSingleLabel,
                    child: Text('Print Single Label'),
                  ),
                ),
                SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _printMultipleLabels,
                    child: Text('Print Multiple Labels'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Implementation methods similar to Material example...
  Future<void> _startScan() async { /* ... */ }
  Future<void> _connectToDevice(Map<String, dynamic> device) async { /* ... */ }
  Future<void> _disconnect() async { /* ... */ }
  Future<void> _printSingleLabel() async { /* ... */ }
  Future<void> _printMultipleLabels() async { /* ... */ }
}
```

### **Example 3: Custom UI (No Framework Dependencies)**

```dart
import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

class CustomPrinterScreen extends StatefulWidget {
  @override
  _CustomPrinterScreenState createState() => _CustomPrinterScreenState();
}

class _CustomPrinterScreenState extends State<CustomPrinterScreen> {
  final NtbpPlugin _plugin = NtbpPlugin();
  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _connectedDevice;
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[900]!, Colors.blue[600]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header
              Container(
                padding: EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(
                        Icons.print,
                        color: Colors.white,
                        size: 28.0,
                      ),
                    ),
                    SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thermal Printer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _connectedDevice?['name'] ?? 'Not Connected',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30.0),
                      topRight: Radius.circular(30.0),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Scan Button
                        Container(
                          width: double.infinity,
                          height: 56.0,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange[400]!, Colors.orange[600]!],
                            ),
                            borderRadius: BorderRadius.circular(28.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 8.0,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28.0),
                              onTap: _isScanning ? null : _startScan,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isScanning ? Icons.stop : Icons.search,
                                      color: Colors.white,
                                      size: 24.0,
                                    ),
                                    SizedBox(width: 8.0),
                                    Text(
                                      _isScanning ? 'Scanning...' : 'Scan for Devices',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24.0),
                        
                        // Device List
                        Expanded(
                          child: _devices.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.bluetooth_searching,
                                        size: 64.0,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 16.0),
                                      Text(
                                        'No devices found',
                                        style: TextStyle(
                                          fontSize: 18.0,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Press scan to discover devices',
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _devices.length,
                                  itemBuilder: (context, index) {
                                    final device = _devices[index];
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 12.0),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(16.0),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20.0,
                                          vertical: 8.0,
                                        ),
                                        leading: Container(
                                          padding: EdgeInsets.all(8.0),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                          child: Icon(
                                            Icons.bluetooth,
                                            color: Colors.blue[600],
                                            size: 20.0,
                                          ),
                                        ),
                                        title: Text(
                                          device['name'] ?? 'Unknown Device',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          device['address'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        trailing: Container(
                                          height: 40.0,
                                          child: ElevatedButton(
                                            onPressed: () => _connectToDevice(device),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue[600],
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20.0),
                                              ),
                                            ),
                                            child: Text('Connect'),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        
                        // Print Buttons
                        if (_connectedDevice != null) ...[
                          SizedBox(height: 24.0),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 56.0,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green[400]!, Colors.green[600]!],
                                    ),
                                    borderRadius: BorderRadius.circular(28.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 8.0,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(28.0),
                                      onTap: _printSingleLabel,
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.print,
                                              color: Colors.white,
                                              size: 24.0,
                                            ),
                                            SizedBox(width: 8.0),
                                            Text(
                                              'Single Label',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16.0),
                              Expanded(
                                child: Container(
                                  height: 56.0,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.purple[400]!, Colors.purple[600]!],
                                    ),
                                    borderRadius: BorderRadius.circular(28.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.purple.withOpacity(0.3),
                                        blurRadius: 8.0,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(28.0),
                                      onTap: _printMultipleLabels,
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.print_disabled,
                                              color: Colors.white,
                                              size: 24.0,
                                            ),
                                            SizedBox(width: 8.0),
                                            Text(
                                              'Multiple Labels',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
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

## 🔧 **Advanced Features**

### **Buffer Management**

The plugin includes advanced buffer clearing strategies to prevent content bleeding:

```dart
// Clear buffer before critical operations
await _plugin.clearBuffer();

// Get printer status
final status = await _plugin.getPrinterStatus();

// Feed paper
await _plugin.feedPaper();
```

### **Custom Label Configuration**

```dart
// Get paper configuration for custom calculations
final config = await _plugin.getLabelPaperConfig(
  width: 75.0,
  height: 50.0,
  unit: 'mm',
  dpi: 203,
);

print('Available width: ${config['availableWidth']} dots');
print('QR size: ${config['qrSize']} dots');
```

### **Device Pairing with PIN**

```dart
// Request device pairing with PIN code
await _plugin.requestDevicePairingWithPin(
  device: device,
  pinCode: '1234',
);

// Get stored PIN code
final pinCode = await _plugin.getStoredPinCode(device);

// Remove stored PIN code
await _plugin.removeStoredPinCode(device);
```

## 📚 **API Reference**

### **Bluetooth Management**

| Method | Description | Returns |
|--------|-------------|---------|
| `isBluetoothAvailable()` | Check if Bluetooth is available | `Future<bool>` |
| `requestBluetoothPermissions()` | Request Bluetooth permissions | `Future<bool>` |
| `startScan()` | Scan for Bluetooth devices | `Future<List<Map<String, dynamic>>>` |
| `connectToDevice(device)` | Connect to selected device | `Future<void>` |
| `disconnect()` | Disconnect from device | `Future<bool>` |
| `getConnectionStatus()` | Get current connection status | `Future<String>` |
| `getDetailedConnectionStatus()` | Get detailed connection info | `Future<Map<String, dynamic>>` |

### **Printing Methods**

| Method | Description | Returns |
|--------|-------------|---------|
| `printSingleLabelWithGapDetection(...)` | Print single label with gap detection | `Future<bool>` |
| `printMultipleLabelsWithGapDetection(...)` | Print multiple labels with gap detection | `Future<bool>` |
| `printProfessionalLabel(...)` | Professional label printing | `Future<bool>` |
| `printLabelSequence(...)` | Sequence label printing | `Future<bool>` |
| `printCustomLabel(...)` | Custom label with specific sizes | `Future<bool>` |
| `printSmartLabel(...)` | Smart label printing | `Future<bool>` |
| `printSmartSequence(...)` | Smart sequence printing | `Future<bool>` |

### **Buffer Management**

| Method | Description | Returns |
|--------|-------------|---------|
| `clearBuffer()` | Clear printer buffer | `Future<bool>` |
| `getPrinterStatus()` | Get printer status | `Future<String>` |
| `feedPaper()` | Feed paper | `Future<bool>` |

### **Device Pairing**

| Method | Description | Returns |
|--------|-------------|---------|
| `requestDevicePairing(device)` | Request device pairing | `Future<bool>` |
| `requestDevicePairingWithPin(device, pinCode)` | Pair with PIN code | `Future<bool>` |
| `getStoredPinCode(device)` | Get stored PIN code | `Future<String?>` |
| `removeStoredPinCode(device)` | Remove stored PIN code | `Future<bool>` |
| `checkDevicePairingStatus(device)` | Check pairing status | `Future<bool>` |

## 🚨 **Troubleshooting**

### **Common Issues & Solutions**

#### **1. Bluetooth Not Available**
```dart
// Check Bluetooth availability
final isAvailable = await _plugin.isBluetoothAvailable();
if (!isAvailable) {
  // Handle Bluetooth not available
  print('Bluetooth is not available on this device');
}
```

#### **2. Permission Denied**
```dart
// Request permissions
final hasPermission = await _plugin.requestBluetoothPermissions();
if (!hasPermission) {
  // Guide user to settings
  print('Please enable Bluetooth permissions in device settings');
}
```

#### **3. No Devices Found**
```dart
// Ensure Bluetooth is on and scan again
try {
  final devices = await _plugin.startScan();
  if (devices.isEmpty) {
    print('No devices found. Ensure printer is powered on and in pairing mode.');
  }
} catch (e) {
  print('Scan failed: $e');
}
```

#### **4. Connection Failed**
```dart
// Check connection status
final status = await _plugin.getConnectionStatus();
if (status != 'CONNECTED') {
  // Try reconnecting
  await _plugin.disconnect();
  await Future.delayed(Duration(seconds: 2));
  await _plugin.connectToDevice(device);
}
```

#### **5. Printing Issues**
```dart
// Clear buffer before printing
await _plugin.clearBuffer();

// Check printer status
final printerStatus = await _plugin.getPrinterStatus();
if (printerStatus != 'READY') {
  print('Printer not ready: $printerStatus');
  return;
}
```

### **Debug Information**

Enable detailed logging for troubleshooting:

```dart
// Check detailed connection status
final details = await _plugin.getDetailedConnectionStatus();
print('Connection details: $details');

// Monitor connection state changes
// The plugin automatically logs all operations
```

## 🛠️ **Development Guide**

### **Building from Source**

```bash
# Clone the repository
git clone https://github.com/yourusername/ntbp_plugin.git
cd ntbp_plugin

# Get dependencies
flutter pub get

# Run tests
flutter test

# Build example app
cd example
flutter build apk --debug
```

### **Project Structure**

```
ntbp_plugin/
├── lib/
│   ├── ntbp_plugin.dart              # Main plugin interface
│   ├── ntbp_plugin_platform_interface.dart  # Abstract interface
│   └── ntbp_plugin_method_channel.dart      # Method channel implementation
├── android/
│   └── src/main/kotlin/
│       └── com/example/ntbp_plugin/
│           └── NtbpPlugin.kt         # Android implementation
├── ios/
│   └── Classes/
│       └── NtbpPlugin.swift          # iOS implementation
├── example/
│   └── lib/
│       └── main.dart                 # Example app
└── test/
    └── ntbp_plugin_test.dart         # Unit tests
```

### **Adding New Features**

1. **Update Platform Interface**: Add abstract methods to `ntbp_plugin_platform_interface.dart`
2. **Implement on Android**: Add Kotlin implementation in `NtbpPlugin.kt`
3. **Implement on iOS**: Add Swift implementation in `NtbpPlugin.swift`
4. **Update Method Channel**: Add method handling in `ntbp_plugin_method_channel.dart`
5. **Add Tests**: Create unit tests for new functionality
6. **Update Documentation**: Document new features and usage

## 🤝 **Contributing**

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### **Development Setup**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

### **Code Style**

- Follow Flutter/Dart conventions
- Use meaningful variable names
- Add comprehensive comments
- Include error handling
- Write unit tests

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- Flutter team for the excellent framework
- TSPL command reference documentation
- Bluetooth development community
- All contributors and testers

## 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/yourusername/ntbp_plugin/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/ntbp_plugin/discussions)
- **Documentation**: [Full Documentation](https://github.com/yourusername/ntbp_plugin/wiki)

---

**Made with ❤️ for the Flutter community**

*This plugin is designed to work seamlessly with any UI implementation - whether you're using Material Design, Cupertino, or custom widgets, the thermal printing functionality remains consistent and reliable.*
