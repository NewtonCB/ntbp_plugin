
export 'ntbp_plugin_platform_interface.dart';
export 'ntbp_plugin_method_channel.dart';
export 'models/bluetooth_device.dart';
export 'models/print_command.dart';

import 'ntbp_plugin_platform_interface.dart';
import 'models/bluetooth_device.dart';
import 'models/print_command.dart';

class NtbpPlugin {
  Future<String?> getPlatformVersion() {
    return NtbpPluginPlatform.instance.getPlatformVersion();
  }

  /// Check if Bluetooth is available on the device
  Future<bool> isBluetoothAvailable() {
    return NtbpPluginPlatform.instance.isBluetoothAvailable();
  }

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermissions() {
    return NtbpPluginPlatform.instance.requestBluetoothPermissions();
  }

  /// Check device pairing status
  Future<String> checkDevicePairingStatus(String address) {
    return NtbpPluginPlatform.instance.checkDevicePairingStatus(address);
  }

  /// Request device pairing
  Future<String> requestDevicePairing(String address) {
    return NtbpPluginPlatform.instance.requestDevicePairing(address);
  }

  /// Request device pairing with PIN code
  Future<String> requestDevicePairingWithPin(String address, String pinCode) {
    return NtbpPluginPlatform.instance.requestDevicePairingWithPin(address, pinCode);
  }

  /// Get stored PIN code for a device
  Future<String?> getStoredPinCode(String address) {
    return NtbpPluginPlatform.instance.getStoredPinCode(address);
  }

  /// Remove stored PIN code for a device
  Future<bool> removeStoredPinCode(String address) {
    return NtbpPluginPlatform.instance.removeStoredPinCode(address);
  }

  /// Start scanning for Bluetooth devices
  Future<void> startScan() {
    return NtbpPluginPlatform.instance.startScan();
  }

  /// Stop scanning for Bluetooth devices
  Future<void> stopScan() {
    return NtbpPluginPlatform.instance.stopScan();
  }

