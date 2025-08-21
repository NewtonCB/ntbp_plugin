# NTBP Plugin - API Reference

## 📚 Complete API Documentation

This document provides a comprehensive reference for all methods, parameters, and return values available in the NTBP Plugin.

## 🏗️ Core Architecture

### Class Hierarchy
```
NtbpPlugin (Public API)
    ↓
NtbpPluginPlatform (Abstract Interface)
    ↓
NtbpPluginMethodChannel (Flutter Implementation)
    ↓
Native Implementation (Android/iOS)
```

### Import Statement
```dart
import 'package:ntbp_plugin/ntbp_plugin.dart';
```

## 🔌 Bluetooth Management

### 1. Bluetooth Availability

#### `isBluetoothAvailable()`
Check if Bluetooth is available and enabled on the device.

**Returns:** `Future<bool>`
- `true`: Bluetooth is available and enabled
- `false`: Bluetooth is not available or disabled

**Usage:**
```dart
final isAvailable = await _plugin.isBluetoothAvailable();
if (isAvailable) {
  print('✅ Bluetooth is available');
} else {
  print('❌ Bluetooth is not available');
}
```

### 2. Permission Management

#### `requestBluetoothPermissions()`
Request all necessary Bluetooth permissions from the user.

**Returns:** `Future<bool>`
- `true`: All permissions granted
- `false`: Some permissions denied

**Required Permissions:**
- `BLUETOOTH`
- `BLUETOOTH_ADMIN`
- `BLUETOOTH_CONNECT`
- `BLUETOOTH_SCAN`
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`

**Usage:**
```dart
final hasPermissions = await _plugin.requestBluetoothPermissions();
if (hasPermissions) {
  print('✅ All permissions granted');
} else {
  print('❌ Some permissions denied');
}
```

### 3. Device Discovery

#### `startScan()`
Start scanning for nearby Bluetooth devices.

**Returns:** `Future<List<BluetoothDevice>>`
- List of discovered Bluetooth devices

**Scan Duration:** Approximately 10-15 seconds

**Usage:**
```dart
try {
  final devices = await _plugin.startScan();
  print('🔍 Found ${devices.length} devices');
  
  for (final device in devices) {
    print('📱 ${device.name} (${device.address})');
  }
} catch (e) {
  print('❌ Scan failed: $e');
}
```

**BluetoothDevice Properties:**
```dart
class BluetoothDevice {
  final String name;        // Device display name
  final String address;     // MAC address
  final int bondState;      // Pairing status
  final List<int> uuids;    // Supported services
}
```

### 4. Connection Management

#### `connectToDevice(BluetoothDevice device)`
Connect to a specific Bluetooth device.

**Parameters:**
- `device`: `BluetoothDevice` - The device to connect to

**Returns:** `Future<void>`

**Connection Process:**
1. Establishes Bluetooth socket connection
2. Initializes input/output streams
3. Attempts multiple connection strategies
4. Updates connection state

**Usage:**
```dart
try {
  await _plugin.connectToDevice(selectedDevice);
  print('✅ Connected to ${selectedDevice.name}');
} catch (e) {
  print('❌ Connection failed: $e');
}
```

#### `disconnect()`
Disconnect from the currently connected device.

**Returns:** `Future<bool>`
- `true`: Successfully disconnected
- `false`: Disconnection failed

**Usage:**
```dart
final success = await _plugin.disconnect();
if (success) {
  print('✅ Disconnected successfully');
} else {
  print('❌ Disconnection failed');
}
```

### 5. Connection Status

#### `getConnectionStatus()`
Get the current connection status.

**Returns:** `Future<String>`
- `"CONNECTED"`: Device is connected
- `"DISCONNECTED"`: Device is disconnected
- `"CONNECTING"`: Connection in progress
- `"ERROR"`: Connection error occurred

**Usage:**
```dart
final status = await _plugin.getConnectionStatus();
switch (status) {
  case "CONNECTED":
    print('✅ Device is connected');
    break;
  case "DISCONNECTED":
    print('❌ Device is disconnected');
    break;
  case "CONNECTING":
    print('🔄 Connecting...');
    break;
  case "ERROR":
    print('❌ Connection error');
    break;
}
```

#### `getDetailedConnectionStatus()`
Get detailed connection information.

**Returns:** `Future<Map<String, dynamic>>`
```dart
{
  "status": "CONNECTED",
  "deviceName": "N41 Printer",
  "deviceAddress": "XX:XX:XX:XX:EF:F8",
  "socketConnected": true,
  "outputStreamAvailable": true,
  "lastError": null
}
```

**Usage:**
```dart
final details = await _plugin.getDetailedConnectionStatus();
print('Device: ${details["deviceName"]}');
print('Socket: ${details["socketConnected"]}');
print('Stream: ${details["outputStreamAvailable"]}');
```

## 🖨️ Printing Methods

### 1. Single Label Printing

#### `printSingleLabelWithGapDetection()`
Print a single label with gap detection and precise positioning.

**Parameters:**
- `qrData`: `String` - QR code content
- `textData`: `String` - Text to print below QR code
- `width`: `double` - Label width in specified unit
- `height`: `double` - Label height in specified unit
- `unit`: `String?` - Unit of measurement (default: "mm")
- `dpi`: `int?` - Printer resolution (default: 203)
- `copies`: `int?` - Number of copies (default: 1)
- `textSize`: `int?` - Text font size (default: 9)

**Returns:** `Future<bool>`
- `true`: Label printed successfully
- `false`: Printing failed

**Features:**
- Automatic gap detection
- Content centering
- Dynamic positioning based on label size
- Buffer clearing before printing

**Usage:**
```dart
final success = await _plugin.printSingleLabelWithGapDetection(
  qrData: "PROD001",
  textData: "Sample Product",
  width: 75.0,
  height: 50.0,
  unit: "mm",
  dpi: 203,
  copies: 2,
  textSize: 12,
);

