# NTBP Plugin - Troubleshooting Guide

## 🐛 Common Issues and Solutions

This guide covers the most common issues you may encounter when using the NTBP Plugin and provides step-by-step solutions.

## 📋 Table of Contents

1. [Installation Issues](#installation-issues)
2. [Bluetooth Connection Problems](#bluetooth-connection-problems)
3. [Printing Issues](#printing-issues)
4. [Permission Problems](#permission-problems)
5. [Performance Issues](#performance-issues)
6. [Debug Information](#debug-information)
7. [Getting Help](#getting-help)

## 🔧 Installation Issues

### Issue: Plugin Not Found
```
Error: Could not find package: ntbp_plugin
```

**Solutions:**
1. **Run dependency installation:**
   ```bash
   flutter pub get
   ```

2. **Check pubspec.yaml:**
   ```yaml
   dependencies:
     ntbp_plugin: ^1.0.0
   ```

3. **Restart your IDE/editor**

4. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   ```

### Issue: Platform Channel Errors
```
Error: MissingPluginException: No implementation found for method X
```

**Solutions:**
1. **Ensure platform setup is complete:**
   - Android: Check `AndroidManifest.xml` permissions
   - iOS: Check `Info.plist` and capabilities

2. **Rebuild the project:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Check platform-specific files exist:**
   - Android: `android/src/main/kotlin/.../NtbpPlugin.kt`
   - iOS: `ios/Classes/NtbpPlugin.swift`

## 🔌 Bluetooth Connection Problems

### Issue: Bluetooth Not Available
```
Error: Bluetooth not available
```

**Solutions:**
1. **Check device Bluetooth:**
   - Enable Bluetooth in device settings
   - Ensure Bluetooth is not in airplane mode

2. **Check app permissions:**
   - Grant Bluetooth permissions in app settings
   - Request permissions at runtime

3. **Verify device support:**
   - Ensure device supports Bluetooth Classic (SPP)
   - Check minimum API level (Android 5.0+)

### Issue: No Devices Found
```
Error: No devices found during scan
```

**Solutions:**
1. **Check printer state:**
   - Ensure printer is in pairing mode
   - Check if printer is already connected to another device

2. **Verify Bluetooth visibility:**
   - Make printer discoverable
   - Check printer Bluetooth settings

3. **Scan duration:**
   - Wait 10-15 seconds for scan completion
   - Try multiple scan attempts

4. **Distance and interference:**
   - Ensure printer is within 10 meters
   - Reduce Bluetooth interference

### Issue: Connection Failed
```
Error: Connection failed
```

**Solutions:**
1. **Check device pairing:**
   - Ensure device is paired first
   - Try pairing manually in Bluetooth settings

2. **Verify printer compatibility:**
   - Check if printer supports SPP profile
   - Ensure printer is not connected to another device

3. **Connection retry:**
   - Implement retry logic in your app
   - Wait between connection attempts

4. **Check printer status:**
   - Ensure printer has power
   - Check for paper jams or errors

### Issue: Connection Drops
```
Error: Connection lost during printing
```

**Solutions:**
1. **Implement reconnection logic:**
   ```dart
   Future<void> maintainConnection() async {
     Timer.periodic(Duration(seconds: 30), (timer) async {
       final status = await _plugin.getConnectionStatus();
       if (status != 'CONNECTED') {
         await _reconnect();
       }
     });
   }
   ```

2. **Check connection stability:**
   - Reduce distance between device and printer
   - Check for Bluetooth interference

3. **Power management:**
   - Disable battery optimization for your app
   - Keep device screen on during printing

## 🖨️ Printing Issues

### Issue: Not Connected Error
```
Error: Not connected to printer
```

**Solutions:**
1. **Check connection status:**
   ```dart
   final status = await _plugin.getConnectionStatus();
   if (status != 'CONNECTED') {
     // Reconnect or show error
   }
   ```

2. **Verify connection before printing:**
   ```dart
   Future<bool> printLabel() async {
     if (!await _isConnected()) {
       await _connectToPrinter();
     }
     // Proceed with printing
   }
   ```

3. **Check output stream:**
   - Ensure `outputStream` is initialized
   - Verify socket connection is active

### Issue: Content Bleeding Between Labels
```
Problem: Previous label content appears on new labels
```

**Solutions:**
1. **Clear buffer before printing:**
   ```dart
   await _plugin.clearBuffer();
   // Wait for buffer clearing
   await Future.delayed(Duration(milliseconds: 200));
   ```

2. **Use aggressive buffer clearing:**
   - The plugin now implements multiple clearing strategies
   - `CLEAR` + `CLS` + `HOME` commands

3. **Add delays between labels:**
   ```dart
   // For multiple labels
   await Future.delayed(Duration(milliseconds: 500));
   ```

4. **Check TSPL commands:**
   - Ensure proper `CLS` command usage
   - Verify command sequence order

### Issue: Label Positioning Problems
```
Problem: Content not centered or positioned correctly
```

**Solutions:**
1. **Check label dimensions:**
   - Verify width and height parameters
   - Ensure unit consistency (mm, inch, dot)

2. **Use smart positioning:**
   ```dart
   await _plugin.printSingleLabelWithGapDetection(
     // ... parameters
   );
   ```

3. **Verify DPI setting:**
   - Match printer's actual DPI (usually 203)
   - Check label size calculations

### Issue: Gap Detection Not Working
```
Problem: Printer doesn't detect label boundaries
```

**Solutions:**
1. **Check label type:**
   - Ensure labels have proper gaps
   - Verify gap size (typically 2-3mm)

2. **Use proper TSPL commands:**
   ```dart
   // Gap detection commands are automatically sent
   await _plugin.printSingleLabelWithGapDetection(...);
   ```

3. **Check printer settings:**
   - Verify gap detection is enabled
   - Check sensor alignment

### Issue: Print Quality Problems
```
Problem: Poor print quality or missing content
```

**Solutions:**
1. **Check print density:**
   - Verify `DENSITY` setting (default: 12)
   - Adjust based on label material

2. **Check content size:**
   - Ensure QR code fits within label
   - Verify text size is appropriate

3. **Check printer hardware:**
   - Clean print head
   - Check label material compatibility

## 🔐 Permission Problems

### Issue: Bluetooth Permissions Denied
```
Error: Bluetooth permissions denied
```

**Solutions:**
1. **Check AndroidManifest.xml:**
   ```xml
   <uses-permission android:name="android.permission.BLUETOOTH" />
   <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
   <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```

2. **Request permissions at runtime:**
   ```dart
   final hasPermissions = await _plugin.requestBluetoothPermissions();
   if (!hasPermissions) {
     // Show permission request dialog
     // Guide user to app settings
   }
   ```

3. **Check app settings:**
   - Go to device Settings → Apps → Your App → Permissions
   - Enable Bluetooth and Location permissions

### Issue: Location Permission Required
```
Error: Location permission required for Bluetooth scanning
```

**Solutions:**
1. **Request location permission:**
   ```dart
   await _plugin.requestBluetoothPermissions();
   ```

2. **Explain to users:**
   - Location permission is required for Bluetooth scanning
   - This is an Android requirement, not app-specific

3. **Handle permission denial:**
   ```dart
   if (!await _plugin.requestBluetoothPermissions()) {
     // Show explanation dialog
     // Guide user to settings
   }
   ```

## ⚡ Performance Issues

### Issue: Slow Connection
```
Problem: Connection takes too long
```

**Solutions:**
1. **Implement connection timeout:**
   ```dart
   try {
     await _plugin.connectToDevice(device).timeout(
       Duration(seconds: 30),
       onTimeout: () => throw TimeoutException('Connection timeout'),
     );
   } catch (e) {
     // Handle timeout
   }
   ```

2. **Use connection strategies:**
   - The plugin implements multiple connection strategies
   - Automatic fallback to alternative methods

3. **Optimize scan duration:**
   - Limit scan time for better performance
   - Cache discovered devices

### Issue: Memory Issues
```
Problem: App crashes or memory warnings
```

**Solutions:**
1. **Dispose resources properly:**
   ```dart
   @override
   void dispose() {
     _plugin.disconnect();
     super.dispose();
   }
   ```

2. **Limit concurrent operations:**
   - Don't run multiple scans simultaneously
   - Cancel previous operations before starting new ones

3. **Monitor memory usage:**
   - Use Flutter DevTools to monitor memory
   - Check for memory leaks

## 🐛 Debug Information

### Enable Debug Logging

```dart
// Add debug prints to track operations
class DebugPrinterService {
  final NtbpPlugin _plugin = NtbpPlugin();
  
  Future<void> connectWithDebug(BluetoothDevice device) async {
    print('🔌 Attempting connection to ${device.name}');
    
    try {
      await _plugin.connectToDevice(device);
      print('✅ Connection successful');
      
      final status = await _plugin.getConnectionStatus();
      print('📊 Connection status: $status');
      
    } catch (e) {
      print('❌ Connection failed: $e');
      rethrow;
    }
  }
}
```

### Check Connection Details

```dart
// Get detailed connection information
Future<void> debugConnection() async {
  try {
    final details = await _plugin.getDetailedConnectionStatus();
    print('🔍 Connection Details:');
    print('  Status: ${details["status"]}');
    print('  Device: ${details["deviceName"]}');
    print('  Socket: ${details["socketConnected"]}');
    print('  Stream: ${details["outputStreamAvailable"]}');
    print('  Error: ${details["lastError"]}');
  } catch (e) {
    print('❌ Debug info failed: $e');
  }
}
```

### Monitor Printer Status

```dart
// Check printer status before operations
Future<void> checkPrinterHealth() async {
  try {
    final status = await _plugin.getPrinterStatus();
    print('📊 Printer Status: $status');
    
    // Check connection
    final connectionStatus = await _plugin.getConnectionStatus();
    print('🔌 Connection: $connectionStatus');
    
  } catch (e) {
    print('❌ Health check failed: $e');
  }
}
```

## 🆘 Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide**
2. **Verify your setup:**
   - Flutter version: `flutter --version`
   - Plugin version in `pubspec.yaml`
   - Platform-specific configuration

3. **Collect debug information:**
   - Error messages and stack traces
   - Device information (Android/iOS version)
   - Printer model and specifications

4. **Test with example app:**
   - Run the provided example app
   - Verify if issue is app-specific or plugin-wide

### Provide Information When Reporting Issues

```dart
// Include this information in bug reports
class BugReportInfo {
  static Map<String, String> collect() {
    return {
      'flutter_version': '${Flutter.version}',
      'dart_version': '${Dart.version}',
      'platform': '${Platform.operatingSystem}',
      'platform_version': '${Platform.operatingSystemVersion}',
      'plugin_version': '1.0.0',
      'device_model': '${Platform.operatingSystem == 'android' ? 'Android Device' : 'iOS Device'}',
    };
  }
}
```

### Contact Channels

1. **GitHub Issues**: [Create an issue](https://github.com/yourusername/ntbp_plugin/issues)
2. **GitHub Discussions**: [Join discussions](https://github.com/yourusername/ntbp_plugin/discussions)
3. **Documentation**: [Check docs](https://github.com/yourusername/ntbp_plugin/docs)

### Issue Template

When creating an issue, use this template:

```markdown
## Bug Report

### Environment
- Flutter version: [e.g., 3.19.0]
- Dart version: [e.g., 3.3.0]
- Platform: [Android/iOS]
- Platform version: [e.g., Android 13, iOS 16]

### Issue Description
[Describe the issue in detail]

### Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Error Messages
```
[Paste error messages here]
```

### Debug Information
[Include debug logs and connection details]

### Additional Context
[Any other relevant information]
```

## 📚 Additional Resources

- [API Reference](API_REFERENCE.md)
- [Integration Guide](INTEGRATION_GUIDE.md)
- [Development Guide](DEVELOPMENT.md)
- [Example App](example/lib/main.dart)

---

This troubleshooting guide should help you resolve most common issues with the NTBP Plugin. If you continue to experience problems, please create a detailed issue report with the information requested above. 