  /// Get list of discovered devices
  Future<List<BluetoothDevice>> getDiscoveredDevices() {
    return NtbpPluginPlatform.instance.getDiscoveredDevices();
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(BluetoothDevice device) {
    return NtbpPluginPlatform.instance.connectToDevice(device);
  }

  /// Disconnect from current device
  Future<bool> disconnect() {
    return NtbpPluginPlatform.instance.disconnect();
  }

  /// Check if connected to a device
  Future<bool> isConnected() {
    return NtbpPluginPlatform.instance.isConnected();
  }

  /// Print text or commands
  Future<bool> print(List<PrintCommand> commands) {
    return NtbpPluginPlatform.instance.print(commands);
  }

  /// Print a simple text string
  Future<bool> printText(String text) {
    return NtbpPluginPlatform.instance.printText(text);
  }

  /// Print a barcode
  Future<bool> printBarcode(String data) {
    return NtbpPluginPlatform.instance.printBarcode(data);
  }

  /// Print a QR code
  Future<bool> printQRCode(String data) {
    return NtbpPluginPlatform.instance.printQRCode(data);
  }

  // Advanced printing methods
  Future<bool> printTextAdvanced(
    String text, {
    double? x,
    double? y,
    int? fontNumber,
    String? codePage,
    int? rotation,
    double? xMultiplication,
    double? yMultiplication,
  }) {
    return NtbpPluginPlatform.instance.printTextAdvanced(
      text,
      x: x,
      y: y,
      fontNumber: fontNumber,
      codePage: codePage,
      rotation: rotation,
      xMultiplication: xMultiplication,
      yMultiplication: yMultiplication,
    );
  }

  Future<bool> printBarcodeAdvanced(
    String data, {
    double? x,
    double? y,
    int? rotation,
    String? codePage,
  }) {
    return NtbpPluginPlatform.instance.printBarcodeAdvanced(
      data,
      x: x,
      y: y,
      rotation: rotation,
      codePage: codePage,
    );
  }

  Future<bool> printQRCodeAdvanced(
    String data, {
    double? x,
    double? y,
    String? size,
    String? errorCorrection,
    String? model,
    int? rotation,
  }) {
    return NtbpPluginPlatform.instance.printQRCodeAdvanced(
      data,
      x: x,
      y: y,
      size: size,
      errorCorrection: errorCorrection,
      model: model,
      rotation: rotation,
    );
  }

  Future<bool> printImage(
    String imagePath, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return NtbpPluginPlatform.instance.printImage(
      imagePath,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  Future<bool> printBlock(
    String text, {
    double? x,
    double? y,
    double? width,
    double? height,
    int? lineWidth,
    int? lineStyle,
  }) {
    return NtbpPluginPlatform.instance.printBlock(
      text,
      x: x,
      y: y,
      width: width,
      height: height,
      lineWidth: lineWidth,
      lineStyle: lineStyle,
    );
  }

  Future<bool> setPrintArea(double width, double height) {
    return NtbpPluginPlatform.instance.setPrintArea(width, height);
  }

  Future<bool> clearPrintBuffer() {
    return NtbpPluginPlatform.instance.clearPrintBuffer();
  }

  Future<bool> executePrint(int copies, int labels) {
    return NtbpPluginPlatform.instance.executePrint(copies, labels);
  }

  /// Print barcode with text below it in one operation
  Future<bool> printBarcodeWithText(
    String barcodeData,
    String textData, {
    double? x,
    double? y,
    int? barcodeHeight,
    int? textFont,
    double? textScale,
  }) {
    return NtbpPluginPlatform.instance.printBarcodeWithText(
      barcodeData,
      textData,
      x: x,
      y: y,
      barcodeHeight: barcodeHeight,
      textFont: textFont,
      textScale: textScale,
    );
  }

  /// Print professional label with QR code and text positioning
  Future<bool> printProfessionalLabel({
    required String qrData,
    required String textData,
    required double labelWidth,
    required double labelHeight,
    String? labelUnit,
    int? dpi,
    int? copies,
    String? speedMode,
  }) {
    return NtbpPluginPlatform.instance.printProfessionalLabel(
      qrData: qrData,
      textData: textData,
      labelWidth: labelWidth,
      labelHeight: labelHeight,
      labelUnit: labelUnit,
      dpi: dpi,
      copies: copies,
      speedMode: speedMode,
    );
  }

  /// Print sequence of labels from backend data
  Future<bool> printLabelSequence(List<Map<String, dynamic>> labelDataList) {
    return NtbpPluginPlatform.instance.printLabelSequence(labelDataList);
  }

  /// Get label paper configuration for specific dimensions
  Future<Map<String, dynamic>> getLabelPaperConfig(double width, double height, String unit) {
    return NtbpPluginPlatform.instance.getLabelPaperConfig(width, height, unit);
  }

  /// Get connection status
  Future<String> getConnectionStatus() {
    return NtbpPluginPlatform.instance.getConnectionStatus();
  }

  /// Get detailed connection status for debugging
  Future<Map<String, dynamic>> getDetailedConnectionStatus() {
    return NtbpPluginPlatform.instance.getDetailedConnectionStatus();
  }

  /// Print custom label with user-defined dimensions and sizes
  Future<bool> printCustomLabel({
    required String qrData,
    required String textData,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    double? qrSize,
    double? textSize,
  }) {
    return NtbpPluginPlatform.instance.printCustomLabel(
      qrData: qrData,
      textData: textData,
      width: width,
      height: height,
      unit: unit,
      dpi: dpi,
      qrSize: qrSize,
      textSize: textSize,
    );
  }

  /// Clear the print buffer
  Future<bool> clearBuffer() {
    return NtbpPluginPlatform.instance.clearBuffer();
  }

  /// Get printer status
  Future<Map<String, dynamic>> getPrinterStatus() {
    return NtbpPluginPlatform.instance.getPrinterStatus();
  }

  /// Feed paper by specified number of lines
  Future<bool> feedPaper(int lines) {
    return NtbpPluginPlatform.instance.feedPaper(lines);
  }

  /// Print a smart label with automatic gap detection and positioning
  static Future<bool> printSmartLabel({
    required String qrData,
    required String textData,
    required double width,
    required double height,
    required String unit,
    required int dpi,
  }) {
    return NtbpPluginPlatform.instance.printSmartLabel({
      'qrData': qrData,
      'textData': textData,
      'width': width,
      'height': height,
      'unit': unit,
      'dpi': dpi,
    });
  }

  /// Print a sequence of smart labels with gap detection
  static Future<bool> printSmartSequence(List<Map<String, dynamic>> labelDataList) {
    return NtbpPluginPlatform.instance.printSmartSequence(labelDataList);
  }

  /// Print single label with gap detection and proper positioning
  static Future<bool> printSingleLabelWithGapDetection({
    required String qrData,
    required String textData,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copies,
    int? textSize,
  }) {
    return NtbpPluginPlatform.instance.printSingleLabelWithGapDetection(
      qrData: qrData,
      textData: textData,
      width: width,
      height: height,
      unit: unit,
      dpi: dpi,
      copies: copies,
      textSize: textSize,
    );
  }

  /// Print multiple labels with different content and proper gap detection
  static Future<bool> printMultipleLabelsWithGapDetection({
    required List<Map<String, dynamic>> labelDataList,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copiesPerLabel,
    int? textSize,
  }) {
    return NtbpPluginPlatform.instance.printMultipleLabelsWithGapDetection(
      labelDataList: labelDataList,
      width: width,
      height: height,
      unit: unit,
      dpi: dpi,
      copiesPerLabel: copiesPerLabel,
      textSize: textSize,
    );
  }
}