if (success) {
  print('✅ Single label printed successfully');
} else {
  print('❌ Single label printing failed');
}
```

### 2. Multiple Labels Printing

#### `printMultipleLabelsWithGapDetection()`
Print multiple labels with different content and proper gap detection.

**Parameters:**
- `labelDataList`: `List<Map<String, dynamic>>` - List of label data
- `width`: `double` - Label width in specified unit
- `height`: `double` - Label height in specified unit
- `unit`: `String?` - Unit of measurement (default: "mm")
- `dpi`: `int?` - Printer resolution (default: 203)
- `copiesPerLabel`: `int?` - Copies per label (default: 1)
- `textSize`: `int?` - Text font size (default: 9)

**Returns:** `Future<bool>`
- `true`: All labels printed successfully
- `false`: Some labels failed to print

**Label Data Format:**
```dart
List<Map<String, dynamic>> labels = [
  {
    "qrData": "QR001",
    "textData": "Product A"
  },
  {
    "qrData": "QR002", 
    "textData": "Product B"
  },
  {
    "qrData": "QR003",
    "textData": "Product C"
  }
];
```

**Features:**
- Sequential printing with gap detection
- Individual buffer clearing for each label
- Proper label separation
- Error handling per label

**Usage:**
```dart
final success = await _plugin.printMultipleLabelsWithGapDetection(
  labelDataList: labels,
  width: 75.0,
  height: 50.0,
  unit: "mm",
  dpi: 203,
  copiesPerLabel: 1,
  textSize: 9,
);

if (success) {
  print('✅ Multiple labels printed successfully');
} else {
  print('❌ Multiple labels printing failed');
}
```

### 3. Professional Label Printing

#### `printProfessionalLabel()`
Print a professional label with optimized TSPL commands.

**Parameters:**
- `qrData`: `String` - QR code content
- `textData`: `String` - Text to print below QR code
- `width`: `double` - Label width in specified unit
- `height`: `double` - Label height in specified unit
- `unit`: `String?` - Unit of measurement (default: "mm")
- `dpi`: `int?` - Printer resolution (default: 203)

**Returns:** `Future<bool>`
- `true`: Label printed successfully
- `false`: Printing failed

**Features:**
- Professional TSPL command sequence
- Optimized positioning algorithms
- Automatic margin calculation
- High-quality output

**Usage:**
```dart
final success = await _plugin.printProfessionalLabel(
  qrData: "PROF001",
  textData: "Professional Label",
  width: 100.0,
  height: 60.0,
  unit: "mm",
  dpi: 203,
);

