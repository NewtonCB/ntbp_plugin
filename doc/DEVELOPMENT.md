# Development Guide (3.x)

For contributors to the plugin itself.

## 1. Project structure

```
lib/
  ntbp_plugin.dart                  public API (NtbpPlugin)
  ntbp_plugin_platform_interface.dart
  ntbp_plugin_method_channel.dart   channel 'ntbp_plugin'
  models/                           BluetoothDevice, PrintCommand, PrinterStatus
  src/tspl/
    tspl_builder.dart               TsplBuilder, TsplFont
    label_print_config.dart         LabelPrintConfig (media)
    cargo_label.dart                CargoLabel, CargoLabelLayout
    logo_bitmap.dart                CargoLogo, MonoBitmap
    three_line_label.dart           legacy 2.x layout
  src/protocols/                    legacy Dart "protocol" layer (kept for compatibility)
android/
  src/main/kotlin/.../NtbpPlugin.kt transport over Xprinter printer-lib (SPP), permissions
  libs/repo/net/posprinter/...      the vendor aar as a local Maven repository
ios/
  Classes/NtbpPlugin.swift          transport over Xprinter PrinterSDK (BLE)
  Classes/ntbp_plugin.h             umbrella header (required, see below)
  Classes/PrinterSDK/*.h            vendor headers
  Libraries/libPrinterSDK.a         vendor static library (arm64 device + x86_64 simulator)
example/                            reference app (see UI_IMPLEMENTATION_GUIDE.md)
test/                               Dart unit tests
sdks/                               vendor demos and manuals (git only, not published)
doc/                                this documentation
```

## 2. Architecture

One rule: **layout in Dart, transport in native.**

- Dart builds the complete TSPL job (text plus binary bitmap data) and sends it as a
  `Uint8List` through `sendProtocolCommands`.
- The native side only connects, writes bytes and answers the status query. It never
  changes the bytes. This is what guarantees identical output on both platforms.
- The two other native responsibilities are device discovery and, on Android, runtime
  permissions.

Channel methods actually used by 3.x:

| Method | Purpose |
|---|---|
| `hasBluetoothPermissions`, `requestBluetoothPermissions` | permissions |
| `isBluetoothAvailable` | adapter state |
| `startScan`, `stopScan`, `getDiscoveredDevices` | discovery |
| `connectToDevice`, `disconnect`, `isConnected`, `getConnectionStatus`, `getDetailedConnectionStatus` | connection |
| `sendProtocolCommands` | raw bytes (typed data) |
| `queryPrinterStatus` | `ESC ! ?` → int |
| `printText`, `printBarcode`, `printQRCode`, `print`, `clearBuffer`, `feedPaper` | small legacy helpers built natively |

## 3. Setting up

```bash
flutter --version       # 3.19+; developed on 3.44
cd ntbp_plugin
flutter pub get
flutter test
cd example && flutter pub get
```

Android needs JDK 17 and the Android SDK with API 35. iOS needs Xcode 15+ and CocoaPods.

## 4. Building

```bash
cd example
flutter build apk --debug                 # Android
flutter build ios --no-codesign --debug   # iOS (device build)
```

Run the example on a real device with `flutter run -d <device id>` from `example/`.

### Things that bite

- **Android aar.** AGP refuses `implementation files('x.aar')` inside a library module.
  The aar lives in `android/libs/repo` as a Maven repository and `android/build.gradle`
  registers that repository on `rootProject.allprojects` so the host app can resolve the
  transitive dependency. Keep it that way.
- **iOS umbrella header.** The Swift class adopts the Objective-C `XBLEManagerDelegate`, so
  the generated `ntbp_plugin-Swift.h` imports `<ntbp_plugin/ntbp_plugin.h>`. That file must
  exist in `Classes/` and be listed first in `public_header_files`.
- **Podspec changes** are not always picked up by `flutter build`; run `pod install` in
  `example/ios` after editing the podspec.
- **Simulator.** The vendor library has no arm64 simulator slice. `EXCLUDED_ARCHS` for the
  simulator is set in the podspec; use a device.
- **Typed data on the channel.** A `Uint8List` arrives natively as
  `FlutterStandardTypedData` / `ByteArray`, not as a list. Both natives accept both forms
  and reject empty payloads; keep that when touching `sendProtocolCommands`.
- **`.pubignore` replaces `.gitignore`** for pub. Every build directory ignored in
  `.gitignore` must be repeated in `.pubignore`, otherwise `build/` ends up in the package.

## 5. Tests

```bash
flutter test                                   # all
flutter test test/cargo_label_layout_test.dart # layout only
```

`cargo_label_layout_test.dart` checks: job framing (SIZE/GAP/CLS/PRINT, no CLEAR/HOME/
FORMFEED), every field present, escaping, bounds (nothing drawn outside the label), font
fit and wrapping, QR payload, logo placement and bitmap packing, map round trip, the legacy
three-line geometry and status decoding. `ntbp_plugin_method_channel_test.dart` asserts that
bytes cross the channel as typed data.

When you change the layout, print the job and compare it by eye:

```dart
print(NtbpPlugin.previewCargoLabel(sample, config: const LabelPrintConfig()));
```

Then print on the XP-420B; the reference mock-up is `asset/sample_label.jpeg` in the
repository.

## 6. Adding a feature

1. **Layout or model change**: edit `lib/src/tspl/`, add a test, run `flutter test`.
   No native change needed.
2. **New native capability** (rare):
   - add the method to `NtbpPluginPlatform` and `MethodChannelNtbpPlugin`,
   - expose it on `NtbpPlugin`,
   - implement in `NtbpPlugin.kt` (`when (call.method)`) and `NtbpPlugin.swift`
     (`switch call.method`), always resolving the result exactly once and on the main thread,
   - add it to the mock in `test/ntbp_plugin_test.dart`,
   - document it in `doc/API_REFERENCE.md`.
3. Update `CHANGELOG.md` and, for behaviour changes, `README.md`.

Error codes are `UPPER_SNAKE` strings in `FlutterError` / `result.error`; reuse the existing
ones listed in `TROUBLESHOOTING.md`.

## 7. Code style

- `flutter analyze` must be clean for `lib/` and `test/` (the legacy `src/protocols` prints
  are tolerated).
- Dart: 2-space indent, trailing commas, `const` where possible.
- Kotlin: no coroutines needed; use the single-thread executor and `mainHandler.post` for
  results. Swift: results on the main queue, guard against double replies.
- Keep native code free of layout decisions.

## 8. Publishing

```bash
flutter pub publish --dry-run   # expect 0 warnings and an archive of about 1 MB
flutter pub publish
```

Checklist in `RELEASE_PREPARATION.md`.
