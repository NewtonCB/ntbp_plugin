# NTBP Plugin - Development Guide

## 🛠️ Developer Guide for Contributing and Extending

This guide is for developers who want to contribute to the NTBP Plugin, add new features, or understand the internal architecture.

## 📋 Table of Contents

1. [Project Structure](#project-structure)
2. [Architecture Overview](#architecture-overview)
3. [Adding New Features](#adding-new-features)
4. [Testing](#testing)
5. [Building and Publishing](#building-and-publishing)
6. [Code Style and Standards](#code-style-and-standards)
7. [Debugging](#debugging)
8. [Performance Optimization](#performance-optimization)

## 🏗️ Project Structure

```
ntbp_plugin/
├── lib/                                    # Dart implementation
│   ├── ntbp_plugin.dart                   # Main plugin class
│   ├── ntbp_plugin_platform_interface.dart # Abstract platform interface
│   ├── ntbp_plugin_method_channel.dart     # Method channel implementation
│   └── models/                            # Data models
│       └── bluetooth_device.dart          # Bluetooth device model
├── android/                               # Android native implementation
│   └── src/main/kotlin/
│       └── com/example/ntbp_plugin/
│           └── NtbpPlugin.kt              # Main Android plugin class
├── ios/                                   # iOS native implementation
│   └── Classes/
│       └── NtbpPlugin.swift               # Main iOS plugin class
├── example/                               # Example Flutter app
│   └── lib/
│       └── main.dart                      # Example implementation
├── test/                                  # Unit tests
│   └── ntbp_plugin_test.dart             # Plugin tests
├── docs/                                  # Documentation
├── pubspec.yaml                           # Plugin configuration
└── README.md                              # Main documentation
```

## 🏛️ Architecture Overview

### Flutter Plugin Architecture

The NTBP Plugin follows Flutter's standard plugin architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App                             │
├─────────────────────────────────────────────────────────────┤
│                 ntbp_plugin.dart                           │
│              (Public API Interface)                        │
├─────────────────────────────────────────────────────────────┤
│           ntbp_plugin_platform_interface.dart              │
│              (Abstract Platform Interface)                 │
├─────────────────────────────────────────────────────────────┤
│           ntbp_plugin_method_channel.dart                  │
│              (Flutter Method Channel)                     │
├─────────────────────────────────────────────────────────────┤
│                    Native Implementation                    │
│  ┌─────────────────┐    ┌─────────────────┐               │
│  │   Android       │    │      iOS        │               │
│  │   (Kotlin)      │    │   (Swift)       │               │
│  │                 │    │                 │               │
│  │ • Bluetooth     │    │ • CoreBluetooth │               │
│  │ • TSPL Commands │    │ • TSPL Commands │               │
│  │ • Buffer Mgmt   │    │ • Buffer Mgmt   │               │
│  └─────────────────┘    └─────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Flutter App** calls methods on `NtbpPlugin`
2. **Platform Interface** defines abstract methods
3. **Method Channel** bridges Flutter and native code
4. **Native Implementation** executes platform-specific logic
5. **Results** flow back through the same path

### Key Components

#### 1. Main Plugin Class (`ntbp_plugin.dart`)
- Public API for Flutter developers
- Static methods that delegate to platform interface
- Error handling and parameter validation

#### 2. Platform Interface (`ntbp_plugin_platform_interface.dart`)
- Abstract methods that platforms must implement
- Ensures consistent API across platforms
- Platform detection and registration

#### 3. Method Channel (`ntbp_plugin_method_channel.dart`)
- Flutter's method channel implementation
- Serializes/deserializes data between Flutter and native
- Handles method invocation and result handling

#### 4. Native Implementation
- **Android**: Kotlin implementation using Android Bluetooth APIs
- **iOS**: Swift implementation using CoreBluetooth framework

## 🚀 Adding New Features

### Step 1: Define the Feature in Platform Interface

```dart
// lib/ntbp_plugin_platform_interface.dart
abstract class NtbpPluginPlatform extends PlatformInterface {
  // ... existing methods ...
  
  /// New feature method
  Future<bool> newFeature({
    required String parameter1,
    int? parameter2,
  }) {
    throw UnimplementedError('newFeature() has not been implemented.');
  }
}
```

### Step 2: Implement in Method Channel

```dart
// lib/ntbp_plugin_method_channel.dart
@override
Future<bool> newFeature({
  required String parameter1,
  int? parameter2,
}) async {
  final result = await methodChannel.invokeMethod<bool>('newFeature', {
    'parameter1': parameter1,
    'parameter2': parameter2,
  });
  return result ?? false;
}
```

### Step 3: Implement in Native Code

#### Android (Kotlin)

```kotlin
// android/src/main/kotlin/com/example/ntbp_plugin/NtbpPlugin.kt
class NtbpPlugin: FlutterPlugin, MethodCallHandler {
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      // ... existing methods ...
      
      "newFeature" -> {
        val parameter1 = call.argument<String>("parameter1") ?: ""
        val parameter2 = call.argument<Int>("parameter2") ?: 0
        
        newFeature(parameter1, parameter2, result)
      }
      
      else -> {
        result.notImplemented()
      }
    }
  }
  
  private fun newFeature(parameter1: String, parameter2: Int, result: Result) {
    coroutineScope.launch {
      try {
        // Implementation logic here
        val success = performNewFeature(parameter1, parameter2)
        result.success(success)
      } catch (e: Exception) {
        result.error("NEW_FEATURE_ERROR", "Failed to perform new feature: ${e.message}", null)
      }
    }
  }
  
  private suspend fun performNewFeature(parameter1: String, parameter2: Int): Boolean {
    // Your implementation here
    return true
  }
}
```

#### iOS (Swift)

```swift
// ios/Classes/NtbpPlugin.swift
public class NtbpPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ntbp_plugin", binaryMessenger: registrar.messenger())
    let instance = NtbpPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    // ... existing methods ...
    
    case "newFeature":
      guard let args = call.arguments as? [String: Any],
            let parameter1 = args["parameter1"] as? String,
            let parameter2 = args["parameter2"] as? Int else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        return
      }
      
      newFeature(parameter1: parameter1, parameter2: parameter2, result: result)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func newFeature(parameter1: String, parameter2: Int, result: @escaping FlutterResult) {
    // Implementation logic here
    do {
      let success = try performNewFeature(parameter1: parameter1, parameter2: parameter2)
      result(success)
    } catch {
      result(FlutterError(code: "NEW_FEATURE_ERROR", message: "Failed to perform new feature: \(error.localizedDescription)", details: nil))
    }
  }
  
  private func performNewFeature(parameter1: String, parameter2: Int) throws -> Bool {
    // Your implementation here
    return true
  }
}
```

### Step 4: Add to Main Plugin Class

```dart
// lib/ntbp_plugin.dart
class NtbpPlugin {
  // ... existing methods ...
  
  /// New feature method
  static Future<bool> newFeature({
    required String parameter1,
    int? parameter2,
  }) {
    return NtbpPluginPlatform.instance.newFeature(
      parameter1: parameter1,
      parameter2: parameter2,
    );
  }
}
```

### Step 5: Update Tests

```dart
// test/ntbp_plugin_test.dart
class MockNtbpPluginPlatform extends Mock implements NtbpPluginPlatform {
  // ... existing mocks ...
  
  @override
  Future<bool> newFeature({
    required String parameter1,
    int? parameter2,
  }) => Future.value(true);
}

void main() {
  group('NtbpPlugin', () {
    // ... existing tests ...
    
    test('newFeature returns correct value', () async {
      final result = await NtbpPlugin.newFeature(
        parameter1: 'test',
        parameter2: 42,
      );
      expect(result, isTrue);
    });
  });
}
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/ntbp_plugin_test.dart

# Run tests in watch mode
flutter test --watch
```

### Test Structure

```dart
// test/ntbp_plugin_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';
import 'package:ntbp_plugin/ntbp_plugin_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mockito/mockito.dart';

class MockNtbpPluginPlatform extends Mock implements NtbpPluginPlatform {}

void main() {
  group('NtbpPlugin', () {
    late NtbpPlugin ntbpPlugin;
    late MockNtbpPluginPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockNtbpPluginPlatform();
      ntbpPlugin = NtbpPlugin();
      
      // Set the mock platform as the instance
      NtbpPluginPlatform.instance = mockPlatform;
    });

    group('isBluetoothAvailable', () {
      test('returns true when platform returns true', () async {
        when(mockPlatform.isBluetoothAvailable()).thenAnswer((_) async => true);
        
        final result = await ntbpPlugin.isBluetoothAvailable();
        
        expect(result, isTrue);
        verify(mockPlatform.isBluetoothAvailable()).called(1);
      });

      test('returns false when platform returns false', () async {
        when(mockPlatform.isBluetoothAvailable()).thenAnswer((_) async => false);
        
        final result = await ntbpPlugin.isBluetoothAvailable();
        
        expect(result, isFalse);
        verify(mockPlatform.isBluetoothAvailable()).called(1);
      });
    });

    // Add more test groups for other methods
  });
}
```

### Integration Testing

```dart
// test/integration/printer_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Printer Integration Tests', () {
    testWidgets('should connect to printer and print label', (tester) async {
      // Build the app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Find and tap scan button
      final scanButton = find.text('Scan for Printers');
      expect(scanButton, findsOneWidget);
      await tester.tap(scanButton);
      await tester.pumpAndSettle();

      // Wait for devices to be discovered
      await tester.pump(Duration(seconds: 15));

      // Find and tap on a device
      final deviceTile = find.byType(ListTile).first;
      await tester.tap(deviceTile);
      await tester.pumpAndSettle();

      // Verify connection
      expect(find.text('Connected'), findsOneWidget);

      // Test printing
      final printButton = find.text('Print Test Label');
      expect(printButton, findsOneWidget);
      await tester.tap(printButton);
      await tester.pumpAndSettle();

      // Verify success message
      expect(find.text('✅ Label printed successfully!'), findsOneWidget);
    });
  });
}
```

## 🏗️ Building and Publishing

### Local Development

```bash
# Install dependencies
flutter pub get

# Run example app
cd example
flutter run

# Build example app
flutter build apk --debug
```

### Plugin Development

```bash
# Analyze code
flutter analyze

# Run tests
flutter test

# Check for issues
flutter doctor
```

### Publishing to pub.dev

```bash
# Check if ready for publishing
flutter pub publish --dry-run

# Publish to pub.dev
flutter pub publish
```

## 📝 Code Style and Standards

### Dart/Flutter Standards

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use [Flutter Style Guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo)
- Run `flutter analyze` before committing

### Kotlin Standards

- Follow [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use meaningful variable names
- Add comprehensive error handling

### Swift Standards

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use descriptive method names
- Implement proper error handling

### Documentation Standards

- Document all public methods
- Use clear, concise descriptions
- Include usage examples
- Follow [Dart Documentation](https://dart.dev/guides/language/effective-dart/documentation) standards

## 🐛 Debugging

### Flutter Debugging

```dart
// Add debug prints
print('🔍 Debug: $variable');

// Use Flutter DevTools
// Run: flutter run --debug
// Open DevTools in browser
```

### Android Debugging

```kotlin
// Add Android logs
android.util.Log.d("NTBPPlugin", "Debug: $message");
android.util.Log.e("NTBPPlugin", "Error: $error");

// Check logcat
// adb logcat | grep NTBPPlugin
```

### iOS Debugging

```swift
// Add iOS logs
print("Debug: \(message)")
os_log("Error: %@", log: .default, type: .error, error.localizedDescription)

// Check Xcode console
```

### Common Debug Scenarios

#### 1. Method Channel Issues

```dart
// Check if method is registered
print('Available methods: ${methodChannel.methodCallHandler}');

// Verify argument types
print('Arguments: ${call.arguments}');
print('Argument types: ${call.arguments.runtimeType}');
```

#### 2. Bluetooth Connection Issues

```kotlin
// Check connection state
Log.d("NTBPPlugin", "Socket connected: ${socket?.isConnected}")
Log.d("NTBPPlugin", "OutputStream available: ${outputStream != null}")

// Verify device state
Log.d("NTBPPlugin", "Device bond state: ${device.bondState}")
```

#### 3. TSPL Command Issues

```kotlin
// Log TSPL commands
Log.d("NTBPPlugin", "Sending commands: $commands")

// Check command response
val response = inputStream?.read()
Log.d("NTBPPlugin", "Command response: $response")
```

## ⚡ Performance Optimization

### Connection Optimization

```kotlin
// Implement connection pooling
class ConnectionManager {
  private var connectionPool = mutableMapOf<String, BluetoothSocket>()
  
  suspend fun getConnection(device: BluetoothDevice): BluetoothSocket {
    return connectionPool.getOrPut(device.address) {
      createConnection(device)
    }
  }
}
```

### Command Batching

```kotlin
// Batch TSPL commands for better performance
private suspend fun sendBatchedCommands(commands: List<String>) {
  val batchedCommands = commands.joinToString("\n")
  sendCommands(batchedCommands.toByteArray().toList())
}
```

### Memory Management

```kotlin
// Proper resource cleanup
override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
  methodChannel.setMethodCallHandler(null)
  coroutineScope.cancel()
  disconnect()
}
```

### Async Operations

```kotlin
// Use appropriate dispatchers
coroutineScope.launch(Dispatchers.IO) {
  // Bluetooth operations
}

coroutineScope.launch(Dispatchers.Main) {
  // UI updates
}
```

## 🔧 Development Tools

### Recommended IDEs

- **Android Studio**: For Android development
- **Xcode**: For iOS development
- **VS Code**: For Flutter/Dart development

### Useful Extensions

- **Flutter**: Official Flutter extension
- **Dart**: Official Dart extension
- **Kotlin**: Kotlin language support
- **Swift**: Swift language support

### Debugging Tools

- **Flutter DevTools**: For Flutter debugging
- **Android Studio Debugger**: For Android debugging
- **Xcode Debugger**: For iOS debugging
- **adb logcat**: For Android logs

## 📚 Additional Resources

### Flutter Plugin Development

- [Flutter Plugin Development](https://flutter.dev/docs/development/packages-and-plugins/developing-packages)
- [Platform Channels](https://flutter.dev/docs/development/platform-integration/platform-channels)
- [Plugin Testing](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#testing)

### Bluetooth Development

- [Android Bluetooth](https://developer.android.com/guide/topics/connectivity/bluetooth)
- [iOS CoreBluetooth](https://developer.apple.com/documentation/corebluetooth)
- [TSPL Commands](https://www.pos-shop.ru/upload/iblock/e6d/e6dcd9090030c75de3ffd3435c1e2024.pdf)

### Testing Resources

- [Flutter Testing](https://flutter.dev/docs/testing)
- [Mockito](https://pub.dev/packages/mockito)
- [Integration Testing](https://flutter.dev/docs/testing/integration-tests)

---

This development guide provides comprehensive information for contributing to and extending the NTBP Plugin. Follow these guidelines to ensure code quality, maintainability, and consistency across the project. 