# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-12-XX

### Added
- **Three-Line Text Support** - Enhanced label printing with customer name, position, and additional info
- **Perfect Text Alignment** - All text lines start at the same left position as QR code
- **Enhanced Positioning System** - Professional-quality label layout with precise positioning
- **ESC/POS Printer Support** - TSPL forced approach for ESC/POS compatible printers
- **Improved Gap Detection** - Better buffer management and frame handling
- **Optimized Text Spacing** - 8mm gap after QR code, 4mm between text lines

### Changed
- **API Enhancement** - Updated `printSingleLabelWithGapDetection` to support three text parameters
- **Positioning Algorithm** - Improved QR code and text positioning for better visual alignment
- **Buffer Management** - Enhanced clearing strategies for more reliable printing
- **Connection Handling** - Simplified and more robust Bluetooth connection logic

### Fixed
- **Text Overlap Issues** - Resolved text positioning problems that caused overlap with QR codes
- **Multiple Label Printing** - Fixed issues with text not appearing on multiple labels
- **Positioning Accuracy** - Corrected text alignment to start exactly at QR code left edge
- **Line Spacing** - Optimized vertical spacing between text lines for better readability

### Technical Improvements
- **Kotlin Implementation** - Enhanced Android native code with better positioning logic
- **Test Coverage** - Updated test files to match new API signatures
- **Documentation** - Comprehensive README update with new features and examples
- **Error Handling** - Improved error messages and debugging information

## [1.0.0] - 2024-01-XX

### Added
- **Initial Release** - Comprehensive thermal Bluetooth label printing plugin
- **Bluetooth Connectivity** - Support for both Classic Bluetooth (SPP) and BLE
- **Thermal Printing** - TSPL language support for professional label printing
- **Smart Positioning** - Automatic content centering based on label dimensions
- **Gap Detection** - Intelligent label boundary detection and frame management
- **Multiple Formats** - QR codes, barcodes, text, and combined content printing
- **Batch Processing** - Sequence printing with proper label separation
- **Buffer Management** - Advanced buffer clearing strategies for reliable printing
- **Cross-Platform Support** - Full Android and iOS implementation
- **Device Pairing** - PIN code handling and pairing management
- **Connection Management** - Robust connection strategies with fallbacks
- **Error Handling** - Comprehensive error management and user feedback
- **Performance Optimization** - Connection pooling and command batching

### Features
- **Single Label Printing** - Print individual labels with gap detection
- **Multiple Labels Printing** - Batch print multiple labels with different content
- **Custom Label Sizes** - Support for various label dimensions (2" to 4.65" width)
- **DPI Configuration** - Support for 203 DPI and higher resolution printers
- **Text Customization** - Configurable text size and positioning
- **Copy Management** - Print multiple copies of labels
- **Paper Configuration** - Automatic paper size detection and configuration
- **Printer Status** - Real-time printer status monitoring
- **Buffer Operations** - Clear, feed, and manage printer buffers

### Technical Features
- **Platform Interface** - Clean abstraction layer for cross-platform development
- **Method Channels** - Efficient Flutter-to-native communication
- **Kotlin Implementation** - Modern Android development with coroutines
- **Swift Implementation** - Native iOS development with CoreBluetooth
- **Comprehensive Testing** - Unit tests and integration tests
- **Documentation** - Complete API reference and integration guides

### Supported Platforms
- **Android** - API level 26+ (Android 8.0+)
- **iOS** - iOS 12.0+
- **Flutter** - 3.19.0+

### Supported Printers
- **TSPL-Compatible** - N41, N42, and similar thermal label printers
- **Resolution** - 203 DPI (8 dots/mm) and higher
- **Label Sizes** - 2" (50mm) to 4.65" (118mm) width
- **Media Types** - Die-cut labels, continuous paper, black mark paper

### Documentation
- **README.md** - Comprehensive overview and quick start
- **API Reference** - Complete method documentation
- **Integration Guide** - Step-by-step integration instructions
- **UI Implementation Guide** - UI framework examples
- **Label Printing Flow** - Detailed printing process documentation
- **Troubleshooting Guide** - Common issues and solutions
- **Development Guide** - Contributing and development setup
- **Release Preparation Guide** - Release process and checklist

---

## [0.0.1] - 2024-01-XX

### Added
- Initial plugin structure
- Basic Bluetooth connectivity
- Basic printing functionality
- Platform interface setup

---

**Note**: This changelog follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format and [Semantic Versioning](https://semver.org/spec/v2.0.0.html) principles.

For detailed information about each release, please refer to the [GitHub releases](https://github.com/yourusername/ntbp_plugin/releases) page.
