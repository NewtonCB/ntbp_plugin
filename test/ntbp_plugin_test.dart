import 'package:flutter_test/flutter_test.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNtbpPluginPlatform
    with MockPlatformInterfaceMixin
    implements NtbpPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> isBluetoothAvailable() => Future.value(true);

  @override
  Future<bool> requestBluetoothPermissions() => Future.value(true);

  @override
  Future<void> startScan() => Future.value();

  @override
  Future<void> stopScan() => Future.value();

  @override
  Future<List<BluetoothDevice>> getDiscoveredDevices() => Future.value([]);

  @override
  Future<bool> connectToDevice(BluetoothDevice device) => Future.value(true);

  @override
  Future<bool> disconnect() => Future.value(true);

  @override
  Future<bool> isConnected() => Future.value(false);

  @override
  Future<bool> print(List<PrintCommand> commands) => Future.value(true);

  @override
  Future<bool> printText(String text) => Future.value(true);

  @override
  Future<bool> printBarcode(String data) => Future.value(true);

  @override
  Future<bool> printQRCode(String data) => Future.value(true);

  @override
  Future<bool> printTextAdvanced(
    String text, {
    double? x,
    double? y,
    int? fontNumber,
    String? codePage,
    int? rotation,
    double? xMultiplication,
    double? yMultiplication,
  }) => Future.value(true);

  @override
  Future<bool> printBarcodeAdvanced(
    String data, {
    double? x,
    double? y,
    int? rotation,
    String? codePage,
  }) => Future.value(true);

  @override
  Future<bool> printQRCodeAdvanced(
    String data, {
    double? x,
    double? y,
    String? size,
    String? errorCorrection,
    String? model,
    int? rotation,
  }) => Future.value(true);

  @override
  Future<bool> printImage(
    String imagePath, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) => Future.value(true);

  @override
  Future<bool> printBlock(
    String text, {
    double? x,
    double? y,
    double? width,
    double? height,
    int? lineWidth,
    int? lineStyle,
  }) => Future.value(true);

  @override
  Future<bool> setPrintArea(double width, double height) => Future.value(true);

  @override
  Future<bool> clearPrintBuffer() => Future.value(true);

  @override
  Future<bool> executePrint(int copies, int labels) => Future.value(true);

  @override
  Future<Map<String, dynamic>> getPrinterStatus() => Future.value({
    'connected': true,
    'socketConnected': true,
    'hasOutputStream': true,
    'connectionState': 'CONNECTED',
  });

  @override
  Future<String> checkDevicePairingStatus(String address) => Future.value('PAIRED');

  @override
  Future<String> requestDevicePairing(String address) => Future.value('PAIRING_REQUESTED');

  @override
  Future<String> requestDevicePairingWithPin(String address, String pinCode) => Future.value('PAIRING_WITH_PIN_REQUESTED');

  @override
  Future<String?> getStoredPinCode(String address) => Future.value('0000');

  @override
  Future<bool> removeStoredPinCode(String address) => Future.value(true);

  @override
  Future<bool> printBarcodeWithText(
    String barcodeData,
    String textData, {
    double? x,
    double? y,
    int? barcodeHeight,
    int? textFont,
    double? textScale,
  }) => Future.value(true);

  @override
  Future<bool> printSmartLabel(Map<String, dynamic> labelData) => Future.value(true);

  @override
  Future<bool> printSmartSequence(List<Map<String, dynamic>> labelDataList) => Future.value(true);

  @override
  Future<bool> printProfessionalLabel({
    required String qrData,
    required String textData,
    required double labelWidth,
    required double labelHeight,
    String? labelUnit,
    int? dpi,
    int? copies,
    String? speedMode,
  }) => Future.value(true);

  @override
  Future<bool> printLabelSequence(List<Map<String, dynamic>> labelDataList) => Future.value(true);

  @override
  Future<Map<String, dynamic>> getLabelPaperConfig(double width, double height, String unit) => Future.value({
    'name': 'Medium',
    'margin': 4.0,
    'qrUsagePercent': 0.85,
    'minQrSize': 100,
    'useMaxDimension': false,
    'description': '2000-4000mm² (e.g., 50x50mm)',
  });

  @override
  Future<String> getConnectionStatus() => Future.value('CONNECTED');

  @override
  Future<Map<String, dynamic>> getDetailedConnectionStatus() => Future.value({
    'connectionState': 'CONNECTED',
    'socketConnected': true,
    'hasOutputStream': true,
    'socketAddress': '00:11:22:33:44:55',
    'socketName': 'Test Printer',
    'isConnectionInProgress': false,
  });

  @override
  Future<bool> printCustomLabel({
    required String qrData,
    required String textData,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    double? qrSize,
    double? textSize,
  }) => Future.value(true);

  @override
  Future<bool> clearBuffer() => Future.value(true);

  @override
  Future<bool> feedPaper(int lines) => Future.value(true);

  @override
  Future<bool> printSingleLabelWithGapDetection({
    required String qrData,
    required String textData,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copies,
    int? textSize,
  }) => Future.value(true);

  @override
  Future<bool> printMultipleLabelsWithGapDetection({
    required List<Map<String, dynamic>> labelDataList,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copiesPerLabel,
    int? textSize,
  }) => Future.value(true);
}

void main() {
  final NtbpPluginPlatform initialPlatform = NtbpPluginPlatform.instance;

  test('$MethodChannelNtbpPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNtbpPlugin>());
  });

  test('getPlatformVersion', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    expect(await ntbpPlugin.getPlatformVersion(), '42');
  });

  test('isBluetoothAvailable', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    expect(await ntbpPlugin.isBluetoothAvailable(), true);
  });

  test('startScan', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    await ntbpPlugin.startScan(); // Should not throw
  });

  test('getDiscoveredDevices returns list of devices', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    final devices = await ntbpPlugin.getDiscoveredDevices();
    expect(devices, isA<List<BluetoothDevice>>());
  });

  test('printTextAdvanced works correctly', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    final result = await ntbpPlugin.printTextAdvanced(
      'Test Text',
      x: 10.0,
      y: 20.0,
      fontNumber: 5,
      xMultiplication: 2.0,
      yMultiplication: 2.0,
    );
    expect(result, isTrue);
  });

  test('printBarcodeAdvanced works correctly', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    final result = await ntbpPlugin.printBarcodeAdvanced(
      '123456789',
      x: 10.0,
      y: 20.0,
      rotation: 0,
    );
    expect(result, isTrue);
  });

  test('printQRCodeAdvanced works correctly', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    final result = await ntbpPlugin.printQRCodeAdvanced(
      'https://example.com',
      x: 10.0,
      y: 20.0,
      size: 'M',
      errorCorrection: '5',
      model: 'M1',
      rotation: 0,
    );
    expect(result, isTrue);
  });

  test('setPrintArea works correctly', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    final result = await ntbpPlugin.setPrintArea(100.0, 150.0);
    expect(result, isTrue);
  });

  test('getPrinterStatus returns status map', () async {
    NtbpPlugin ntbpPlugin = NtbpPlugin();
    MockNtbpPluginPlatform fakePlatform = MockNtbpPluginPlatform();
    NtbpPluginPlatform.instance = fakePlatform;

    final status = await ntbpPlugin.getPrinterStatus();
    expect(status, isA<Map<String, dynamic>>());
  });
}