if (success) {
  print('✅ Professional label printed successfully');
} else {
  print('❌ Professional label printing failed');
}
```

### 4. Custom Label Printing

#### `printCustomLabel()`
Print a label with custom QR and text sizes.

**Parameters:**
- `qrData`: `String` - QR code content
- `textData`: `String` - Text to print below QR code
- `width`: `double` - Label width in specified unit
- `height`: `double` - Label height in specified unit
- `unit`: `String?` - Unit of measurement (default: "mm")
- `dpi`: `int?` - Printer resolution (default: 203)
- `qrSize`: `int?` - Custom QR code size in dots
- `textSize`: `int?` - Custom text size

**Returns:** `Future<bool>`
- `true`: Label printed successfully
- `false`: Printing failed

**Usage:**
```dart
final success = await _plugin.printCustomLabel(
  qrData: "CUSTOM001",
  textData: "Custom Size Label",
  width: 80.0,
  height: 45.0,
  unit: "mm",
  dpi: 203,
  qrSize: 200,
  textSize: 15,
);

if (success) {
  print('✅ Custom label printed successfully');
} else {
  print('❌ Custom label printing failed');
}
```

### 5. Smart Label Printing

#### `printSmartLabel()`
Print a label using smart positioning algorithms.

**Parameters:**
- `qrData`: `String` - QR code content
- `textData`: `String` - Text to print below QR code
- `labelWidth`: `double` - Label width in specified unit
- `labelHeight`: `double` - Label height in specified unit
- `unit`: `String?` - Unit of measurement (default: "mm")
- `dpi`: `int?` - Printer resolution (default: 203)

**Returns:** `Future<bool>`
- `true`: Label printed successfully
- `false`: Printing failed

**Features:**
- Intelligent content positioning
- Dynamic margin calculation
- Optimal QR code sizing
- Smart text placement

**Usage:**
```dart
final success = await _plugin.printSmartLabel(
  qrData: "SMART001",
  textData: "Smart Label",
  labelWidth: 75.0,
  labelHeight: 50.0,
  unit: "mm",
  dpi: 203,
);

if (success) {
  print('✅ Smart label printed successfully');
} else {
  print('❌ Smart label printing failed');
}
```

### 6. Smart Sequence Printing

#### `printSmartSequence()`
Print multiple labels using smart algorithms.

**Parameters:**
- `labelDataList`: `List<Map<String, dynamic>>` - List of label data
- `labelWidth`: `double` - Label width in specified unit
- `labelHeight`: `double` - Label height in specified unit
- `unit`: `String?` - Unit of measurement (default: "mm")
- `dpi`: `int?` - Printer resolution (default: 203)

**Returns:** `Future<bool>`
- `true`: All labels printed successfully
- `false`: Some labels failed to print

**Usage:**
```dart
final success = await _plugin.printSmartSequence(
  labelDataList: labels,
  labelWidth: 75.0,
  labelHeight: 50.0,
  unit: "mm",
  dpi: 203,
);

