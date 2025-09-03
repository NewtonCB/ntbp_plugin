# NTBP Plugin - Flutter Thermal Bluetooth Label Printer

[![Flutter](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://flutter.dev/docs/development/platform-integration)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.0.0-orange.svg)](https://pub.dev/packages/ntbp_plugin)

A comprehensive, production-ready Flutter plugin for thermal Bluetooth label printing with advanced features including gap detection, precise positioning, and support for multiple label formats. **Works with any UI implementation** - the plugin handles all the complexity behind the scenes.

## 🎯 **Why Choose NTBP Plugin?**

- **🔄 UI-Agnostic**: Works seamlessly with any Flutter UI framework (Material, Cupertino, custom)
- **🚀 Production Ready**: Tested extensively with real thermal printers
- **📱 Cross-Platform**: Full Android and iOS support
- **🛡️ Robust**: Advanced error handling and buffer management
- **📚 Well-Documented**: Comprehensive guides and examples
- **🔧 Maintainable**: Clean architecture and extensible design
- **🎨 Perfect Positioning**: Professional-quality label layout with precise text alignment

## 🚀 **Core Features**

### **Label Printing**
- **Three-Line Text Support**: Customer name, position, and additional info with perfect alignment
- **QR Code Integration**: High-quality QR codes with optimal sizing and positioning
- **Smart Positioning**: Automatic content centering and perfect text alignment
- **Gap Detection**: Intelligent label boundary detection and frame management
- **Multiple Formats**: QR codes, barcodes, text, and combined content printing
- **Batch Processing**: Sequence printing with proper label separation

### **Bluetooth Connectivity**
- **Device Discovery**: Automatic Bluetooth device scanning and pairing
- **Connection Management**: Robust connection handling with retry logic
- **Protocol Support**: TSPL and ESC/POS compatibility
- **Cross-Platform**: Android and iOS support with identical APIs

### **Advanced Features**
- **Buffer Management**: Advanced buffer clearing strategies for reliable printing
- **Error Handling**: Comprehensive error handling and recovery
- **Scalable Architecture**: Easy to extend for new printer types
- **Performance Optimized**: Efficient printing with minimal resource usage

## 📱 **Supported Printers**

- **TSPL-Compatible Printers**: N41, N42, and similar thermal label printers
- **ESC/POS Printers**: Romeson KT58L and similar models (with TSPL forced)
- **Resolution**: 203 DPI (8 dots/mm) and higher
- **Label Sizes**: 2" (50mm) to 4.65" (118mm) width
- **Media Types**: Die-cut labels, continuous paper, black mark paper

## 📦 **Installation**

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ntbp_plugin: ^2.0.0
```

Then run:

```bash
flutter pub get
```

## 🚀 **Quick Start**

### **1. Basic Setup**

```dart
import 'package:ntbp_plugin/ntbp_plugin.dart';

// Initialize the plugin
await NtbpPlugin.initialize();
```

### **2. Discover and Connect to Printer**

```dart
// Start Bluetooth discovery
await NtbpPlugin.startScan();

// Get discovered devices
List<BluetoothDevice> devices = await NtbpPlugin.getDiscoveredDevices();

// Connect to a device
bool connected = await NtbpPlugin.connectToDevice(devices.first);
```

### **3. Print Single Label with Three Lines**

```dart
bool success = await NtbpPlugin.printSingleLabelWithGapDetection(
  qrData: "XYZ185EVT",
  textData1: "Cust: Nashon Israel",      // Customer name
  textData2: "Drp: Mwanza",             // Drop point
  textData3: "Ref: 12345",              // Additional info
  width: 75.0,
  height: 60.0,
  unit: 'mm',
  dpi: 203,
  copies: 1,
  textSize: 9,
);
```

### **4. Print Multiple Labels**

```dart
List<Map<String, dynamic>> labelData = [
  {
    'qrData': 'XYZ185EVT',
    'textData1': 'Cust: Nashon Israel',
    'textData2': 'Drp: Mwanza',
    'textData3': 'Ref: 12345',
  },
  {
    'qrData': 'XYZ186HYW',
    'textData1': 'Cust: Emanuel Tarimo',
    'textData2': 'Drp: Mbeya',
    'textData3': 'Ref: 67890',
  },
];

bool success = await NtbpPlugin.printMultipleLabelsWithGapDetection(
  labelDataList: labelData,
  width: 75.0,
  height: 60.0,
  unit: 'mm',
  dpi: 203,
  copiesPerLabel: 1,
  textSize: 9,
);
```

## 📋 **API Reference**

### **Core Methods**

#### **Initialization**
```dart
static Future<void> initialize()
```
Initialize the plugin and prepare for Bluetooth operations.

#### **Bluetooth Management**
```dart
static Future<bool> isBluetoothAvailable()
static Future<bool> requestBluetoothPermissions()
static Future<void> startScan()
static Future<void> stopScan()
static Future<List<BluetoothDevice>> getDiscoveredDevices()
static Future<bool> connectToDevice(BluetoothDevice device)
static Future<bool> disconnect()
static Future<bool> isConnected()
```

#### **Label Printing**
```dart
static Future<bool> printSingleLabelWithGapDetection({
  required String qrData,
  required String textData1,    // Customer name
  required String textData2,    // Drop point
  required String textData3,    // Additional info
  required double width,
  required double height,
  String? unit,
  int? dpi,
  int? copies,
  int? textSize,
})

static Future<bool> printMultipleLabelsWithGapDetection({
  required List<Map<String, dynamic>> labelDataList,
  required double width,
  required double height,
  String? unit,
  int? dpi,
  int? copiesPerLabel,
  int? textSize,
})
```

### **Data Models**

#### **BluetoothDevice**
```dart
class BluetoothDevice {
  final String name;
  final String address;
  final bool isPaired;
  final int rssi;
}
```

#### **PrintCommand**
```dart
class PrintCommand {
  final String command;
  final Map<String, dynamic> parameters;
}
```

## 🎨 **Label Layout Features**

### **Perfect Positioning**
- **QR Code**: Automatically centered with optimal sizing
- **Text Alignment**: All three text lines start at the same left position as QR code
- **Vertical Spacing**: 8mm gap after QR code, 4mm between text lines
- **Responsive Design**: Adapts to different label sizes automatically

### **Supported Label Sizes**
- **Small**: 50x30mm - Compact labels for basic info
- **Medium**: 75x60mm - Standard labels with three text lines
- **Large**: 100x80mm - Extended labels for detailed information

### **Text Configuration**
- **Line 1**: Customer name (e.g., "Cust: Nashon Israel")
- **Line 2**: Drop point (e.g., "Drp: Mwanza")
- **Line 3**: Additional info (e.g., "Ref: 12345")

## 🔧 **Advanced Configuration**

### **DPI Settings**
```dart
// Standard 203 DPI (recommended)
dpi: 203

// High resolution 300 DPI
dpi: 300
```

### **Text Size Options**
```dart
// Small text (7-8)
textSize: 7

// Standard text (9-10)
textSize: 9

// Large text (11-12)
textSize: 11
```

### **Unit Options**
```dart
// Millimeters (recommended)
unit: 'mm'

// Inches
unit: 'in'

// Dots
unit: 'dots'
```

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **Connection Problems**
```dart
// Check Bluetooth availability
bool available = await NtbpPlugin.isBluetoothAvailable();

// Request permissions
bool granted = await NtbpPlugin.requestBluetoothPermissions();

// Check connection status
bool connected = await NtbpPlugin.isConnected();
```

#### **Printing Issues**
- Ensure printer is properly connected
- Check label dimensions match your physical labels
- Verify DPI settings match your printer
- Try reducing text size if content is cut off

#### **Text Positioning**
- The plugin automatically handles perfect alignment
- Text lines start at the same left position as QR code
- Vertical spacing is optimized for readability

### **Debug Information**
```dart
// Get detailed connection status
Map<String, dynamic> status = await NtbpPlugin.getDetailedConnectionStatus();

// Get printer status
Map<String, dynamic> printerStatus = await NtbpPlugin.getPrinterStatus();
```

## 📱 **Platform-Specific Notes**

### **Android**
- Requires `BLUETOOTH` and `BLUETOOTH_ADMIN` permissions
- Supports both Classic Bluetooth and BLE
- Automatic permission handling

### **iOS**
- Requires `NSBluetoothAlwaysUsageDescription` in Info.plist
- Supports Classic Bluetooth (SPP) connections
- Automatic permission prompts

## 🧪 **Testing**

The plugin includes comprehensive test coverage:

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📄 **Example App**

Check out the complete example app in the `example/` directory:

- **Bluetooth Discovery**: Automatic device scanning
- **Connection Management**: Robust connection handling
- **Label Printing**: Single and multiple label examples
- **UI Implementation**: Responsive design for different screen sizes

## 🤝 **Contributing**

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### **Development Setup**
```bash
# Clone the repository
git clone https://github.com/your-username/ntbp_plugin.git

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run example app
cd example && flutter run
```

## 📝 **Changelog**

### **Version 2.0.0**
- ✨ **NEW**: Three-line text support with perfect alignment
- ✨ **NEW**: Enhanced positioning system for professional labels
- ✨ **NEW**: Improved gap detection and buffer management
- ✨ **NEW**: ESC/POS printer support with TSPL forced
- 🔧 **IMPROVED**: Better error handling and connection management
- 🔧 **IMPROVED**: Optimized text spacing and positioning
- 🐛 **FIXED**: Multiple label printing issues
- 🐛 **FIXED**: Text overlap and positioning problems

### **Version 1.0.0**
- 🎉 **INITIAL**: First stable release
- ✨ **FEATURES**: Basic Bluetooth connectivity and label printing
- ✨ **FEATURES**: QR code and text printing support
- ✨ **FEATURES**: Gap detection and buffer management

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- Flutter team for the excellent platform
- Thermal printer manufacturers for their documentation
- Community contributors and testers

## 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/your-username/ntbp_plugin/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/ntbp_plugin/discussions)
- **Email**: support@your-domain.com

---

**Made with ❤️ for the Flutter community**