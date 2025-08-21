# NTBP Plugin - UI Implementation Guide

## 🎯 **Overview**

This guide provides practical examples of implementing the NTBP Plugin with different UI frameworks and design systems. The plugin is **UI-agnostic** - it works seamlessly with any Flutter UI implementation.

## 📋 **Quick Start Pattern**

### **1. Service Layer (UI-Independent)**

```dart
import 'package:ntbp_plugin/ntbp_plugin.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final NtbpPlugin _plugin = NtbpPlugin();
  
  bool _isConnected = false;
  Map<String, dynamic>? _connectedDevice;
  
  bool get isConnected => _isConnected;
  Map<String, dynamic>? get connectedDevice => _connectedDevice;

  // Initialize plugin
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
}
```

### **2. UI Implementation (Any Framework)**

```dart
class MyPrinterScreen extends StatefulWidget {
  @override
  _MyPrinterScreenState createState() => _MyPrinterScreenState();
}

class _MyPrinterScreenState extends State<MyPrinterScreen> {
  final PrinterService _printerService = PrinterService();
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
    // Your custom UI implementation here
    return Scaffold(
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

### **Material Design 3**

```dart
class Material3PrinterScreen extends StatefulWidget {
  @override
  _Material3PrinterScreenState createState() => _Material3PrinterScreenState();
}

class _Material3PrinterScreenState extends State<Material3PrinterScreen> {
  final PrinterService _printerService = PrinterService();
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
  final PrinterService _printerService = PrinterService();
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

### **Custom UI (No Framework Dependencies)**

```dart
class CustomPrinterScreen extends StatefulWidget {
  @override
  _CustomPrinterScreenState createState() => _CustomPrinterScreenState();
}

class _CustomPrinterScreenState extends State<CustomPrinterScreen> {
  final PrinterService _printerService = PrinterService();
  List<Map<String, dynamic>> _devices = [];
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
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.print,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thermal Printer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _printerService.isConnected 
                                ? 'Connected to ${_printerService.connectedDevice?['name']}'
                                : 'Not Connected',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
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
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Scan Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange[400]!, Colors.orange[600]!],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: _isScanning ? null : _startScan,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isScanning ? Icons.stop : Icons.search,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      _isScanning ? 'Scanning...' : 'Scan for Devices',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
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
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Press scan to discover devices',
                                        style: TextStyle(
                                          fontSize: 14,
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
                                      margin: EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                        leading: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.bluetooth,
                                            color: Colors.blue[600],
                                            size: 20,
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
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        trailing: Container(
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: () => _connectToDevice(device),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue[600],
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
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
                        if (_printerService.isConnected) ...[
                          SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green[400]!, Colors.green[600]!],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(28),
                                      onTap: _printSingleLabel,
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.print,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Single Label',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
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
                              SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.purple[400]!, Colors.purple[600]!],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.purple.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(28),
                                      onTap: _printMultipleLabels,
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.print_disabled,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Multiple Labels',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
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

## 🔧 **State Management Integration**

### **Provider Pattern**

```dart
import 'package:flutter/foundation.dart';

class PrinterProvider extends ChangeNotifier {
  final PrinterService _printerService = PrinterService();
  
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
      final success = await _printerService.initialize();
      if (success) {
        _updateStatus('Ready to scan');
      } else {
        _updateStatus('Initialization failed');
      }
    } catch (e) {
      _updateStatus('Error: $e');
    }
  }
  
  // Scan for devices
  Future<void> scanForDevices() async {
    if (_isScanning) return;
    
    _setScanning(true);
    _updateStatus('Scanning...');
    
    try {
      final devices = await _printerService.scanForDevices();
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
    _updateStatus('Connecting...');
    
    try {
      final success = await _printerService.connectToDevice(device);
      if (success) {
        _connectedDevice = device;
        _isConnected = true;
        _updateStatus('Connected to ${device['name']}');
      } else {
        _updateStatus('Connection failed');
      }
    } catch (e) {
      _updateStatus('Error: $e');
    }
  }
  
  // Disconnect
  Future<void> disconnect() async {
    if (!_isConnected) return;
    
    _updateStatus('Disconnecting...');
    
    try {
      final success = await _printerService.disconnect();
      if (success) {
        _connectedDevice = null;
        _isConnected = false;
        _updateStatus('Disconnected');
      }
    } catch (e) {
      _updateStatus('Error: $e');
    }
  }
  
  // Print methods
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
      _updateStatus('Not connected');
      return;
    }
    
    _updateStatus('Printing...');
    
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
        _updateStatus('Print successful!');
      } else {
        _updateStatus('Print failed');
      }
    } catch (e) {
      _updateStatus('Error: $e');
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

## 🎯 **Key Principles**

1. **Separation of Concerns**: Keep printer logic in service layer, separate from UI
2. **UI Independence**: The plugin works with any UI framework or custom design
3. **Error Handling**: Always handle errors gracefully and provide user feedback
4. **State Management**: Use your preferred state management solution
5. **Loading States**: Show progress indicators for better user experience
6. **Responsive Design**: Ensure UI works on different screen sizes

## 🚀 **Next Steps**

1. **Choose your UI framework** (Material, Cupertino, or custom)
2. **Implement the service layer** using the provided `PrinterService` class
3. **Create your UI components** using the examples as reference
4. **Add error handling** and loading states
5. **Test thoroughly** with real devices
6. **Customize the design** to match your app's theme

The NTBP Plugin is designed to be completely UI-agnostic, so you can focus on creating beautiful, intuitive interfaces while the plugin handles all the complex thermal printing logic behind the scenes. 