if (success) {
  print('✅ Smart sequence printed successfully');
} else {
  print('❌ Smart sequence printing failed');
}
```

## 🧹 Buffer Management

### 1. Clear Buffer

#### `clearBuffer()`
Clear the printer's print buffer.

**Returns:** `Future<bool>`
- `true`: Buffer cleared successfully
- `false`: Buffer clearing failed

**TSPL Commands Used:**
- `CLEAR` - Clear buffer
- `CLS` - Clear screen

**Usage:**
```dart
final success = await _plugin.clearBuffer();
if (success) {
  print('✅ Buffer cleared successfully');
} else {
  print('❌ Buffer clearing failed');
}
```

### 2. Get Printer Status

#### `getPrinterStatus()`
Get the current status of the printer.

**Returns:** `Future<String>`
- Printer status information

**Usage:**
```dart
final status = await _plugin.getPrinterStatus();
print('📊 Printer status: $status');
```

### 3. Feed Paper

#### `feedPaper()`
Feed paper to the next position.

**Returns:** `Future<bool>`
- `true`: Paper fed successfully
- `false`: Paper feeding failed

**Usage:**
```dart
final success = await _plugin.feedPaper();
if (success) {
  print('✅ Paper fed successfully');
} else {
  print('❌ Paper feeding failed');
}
```

## 🔐 Device Pairing

### 1. Request Device Pairing

#### `requestDevicePairing(BluetoothDevice device)`
Request pairing with a Bluetooth device.

**Parameters:**
- `device`: `BluetoothDevice` - The device to pair with

**Returns:** `Future<bool>`
- `true`: Pairing request sent successfully
- `false`: Pairing request failed

**Usage:**
```dart
final success = await _plugin.requestDevicePairing(device);
if (success) {
  print('✅ Pairing request sent');
} else {
  print('❌ Pairing request failed');
}
```

### 2. Request Device Pairing with PIN

#### `requestDevicePairingWithPin(BluetoothDevice device, String pinCode)`
Request pairing with a PIN code.

**Parameters:**
- `device`: `BluetoothDevice` - The device to pair with
- `pinCode`: `String` - PIN code for pairing

**Returns:** `Future<bool>`
- `true`: Pairing with PIN successful
- `false`: Pairing with PIN failed

**Usage:**
```dart
final success = await _plugin.requestDevicePairingWithPin(device, "1234");
if (success) {
  print('✅ Device paired with PIN');
} else {
  print('❌ PIN pairing failed');
}
```

### 3. Get Stored PIN Code

#### `getStoredPinCode(BluetoothDevice device)`
Get the stored PIN code for a device.

**Parameters:**
- `device`: `BluetoothDevice` - The device to get PIN for

**Returns:** `Future<String?>`
- PIN code if stored, `null` if not found

**Usage:**
```dart
final pinCode = await _plugin.getStoredPinCode(device);
if (pinCode != null) {
  print('🔑 Stored PIN: $pinCode');
} else {
  print('❌ No PIN stored for this device');
}
```

### 4. Remove Stored PIN Code

#### `removeStoredPinCode(BluetoothDevice device)`
Remove the stored PIN code for a device.

**Parameters:**
- `device`: `BluetoothDevice` - The device to remove PIN for

**Returns:** `Future<bool>`
- `true`: PIN code removed successfully
- `false`: PIN code removal failed

**Usage:**
```dart
final success = await _plugin.removeStoredPinCode(device);
if (success) {
  print('✅ PIN code removed');
} else {
  print('❌ PIN code removal failed');
}
```

## 📊 Label Configuration

### 1. Get Label Paper Configuration

#### `getLabelPaperConfig(double width, double height, String unit, int dpi)`
Get optimized paper configuration for label dimensions.

**Parameters:**
- `width`: `double` - Label width
- `height`: `double` - Label height
- `unit`: `String` - Unit of measurement
- `dpi`: `int` - Printer resolution

**Returns:** `Future<Map<String, dynamic>>`
```dart
{
  "widthInDots": 1488,
  "heightInDots": 992,
  "gapSize": 40,
  "marginInDots": 60,
  "availableWidth": 1368,
  "availableHeight": 872,
  "qrSize": 820,
  "textSize": 9
}
```

**Usage:**
```dart
final config = await _plugin.getLabelPaperConfig(75.0, 50.0, "mm", 203);
print('Width in dots: ${config["widthInDots"]}');
print('QR size: ${config["qrSize"]}');
```

## 🔧 Utility Methods

### 1. Check Device Pairing Status

#### `checkDevicePairingStatus(BluetoothDevice device)`
Check if a device is paired.

**Parameters:**
- `device`: `BluetoothDevice` - The device to check

**Returns:** `Future<bool>`
- `true`: Device is paired
- `false`: Device is not paired

**Usage:**
```dart
final isPaired = await _plugin.checkDevicePairingStatus(device);
if (isPaired) {
  print('✅ Device is paired');
} else {
  print('❌ Device is not paired');
}
```

## 📱 Error Handling

### Common Error Types

| Error Code | Description | Solution |
|------------|-------------|----------|
| `BLUETOOTH_NOT_AVAILABLE` | Bluetooth not available | Enable Bluetooth |
| `PERMISSION_DENIED` | Permissions not granted | Grant required permissions |
| `DEVICE_NOT_FOUND` | Device not found | Check device visibility |
| `CONNECTION_FAILED` | Connection failed | Retry connection |
| `NOT_CONNECTED` | Not connected to printer | Connect to device first |
| `PRINTING_FAILED` | Printing operation failed | Check printer status |
| `BUFFER_ERROR` | Buffer operation failed | Clear buffer and retry |

### Error Handling Example

```dart
try {
  final success = await _plugin.printSingleLabelWithGapDetection(
    qrData: "TEST",
    textData: "Test Label",
    width: 75.0,
    height: 50.0,
  );
  
  if (success) {
    print('✅ Printing successful');
  } else {
    print('❌ Printing failed');
  }
} catch (e) {
  if (e is PlatformException) {
    switch (e.code) {
      case 'NOT_CONNECTED':
        print('❌ Please connect to a printer first');
        break;
      case 'PRINTING_FAILED':
        print('❌ Printing operation failed');
        break;
      default:
        print('❌ Error: ${e.message}');
    }
  } else {
    print('❌ Unexpected error: $e');
  }
}
```

## 🎯 Best Practices

### 1. Connection Management
- Always check connection status before printing
- Implement reconnection logic for dropped connections
- Handle connection timeouts gracefully

### 2. Error Handling
- Wrap all plugin calls in try-catch blocks
- Check return values for success/failure
- Provide user-friendly error messages

### 3. Performance Optimization
- Reuse plugin instances when possible
- Implement proper delays between operations
- Clear buffer before critical printing operations

### 4. User Experience
- Show loading indicators during operations
- Provide clear feedback for all operations
- Handle edge cases gracefully

## 📝 Complete Example

```dart
import 'package:ntbp_plugin/ntbp_plugin.dart';

