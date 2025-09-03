import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ntbp_plugin_platform_interface.dart';
import 'models/bluetooth_device.dart';
import 'models/print_command.dart';

/// An implementation of [NtbpPluginPlatform] that uses method channels.
class MethodChannelNtbpPlugin extends NtbpPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ntbp_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    final result = await methodChannel.invokeMethod<bool>('isBluetoothAvailable');
    return result ?? false;
  }

  @override
  Future<bool> requestBluetoothPermissions() async {
    final result = await methodChannel.invokeMethod<bool>('requestBluetoothPermissions');
    return result ?? false;
  }

  @override
  Future<String> checkDevicePairingStatus(String address) async {
    final result = await methodChannel.invokeMethod<String>('checkDevicePairingStatus', {
      'address': address,
    });
    return result ?? 'UNKNOWN';
  }

  @override
  Future<String> requestDevicePairing(String address) async {
    final result = await methodChannel.invokeMethod<String>('requestDevicePairing', {
      'address': address,
    });
    return result ?? 'ERROR';
  }

  @override
  Future<String> requestDevicePairingWithPin(String address, String pinCode) async {
    final result = await methodChannel.invokeMethod<String>('requestDevicePairingWithPin', {
      'address': address,
      'pinCode': pinCode,
    });
    return result ?? 'ERROR';
  }

  @override
  Future<String?> getStoredPinCode(String address) async {
    final result = await methodChannel.invokeMethod<String>('getStoredPinCode', {
      'address': address,
    });
    return result;
  }

  @override
  Future<bool> removeStoredPinCode(String address) async {
    final result = await methodChannel.invokeMethod<bool>('removeStoredPinCode', {
      'address': address,
    });
    return result ?? false;
  }

  @override
  Future<void> startScan() async {
    await methodChannel.invokeMethod('startScan');
  }

  @override
  Future<void> stopScan() async {
    await methodChannel.invokeMethod('stopScan');
  }

  @override
  Future<List<BluetoothDevice>> getDiscoveredDevices() async {
    final List<dynamic> result = await methodChannel.invokeMethod('getDiscoveredDevices') ?? [];
    return result.map((device) => BluetoothDevice.fromMap(Map<String, dynamic>.from(device))).toList();
  }

  @override
  Future<bool> connectToDevice(BluetoothDevice device) async {
    final result = await methodChannel.invokeMethod<bool>('connectToDevice', device.toMap());
    return result ?? false;
  }

  @override
  Future<bool> disconnect() async {
    final result = await methodChannel.invokeMethod<bool>('disconnect');
    return result ?? false;
  }

  @override
  Future<bool> isConnected() async {
    final result = await methodChannel.invokeMethod<bool>('isConnected');
    return result ?? false;
  }

  @override
  Future<bool> print(List<PrintCommand> commands) async {
    final result = await methodChannel.invokeMethod<bool>('print', {
      'commands': commands.map((cmd) => cmd.toMap()).toList(),
    });
    return result ?? false;
  }

  @override
  Future<bool> printText(String text) async {
    final result = await methodChannel.invokeMethod<bool>('printText', {
      'text': text,
    });
    return result ?? false;
  }

  @override
  Future<bool> printBarcode(String data) async {
    final result = await methodChannel.invokeMethod<bool>('printBarcode', {
      'data': data,
    });
    return result ?? false;
  }

  @override
  Future<bool> printQRCode(String data) async {
    final result = await methodChannel.invokeMethod<bool>('printQRCode', {
      'data': data,
    });
    return result ?? false;
  }

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
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printTextAdvanced', {
      'text': text,
      'x': x,
      'y': y,
      'fontNumber': fontNumber,
      'codePage': codePage,
      'rotation': rotation,
      'xMultiplication': xMultiplication,
      'yMultiplication': yMultiplication,
    });
    return result ?? false;
  }

  @override
  Future<bool> printBarcodeAdvanced(
    String data, {
    double? x,
    double? y,
    int? rotation,
    String? codePage,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printBarcodeAdvanced', {
      'data': data,
      'x': x,
      'y': y,
      'rotation': rotation,
      'codePage': codePage,
    });
    return result ?? false;
  }

  @override
  Future<bool> printQRCodeAdvanced(
    String data, {
    double? x,
    double? y,
    String? size,
    String? errorCorrection,
    String? model,
    int? rotation,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printQRCodeAdvanced', {
      'data': data,
      'x': x,
      'y': y,
      'size': size,
      'errorCorrection': errorCorrection,
      'model': model,
      'rotation': rotation,
    });
    return result ?? false;
  }

  @override
  Future<bool> printImage(
    String imagePath, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printImage', {
      'imagePath': imagePath,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
    return result ?? false;
  }

  @override
  Future<bool> printBlock(
    String text, {
    double? x,
    double? y,
    double? width,
    double? height,
    int? lineWidth,
    int? lineStyle,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printBlock', {
      'text': text,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'lineWidth': lineWidth,
      'lineStyle': lineStyle,
    });
    return result ?? false;
  }

  @override
  Future<bool> setPrintArea(double width, double height) async {
    final result = await methodChannel.invokeMethod<bool>('setPrintArea', {
      'width': width,
      'height': height,
    });
    return result ?? false;
  }

  @override
  Future<bool> clearPrintBuffer() async {
    final result = await methodChannel.invokeMethod<bool>('clearPrintBuffer');
    return result ?? false;
  }

  @override
  Future<bool> executePrint(int copies, int labels) async {
    final result = await methodChannel.invokeMethod<bool>('executePrint', {
      'copies': copies,
      'labels': labels,
    });
    return result ?? false;
  }

  @override
  Future<bool> printBarcodeWithText(
    String barcodeData,
    String textData, {
    double? x,
    double? y,
    int? barcodeHeight,
    int? textFont,
    double? textScale,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printBarcodeWithText', {
      'barcodeData': barcodeData,
      'textData': textData,
      'x': x,
      'y': y,
      'barcodeHeight': barcodeHeight,
      'textFont': textFont,
      'textScale': textScale,
    });
    return result ?? false;
  }

  @override
  Future<bool> printSmartLabel(Map<String, dynamic> labelData) async {
    final result = await methodChannel.invokeMethod<bool>('printSmartLabel', labelData);
    return result ?? false;
  }

  @override
  Future<bool> printSmartSequence(List<Map<String, dynamic>> labelDataList) async {
    final result = await methodChannel.invokeMethod<bool>('printSmartSequence', {
      'labelDataList': labelDataList,
    });
    return result ?? false;
  }

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
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printProfessionalLabel', {
      'qrData': qrData,
      'textData': textData,
      'labelWidth': labelWidth,
      'labelHeight': labelHeight,
      'labelUnit': labelUnit,
      'dpi': dpi,
      'copies': copies,
      'speedMode': speedMode,
    });
    return result ?? false;
  }

  @override
  Future<bool> printLabelSequence(List<Map<String, dynamic>> labelDataList) async {
    final result = await methodChannel.invokeMethod<bool>('printLabelSequence', {
      'labelDataList': labelDataList,
    });
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> getLabelPaperConfig(double width, double height, String unit) async {
    final result = await methodChannel.invokeMethod<Map<String, dynamic>>('getLabelPaperConfig', {
      'width': width,
      'height': height,
      'unit': unit,
    });
    return result ?? {};
  }

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
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printCustomLabel', {
      'qrData': qrData,
      'textData': textData,
      'width': width,
      'height': height,
      'unit': unit,
      'dpi': dpi,
      'qrSize': qrSize,
      'textSize': textSize,
    });
    return result ?? false;
  }

  @override
  Future<bool> feedPaper(int lines) async {
    final result = await methodChannel.invokeMethod<bool>('feedPaper', {'lines': lines});
    return result ?? false;
  }

  @override
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
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printSingleLabelWithGapDetection', {
      'qrData': qrData,
      'textData1': textData1,
      'textData2': textData2,
      'textData3': textData3,
      'width': width,
      'height': height,
      'unit': unit,
      'dpi': dpi,
      'copies': copies,
      'textSize': textSize,
    });
    return result ?? false;
  }

  @override
  Future<bool> printMultipleLabelsWithGapDetection({
    required List<Map<String, dynamic>> labelDataList,
    required double width,
    required double height,
    String? unit,
    int? dpi,
    int? copiesPerLabel,
    int? textSize,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('printMultipleLabelsWithGapDetection', {
      'labelDataList': labelDataList,
      'width': width,
      'height': height,
      'unit': unit,
      'dpi': dpi,
      'copiesPerLabel': copiesPerLabel,
      'textSize': textSize,
    });
    return result ?? false;
  }

  @override
  Future<bool> clearBuffer() async {
    final result = await methodChannel.invokeMethod<bool>('clearBuffer');
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> getPrinterStatus() async {
    final result = await methodChannel.invokeMethod<Map<String, dynamic>>('getPrinterStatus');
    return result ?? {};
  }

  @override
  Future<String> getConnectionStatus() async {
    final result = await methodChannel.invokeMethod<String>('getConnectionStatus');
    return result ?? 'UNKNOWN';
  }

  @override
  Future<Map<String, dynamic>> getDetailedConnectionStatus() async {
    final result = await methodChannel.invokeMethod<Map<String, dynamic>>('getDetailedConnectionStatus');
    return result ?? {};
  }

  // NEW: Protocol system methods that connect to native code
  @override
  Future<bool> sendProtocolCommands(List<int> commands, String protocolName) async {
    final result = await methodChannel.invokeMethod<bool>('sendProtocolCommands', {
      'commands': commands,
      'protocolName': protocolName,
    });
    return result ?? false;
  }

  @override
  Future<bool> initializeProtocolPrinter(String printerModel, double labelWidth, double labelHeight, String unit, int dpi) async {
    final result = await methodChannel.invokeMethod<bool>('initializeProtocolPrinter', {
      'printerModel': printerModel,
      'labelWidth': labelWidth,
      'labelHeight': labelHeight,
      'unit': unit,
      'dpi': dpi,
    });
    return result ?? false;
  }

  @override
  Future<bool> printWithProtocol(String protocolName, Map<String, dynamic> printData) async {
    final result = await methodChannel.invokeMethod<bool>('printWithProtocol', {
      'protocolName': protocolName,
      'printData': printData,
    });
    return result ?? false;
  }
}
