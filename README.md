# NTBP Plugin - Flutter Thermal Bluetooth Label Printer

[![Flutter](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://flutter.dev/docs/development/platform-integration)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-3.0.0-orange.svg)](https://pub.dev/packages/ntbp_plugin)

Flutter plugin for thermal Bluetooth label printing on TSPL printers such as the **Xprinter XP-420B** and the N41. Label layouts are rendered to TSPL in Dart so Android and iOS print identical output; the native side uses the Xprinter vendor SDKs for transport and printer status. **Works with any UI implementation.**

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

- **Xprinter XP-420B** (4-inch desktop label printer, 203 dpi, TSPL) - primary target since 3.0.0
- **TSPL-Compatible Printers**: N41, N42, and similar thermal label printers
- **ESC/POS Printers**: Romeson KT58L and similar models (with TSPL forced)
- **Resolution**: 203 DPI (8 dots/mm) and higher
- **Label Sizes**: 2" (50mm) to 4.65" (118mm) width
- **Media Types**: Die-cut labels (gap), black mark paper, continuous paper
- **Transport**: Android classic Bluetooth (SPP) via Xprinter `printer-lib`; iOS BLE via Xprinter `PrinterSDK`

## 📦 **Installation**

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ntbp_plugin: ^3.0.0
```

Android needs `minSdkVersion 21` or higher. On Android 12+ request `BLUETOOTH_SCAN` and
`BLUETOOTH_CONNECT` at runtime (for example with `permission_handler`) before scanning.
iOS needs `NSBluetoothAlwaysUsageDescription` in `Info.plist`. If you request the
permission with `permission_handler`, also add `PERMISSION_BLUETOOTH=1` to
`GCC_PREPROCESSOR_DEFINITIONS` in your Podfile's `post_install` block, otherwise the
Bluetooth permission is compiled out and always reports "denied". The bundled iOS library
has no Apple-silicon simulator slice, so use a real device or a Rosetta simulator.

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

### **3. Print a Cargo Shipment Label (XP-420B)**

The layout fits a 100 x 150 mm (4" x 6") label: brand name top left and logo top right, booking
reference and item reference with a QR code, sender and receiver (name and phone),
destination / weight / package, source / date, and the cargo name in a box at the
bottom.

```dart
// Decode the logo once and reuse it for every label.
final bytes = await rootBundle.load('assets/logo.png');
final logo = CargoLogo.fromBytes(bytes.buffer.asUint8List());

final label = CargoLabel(
  brandName: 'BM Coach',
  bookingReference: 'BK-1025',
  item: CargoLabel.generateReference('BK-1025', 1), // BK1025-001
  cargoName: 'Spare parts (engine)',
  sender: ['Otapp Agency Limited', 'Tel: +255 712 345 678'],
  receiver: ['John Mwakyusa', 'Tel: +255 765 432 109'],
  source: 'MWANZA',
  destination: 'DAR ES SALAAM',
  weight: '5.0 KG',
  package: '1 / 5',
  date: '2025-10-19',
  // qrContent: CargoQrContent.summary (default) encodes a readable shipment
  // summary, so scanning the QR with any phone shows all the details.
);

// Media settings. Defaults are 100 x 150 mm, 203 dpi, 3 mm gap, 1 copy.
const config = LabelPrintConfig(gapMm: 3, density: 10);

bool ok = await NtbpPlugin.printCargoLabel(label, config: config, logo: logo);
```

Print a series. The plugin polls the printer between labels and stops at the first
error (out of paper, head open, jam) so nothing is lost in the buffer:

```dart
final result = await NtbpPlugin.printCargoLabels(labels, config: config, logo: logo);
print('${result.printed}/${result.total} printed, failed: ${result.failedIndexes}');
if (result.stoppedBy != null) print(result.stoppedBy!.description);
```

`CargoLogo` accepts PNG, JPEG, GIF, BMP and WebP. Colour artwork is reduced to black
with a luminance threshold (`threshold`, default 170); use `dither: true` for photos.
The logo is scaled to fit a 45 x 14 mm box at the top right of the label; `brandName` is
printed at the top left in the largest font that fits beside it.

### **4. Calibrate the Gap Sensor (once per roll)**

```dart
await NtbpPlugin.calibrateGap();   // or autoCalibrate() / calibrateBlackMark()
```

Calibration feeds two or three labels. Do it after loading a new roll, not before every print.

### **5. Printer Status**

```dart
final status = await NtbpPlugin.queryPrinterStatus();
if (!status.isReady) print(status.description); // "Out of paper", "Head opened", ...
```

### **6. Custom TSPL**

```dart
final job = TsplBuilder()
  ..sizeMm(100, 150)
  ..gapMm(3)
  ..cls()
  ..text(40, 40, TsplFont.f24x32, 'Hello')
  ..print(copies: 2);
await NtbpPlugin.sendTspl(job.build());
```

### **7. Print Single Label with Three Lines (N41 layout)**

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

### **8. Print Multiple Three-Line Labels**

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
- Uses the Xprinter `printer-lib-3.5.8.aar` bundled with the plugin (classic Bluetooth SPP).
- `minSdkVersion 21`.
- Discovery lists bonded devices plus classic devices found in a 12 second scan.
- Requires `BLUETOOTH` and `BLUETOOTH_ADMIN` permissions
- Supports both Classic Bluetooth and BLE
- Automatic permission handling

### **iOS**
- Uses the Xprinter `PrinterSDK` static library bundled with the plugin (BLE).
- Device address is the CoreBluetooth peripheral identifier; it is stable per phone.
- The library has device (arm64) and x86_64 simulator slices only.
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

### **Version 3.0.0**
- Xprinter XP-420B support with the cargo shipment label layout
- Logo at the top of the label (`CargoLogo`), source field, cargo name box
- QR code encodes a readable shipment summary (configurable)
- Example app: label form, editable series, smooth_sheets printer picker
- Vendor SDK transports on Android (SPP) and iOS (BLE)
- Printer status query, one-time gap calibration, series printing with error stop
- Layouts rendered in Dart; identical output on both platforms
- Fixed invalid TSPL (`CLEAR`, `GAPDETECT ON`), blank labels from `HOME`/`FORMFEED`, quote escaping

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