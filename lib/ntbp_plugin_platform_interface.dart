import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ntbp_plugin_method_channel.dart';
import 'models/bluetooth_device.dart';
import 'models/print_command.dart';

abstract class NtbpPluginPlatform extends PlatformInterface {
  /// Constructs a NtbpPluginPlatform.
  NtbpPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static NtbpPluginPlatform _instance = MethodChannelNtbpPlugin();

  /// The default instance of [NtbpPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelNtbpPlugin].
  static NtbpPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NtbpPluginPlatform] when
  /// they register themselves.
  static set instance(NtbpPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Check if Bluetooth is available on the device
  Future<bool> isBluetoothAvailable() {
    throw UnimplementedError('isBluetoothAvailable() has not been implemented.');
  }

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermissions() {
    throw UnimplementedError('requestBluetoothPermissions() has not been implemented.');
  }

  /// Check device pairing status
  Future<String> checkDevicePairingStatus(String address) {
    throw UnimplementedError('checkDevicePairingStatus() has not been implemented.');
  }

  /// Request device pairing
  Future<String> requestDevicePairing(String address) {
    throw UnimplementedError('requestDevicePairing() has not been implemented.');
  }

  /// Request device pairing with PIN code
  Future<String> requestDevicePairingWithPin(String address, String pinCode) {
    throw UnimplementedError('requestDevicePairingWithPin() has not been implemented.');
  }

  /// Get stored PIN code for a device
  Future<String?> getStoredPinCode(String address) {
    throw UnimplementedError('getStoredPinCode() has not been implemented.');
  }

  /// Remove stored PIN code for a device
  Future<bool> removeStoredPinCode(String address) {
    throw UnimplementedError('removeStoredPinCode() has not been implemented.');
  }

  /// Start scanning for Bluetooth devices
  Future<void> startScan() {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  /// Stop scanning for Bluetooth devices
  Future<void> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  /// Get list of discovered devices
  Future<List<BluetoothDevice>> getDiscoveredDevices() {
    throw UnimplementedError('getDiscoveredDevices() has not been implemented.');
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(BluetoothDevice device) {
    throw UnimplementedError('connectToDevice() has not been implemented.');
  }

  /// Disconnect from current device
  Future<bool> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  /// Check if connected to a device
  Future<bool> isConnected() {
    throw UnimplementedError('isConnected() has not been implemented.');
  }

  /// Print text or commands
  Future<bool> print(List<PrintCommand> commands) {
    throw UnimplementedError('print() has not been implemented.');
  }

  /// Print a simple text string
  Future<bool> printText(String text) {
    throw UnimplementedError('printText() has not been implemented.');
  }

  /// Print a barcode
  Future<bool> printBarcode(String data) {
    throw UnimplementedError('printBarcode() has not been implemented.');
  }

  /// Print a QR code
  Future<bool> printQRCode(String data) {
    throw UnimplementedError('printQRCode() has not been implemented.');
  }

  /// Advanced text printing with positioning and formatting
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
    throw UnimplementedError('printTextAdvanced() has not been implemented.');
  }

  /// Advanced barcode printing with positioning
  Future<bool> printBarcodeAdvanced(
    String data, {
    double? x,
    double? y,
    int? rotation,
    String? codePage,
  }) {
    throw UnimplementedError('printBarcodeAdvanced() has not been implemented.');
  }

  /// Advanced QR code printing with positioning and options
  Future<bool> printQRCodeAdvanced(
    String data, {
    double? x,
    double? y,
    String? size,
    String? errorCorrection,
    String? model,
    int? rotation,
  }) {
    throw UnimplementedError('printQRCodeAdvanced() has not been implemented.');
  }

  /// Print an image
  Future<bool> printImage(
    String imagePath, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    throw UnimplementedError('printImage() has not been implemented.');
  }

  /// Print a block with text
  Future<bool> printBlock(
    String text, {
    double? x,
    double? y,
    double? width,
    double? height,
    int? lineWidth,
    int? lineStyle,
  }) {
    throw UnimplementedError('printBlock() has not been implemented.');
  }

  /// Set print area size
  Future<bool> setPrintArea(double width, double height) {
    throw UnimplementedError('setPrintArea() has not been implemented.');
  }

  /// Clear the print buffer
  Future<bool> clearPrintBuffer() {
    throw UnimplementedError('clearPrintBuffer() has not been implemented.');
  }

  /// Execute the print job
  Future<bool> executePrint(int copies, int labels) {
    throw UnimplementedError('executePrint() has not been implemented.');
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
    throw UnimplementedError('printBarcodeWithText() has not been implemented.');
  }

  /// Print smart label with auto-positioning based on label size
  Future<bool> printSmartLabel(Map<String, dynamic> labelData) {
    throw UnimplementedError('printSmartLabel() has not been implemented.');
  }

  /// Print a sequence of smart labels with gap detection
  Future<bool> printSmartSequence(List<Map<String, dynamic>> labelDataList) {
    throw UnimplementedError('printSmartSequence() has not been implemented.');
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
    throw UnimplementedError('printProfessionalLabel() has not been implemented.');
  }

  /// Print sequence of labels from backend data
  Future<bool> printLabelSequence(List<Map<String, dynamic>> labelDataList) {
    throw UnimplementedError('printLabelSequence() has not been implemented.');
  }

  /// Get label paper configuration for specific dimensions
  Future<Map<String, dynamic>> getLabelPaperConfig(double width, double height, String unit) {
    throw UnimplementedError('getLabelPaperConfig() has not been implemented.');
  }

  /// Get connection status
  Future<String> getConnectionStatus() {
    throw UnimplementedError('getConnectionStatus() has not been implemented.');
  }

  /// Get detailed connection status for debugging
  Future<Map<String, dynamic>> getDetailedConnectionStatus() {
    throw UnimplementedError('getDetailedConnectionStatus() has not been implemented.');
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
    throw UnimplementedError('printCustomLabel() has not been implemented.');
  }

  /// Clear the print buffer
  Future<bool> clearBuffer() {
    throw UnimplementedError('clearBuffer() has not been implemented.');
  }

  /// Get printer status
  Future<Map<String, dynamic>> getPrinterStatus() {
    throw UnimplementedError('getPrinterStatus() has not been implemented.');
  }

  /// Feed paper by specified number of lines
  Future<bool> feedPaper(int lines) {
    throw UnimplementedError('feedPaper() has not been implemented.');
  }

  /// Print single label with gap detection and proper positioning
  Future<bool> printSingleLabelWithGapDetection({
    required String qrData,
    required String textData1, // Customer name
    required String textData2, // Drop point
    required String textData3, // Additional info
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copies,
    int? textSize,
  }) {
    throw UnimplementedError('printSingleLabelWithGapDetection() has not been implemented.');
  }

  /// Print multiple labels with different content and proper gap detection
  Future<bool> printMultipleLabelsWithGapDetection({
    required List<Map<String, dynamic>> labelDataList,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copiesPerLabel,
    int? textSize,
  }) {
    throw UnimplementedError('printMultipleLabelsWithGapDetection() has not been implemented.');
  }

  /// Send protocol commands to printer (for protocol system)
  Future<bool> sendProtocolCommands(List<int> commands, String protocolName) {
    throw UnimplementedError('sendProtocolCommands() has not been implemented.');
  }

  /// Initialize printer with protocol-specific settings
  Future<bool> initializeProtocolPrinter(String printerModel, double labelWidth, double labelHeight, String unit, int dpi) {
    throw UnimplementedError('initializeProtocolPrinter() has not been implemented.');
  }

  /// Print using protocol system
  Future<bool> printWithProtocol(String protocolName, Map<String, dynamic> printData) {
    throw UnimplementedError('printWithProtocol() has not been implemented.');
  }


}
