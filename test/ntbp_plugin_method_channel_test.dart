import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ntbp_plugin/ntbp_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelNtbpPlugin platform = MethodChannelNtbpPlugin();
  const MethodChannel channel = MethodChannel('ntbp_plugin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('sendProtocolCommands sends bytes as typed data', () async {
    Object? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async {
        received = (call.arguments as Map)['commands'];
        return true;
      },
    );
    expect(await platform.sendProtocolCommands([0x53, 0x49, 0xFF], 'TSPL'), isTrue);
    expect(received, isA<Uint8List>());
    expect(received, [0x53, 0x49, 0xFF]);
  });
}