class PrinterService {
  final NtbpPlugin _plugin = NtbpPlugin();
  BluetoothDevice? _connectedDevice;
  
  // Initialize the plugin
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
  
  // Scan for devices
  Future<List<BluetoothDevice>> scanForDevices() async {
    try {
      final devices = await _plugin.startScan();
      print('🔍 Found ${devices.length} devices');
      return devices;
    } catch (e) {
      print('❌ Scan failed: $e');
      return [];
    }
  }
  
  // Connect to device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print('🔌 Connecting to ${device.name}...');
      
      await _plugin.connectToDevice(device);
      
      // Check connection status
      final status = await _plugin.getConnectionStatus();
      if (status == 'CONNECTED') {
        _connectedDevice = device;
        print('✅ Connected successfully to ${device.name}');
        return true;
      } else {
        print('❌ Connection failed: $status');
        return false;
      }
    } catch (e) {
      print('❌ Connection error: $e');
      return false;
    }
  }
  
  // Print single label
  Future<bool> printLabel({
    required String qrData,
    required String textData,
    double width = 75.0,
    double height = 50.0,
    int copies = 1,
    int textSize = 9,
  }) async {
    if (_connectedDevice == null) {
      print('❌ No device connected');
      return false;
    }
    
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
      
      if (success) {
        print('✅ Label printed successfully');
        return true;
      } else {
        print('❌ Label printing failed');
        return false;
      }
    } catch (e) {
      print('❌ Printing error: $e');
      return false;
    }
  }
  
  // Print multiple labels
  Future<bool> printMultipleLabels(List<Map<String, String>> labelData) async {
    if (_connectedDevice == null) {
      print('❌ No device connected');
      return false;
    }
    
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
      
      if (success) {
        print('✅ ${labelData.length} labels printed successfully');
        return true;
      } else {
        print('❌ Multiple labels printing failed');
        return false;
      }
    } catch (e) {
      print('❌ Printing error: $e');
      return false;
    }
  }
  
  // Disconnect
  Future<void> disconnect() async {
    try {
      await _plugin.disconnect();
      _connectedDevice = null;
      print('✅ Disconnected successfully');
    } catch (e) {
      print('❌ Disconnection error: $e');
    }
  }
  
  // Get connection status
  Future<String> getConnectionStatus() async {
    try {
      return await _plugin.getConnectionStatus();
    } catch (e) {
      print('❌ Status check error: $e');
      return 'ERROR';
    }
  }
}
```

This comprehensive API reference covers all available methods, parameters, return values, and usage examples for the NTBP Plugin. Use this as your primary reference when implementing the plugin in your Flutter applications. 