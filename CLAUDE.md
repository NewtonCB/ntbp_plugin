# NTBP Plugin — Working Knowledge

Flutter plugin for thermal Bluetooth **label** printing. Talks TSPL (Thermal Script
Programming Language) to printers such as the Xprinter XP-420B and the N41. Version 3.0.0.
Package name `ntbp_plugin`, Android package `com.example.ntbp_plugin`.

## v3 architecture (current, since 2026-10-26)

**One layout engine in Dart, thin native transports.**
- `lib/src/tspl/tspl_builder.dart` — `TsplBuilder` (chainable TSPL command writer, escaping) and
  `TsplFont` (built-in bitmap fonts "1".."8" with glyph metrics, `fit()` picks the largest font that
  fits a width, `clip()` truncates).
- `lib/src/tspl/label_print_config.dart` — `LabelPrintConfig` (widthMm/heightMm/dpi/gapMm/blackMark/
  direction/density/speed/copies). `writeHeader()` emits SIZE, GAP|BLINE, DIRECTION, REFERENCE, CLS.
- `lib/src/tspl/cargo_label.dart` — `CargoLabel` model + `CargoLabelLayout.buildJob()`: the XP-420B
  cargo shipment label (sample photo at `asset/sample_label.jpeg`). Geometry on an 800x1200 reference
  grid (100x150 mm @203 dpi) scaled to the config; fonts chosen per field by fit.
- `lib/src/tspl/three_line_label.dart` — `ThreeLineQrLabel` + `ThreeLineQrLayout`: faithful port of the
  v2 Kotlin QR + 3 text lines geometry, so the legacy static methods work identically on both platforms.
- `lib/models/printer_status.dart` — `PrinterStatus` (decodes the `ESC ! ?` status byte; -1 no
  response, -2 not connected) and `PrintBatchResult`.
- `lib/ntbp_plugin.dart` — public API. New statics: `printCargoLabel`, `printCargoLabels`,
  `previewCargoLabel`, `sendTspl`, `sendBytes`, `calibrateGap`, `autoCalibrate`, `calibrateBlackMark`,
  `formFeed`, `queryPrinterStatus`, `waitUntilIdle`. Legacy `printSingleLabelWithGapDetection` /
  `printMultipleLabelsWithGapDetection` now build TSPL in Dart and send via `sendProtocolCommands`.
- Series printing (`_printSeries`): one job per label, then poll status until not printing; stops at
  first error (head open / jam / out of paper); if the printer never answers status, falls back to a
  timed delay. No FORMFEED between labels, no HOME, no CLEAR, no per-print calibration.
- Native channel methods actually used now: scan/connect/disconnect/isConnected/status maps,
  `sendProtocolCommands` (raw bytes), `queryPrinterStatus(timeoutMs)` → int, plus simple legacy
  printText/printBarcode/printQRCode/print/clearBuffer/feedPaper which build tiny TSPL natively.
- Android native: `POSConnect.init` in onAttachedToEngine, `IDeviceConnection` (SPP by MAC) with
  `IConnectListener`, `sendData` on a single-thread executor, `TSPLPrinter(conn).printerStatus(timeout)`.
  Discovery still uses `BluetoothAdapter` (bonded + discovery, BLE-only devices skipped). The aar is
  served from a local Maven repo at `android/libs/repo/net/posprinter/printer-lib/3.5.8/` (aar + pom),
  `implementation "net.posprinter:printer-lib:3.5.8"`, and `build.gradle` registers that repo on
  `rootProject.allprojects` so the host app can resolve it. **Do not use `implementation files(x.aar)`
  in the plugin: AGP refuses direct local aar deps in library modules.** minSdk 21.
- iOS native: `ios/Classes/ntbp_plugin.h` umbrella header is REQUIRED (Swift's generated
  `ntbp_plugin-Swift.h` imports `<ntbp_plugin/ntbp_plugin.h>` because the plugin class adopts the ObjC
  `XBLEManagerDelegate`); it is listed first in `public_header_files`. After podspec changes run
  `pod install` in `example/ios` explicitly, `flutter build` may reuse the old install.
  `XBLEManager.sharedInstance()` as transport, delegate for discover/connect/disconnect,
  `writeCommand(with:writeCallBack:)`, `printerLabelStatus` for status. Headers in
  `ios/Classes/PrinterSDK/*.h` (public headers → umbrella → visible to Swift), static lib in
  `ios/Libraries/libPrinterSDK.a` (`vendored_libraries`, `-ObjC`, `libz`, CoreBluetooth +
  ExternalAccessory + CFNetwork). Simulator: x86_64 only (arm64 excluded) → Rosetta on Apple silicon.
- Example app: `_buildCargoSection` in `example/lib/main.dart` has Print Sample / Print 3 Labels /
  Calibrate Gap / Printer Status buttons with width/height/gap fields.
- Verified 2026-10-26: `flutter test` (19 pass), `flutter build ios --no-codesign --debug` and
  `flutter build apk --debug` of the example both succeed. User's test iPhone: "Kim_Phone"
  (id 00008110-00092DC93C12401E), Runner signed with team D2TB893886.
- Tests: `test/cargo_label_layout_test.dart` (layout bounds, escaping, font fit, three-line geometry,
  status decode). Run `flutter test`.

**The sections below describe the v2 layout math for reference; the Kotlin/Swift copies are gone.**

## Layer map

| Layer | File(s) | Role |
|---|---|---|
| Public Dart API | `lib/ntbp_plugin.dart` | `NtbpPlugin` class. Mix of **static** methods (gap-detection label printing, protocol system) and **instance** methods (Bluetooth, legacy prints). |
| Platform interface | `lib/ntbp_plugin_platform_interface.dart` | Abstract contract, default impl is the method channel. |
| Method channel | `lib/ntbp_plugin_method_channel.dart` | Serializes every call to a `Map` and invokes on channel `ntbp_plugin`. |
| Models | `lib/models/bluetooth_device.dart`, `lib/models/print_command.dart` | `BluetoothDevice` (name, address, isConnected, rssi, deviceClass). `PrintCommand` legacy command object with text/barcode/QR/image/block factories. |
| Dart protocol system | `lib/src/protocols/` | `PrinterProtocol` interface, `TSPLProtocol`, `ESCPOSProtocol` (also emits TSPL), `PrinterFactory` (substring match on device name), `ProtocolManager` singleton. Builds TSPL bytes in Dart and sends via `sendProtocolCommands`. |
| Android native | `android/src/main/kotlin/com/example/ntbp_plugin/NtbpPlugin.kt` (~1100 lines) | **The real implementation.** Classic Bluetooth SPP + TSPL generation. |
| iOS native | `ios/Classes/NtbpPlugin.swift` (~1080 lines) | CoreBluetooth BLE + TSPL generation. Lags behind Android (see Gotchas). |
| Example app | `example/lib/main.dart`, `example/lib/protocol_example.dart` | Reference UI. |
| Docs | `doc/*.md`, `README.md`, `CHANGELOG.md` | `doc/LABEL_PRINTING_FLOW.md` describes the TSPL sequence. |

## Bluetooth transport

**Android (SPP, Classic BT)**
- `startScan`: clears cache, adds all bonded devices, starts discovery, waits a fixed 12 s, returns device count. `DiscoveryReceiver` collects `ACTION_FOUND` into a `ConcurrentHashMap<address, BluetoothDevice>`.
- `connectToDevice`: `createRfcommSocketToServiceRecord(00001101-0000-1000-8000-00805F9B34FB)`, keeps `bluetoothSocket` + `outputStream`.
- `isConnected()` = socket connected AND outputStream non-null.
- `sendCommands(List<Byte>)` = `outputStream.write` + `flush` on `Dispatchers.IO`. No read-back from printer.
- All handlers run inside `coroutineScope.launch` (IO + SupervisorJob).

**iOS (BLE, CoreBluetooth)**
- Scans peripherals, connects, discovers services and a writable characteristic, writes with `.withResponse`. Also sleep-based, no status read-back.

## Core printing path (v2.0.0 feature)

Primary API: `NtbpPlugin.printSingleLabelWithGapDetection(...)` and
`NtbpPlugin.printMultipleLabelsWithGapDetection(...)` (both static).

Args: `qrData`, `textData1` (customer), `textData2` (drop point), `textData3` (extra),
`width`, `height`, `unit` (default mm), `dpi` (default 203), `copies`, `textSize` (default 9).
Batch variant takes `labelDataList: List<Map>` with the same per-label keys and `copiesPerLabel`.

**Android sequence (per print):**
1. `sendGapDetectionCommands` → `CLEAR`, `SIZE w dot,h dot`, `GAP g dot,0`, `GAPDETECT ON`, `AUTODETECT ON`, `CLS`.
   Gap g = 2 mm (height ≤ 20), 2.5 mm (≤ 40), else 3 mm. Sleep 300 ms.
2. `clearBufferAggressively` → `CLEAR` / `CLS` / `HOME` with 150–200 ms sleeps. (Batch uses `clearBufferCompletely`, which also sends `DIRECTION 0`, `REFERENCE 0,0`.)
3. Layout math (all in dots, `convertToDots` = value × dpi / 25.4 for mm):
   - margin = 2 mm (width ≤ 30), 3 mm (≤ 60), else 4 mm
   - available = label − 2×margin
   - qrSize = availableWidth × 0.55 / 0.60 / 0.65 by width band, capped at availableHeight × 0.45 and availableWidth × 0.65
   - qrX = margin + (availableWidth − qrSize)/2 (centered); qrY = margin + availableHeight × 0.08
   - textX = qrX (text left-aligned with QR)
   - textY1 = qrY + qrSize + 8 mm; textY2 = textY1 + 4 mm; textY3 = textY2 + 4 mm
   - clamped so textY3 ≤ height − margin − 2 mm
4. Emit:
   ```
   REFERENCE 0,0
   DIRECTION 0
   QRCODE qrX,qrY,H,10,A,0,"qrData"
   TEXT textX,textY1,"9",0,1,1,"textData1"   (only if non-empty)
   TEXT textX,textY2,"9",0,1,1,"textData2"
   TEXT textX,textY3,"9",0,1,1,"textData3"
   PRINT copies
   ```
   TEXT font param is the `textSize` string; rotation 0; x/y multiplier 1,1.
5. Sleep 500 ms × copies, then `result.success(true)`.
6. Batch: per label → clear buffer, `calculateLabelPositions`, same commands (plus a `CLS`), `FORMFEED` between labels, `CUT` at end. Returns true only if every label succeeded.

Layout is **hard-coded**: QR on top, up to three text lines below. No generic layout engine.

## Android method-channel coverage

Implemented in Kotlin: `getPlatformVersion`, `printSingleLabelWithGapDetection`,
`printMultipleLabelsWithGapDetection`, `sendProtocolCommands`, `initializeProtocolPrinter`,
`printWithProtocol`, `print`, `printText`, `printBarcode`, `printQRCode`, `clearBuffer`,
`getPrinterStatus`, `feedPaper`, `connectToDevice`, `disconnect`, `isConnected`,
`getConnectionStatus`, `getDetailedConnectionStatus`, `startScan`, `stopScan`, `getDiscoveredDevices`.

**Falls through to `notImplemented` on Android** even though Dart exposes them:
`isBluetoothAvailable`, `requestBluetoothPermissions`, all pairing/PIN methods,
`printTextAdvanced`, `printBarcodeAdvanced`, `printQRCodeAdvanced`, `printImage`, `printBlock`,
`setPrintArea`, `clearPrintBuffer`, `executePrint`, `printBarcodeWithText`,
`printProfessionalLabel`, `printLabelSequence`, `getLabelPaperConfig`, `printCustomLabel`,
`printSmartLabel`, `printSmartSequence`.

Legacy `print`/`printText`/`printBarcode`/`printQRCode` on Android cast `call.arguments`
directly to a List/String, but Dart sends a Map, so they will throw a ClassCastException.

## Gotchas / known drift

- **iOS does not support three text lines.** Swift reads `textData` (single), Dart sends
  `textData1/2/3`, so iOS prints the fallback "Sample Text". Same for the batch path.
  Any new feature must be added to both Kotlin and Swift if iOS parity is required.
- **Three divergent copies of layout math**: Kotlin (`calculateLabelPositions` and inline in
  `printSingleLabelWithGapDetection`), Swift (`calculatePositions`), Dart (`TSPLProtocol.calculatePositions`).
  QR fractions and Y offsets differ between them. Kotlin is the source of truth for v2.0.0 behaviour.
- **No TSPL escaping.** A `"` inside text data breaks the `TEXT`/`QRCODE` command.
- **Timing is sleep-based.** Completion is assumed after fixed delays; nothing reads printer status.
- Android `printSingleLabelWithGapDetection` uses `Thread.sleep` inside a coroutine; batch uses `delay`.
- `buildSingleLabelCommands` in Kotlin is dead code (two-line variant, unused).
- `ESCPOSProtocol` is named ESC/POS but intentionally emits TSPL ("TSPL forced").
- `PrinterFactory.autoDetectProtocol` defaults to TSPL when nothing matches.
- `BluetoothDevice` equality is by `address` only.

## Conventions

- Dimensions are passed in `unit` (mm/inch/dot) and converted to dots natively.
- Error codes are UPPER_SNAKE strings: `NOT_CONNECTED`, `ENHANCED_LABEL_ERROR`,
  `MULTIPLE_LABELS_ERROR`, `EMPTY_LABEL_LIST`, `CONNECTION_ERROR`, `DEVICE_NOT_FOUND`, etc.
- Android logs under tag `NTBPPlugin`.
- Tests: `test/ntbp_plugin_test.dart`, `test/ntbp_plugin_method_channel_test.dart`,
  `example/integration_test/plugin_integration_test.dart`.
- Branch naming seen: `feat/XP-420B`. Main branch: `main`.

## Adding a new feature — checklist

1. Add method to `NtbpPluginPlatform` (interface) and `MethodChannelNtbpPlugin` (serialize to Map).
2. Expose it on `NtbpPlugin` (match static vs instance style of its neighbours).
3. Add a `when` branch in Kotlin `onMethodCall`, parse args with `as? Number`/`as? String` + defaults, implement inside `coroutineScope.launch`, guard with `isConnected()`.
4. Mirror in Swift `handle(_:result:)` if iOS parity is needed.
5. Update `README.md`, `doc/API_REFERENCE.md`, `CHANGELOG.md`, bump `pubspec.yaml` version.
6. Update the mock in `test/ntbp_plugin_test.dart`.

## XP-420B migration (branch `feat/XP-420B`, started 2026-10-26)

Target printer: **Xprinter XP-420B**, 4-inch (max 108 mm print width) desktop thermal label
printer, 203 dpi, TSPL language, Bluetooth. Same TSPL dialect as the N41 so the layout
logic carries over; the transport and command building move to the vendor SDK.

**Vendor SDK dropped in `sdks/`:**
- `sdks/ios/PrinterDemo/PrinterDemo/PrinterSDK/` — Xprinter `libPrinterSDK.a` (fat: arm64 + x86_64)
  with headers `XSDKPrinter.h` (umbrella), `XBLEManager.h`, `XTSPLCommand.h`, `XConstants.h`,
  plus WIFI/MFi/ZPL/CPCL/POS. Objective-C, needs a bridging header (`#import "XSDKPrinter.h"`).
- `sdks/ios/*.pdf` — vendor manuals (TSPL, BLE, MFi, etc.).
- `sdks/android/printer-lib-3.5.8.aar` — Xprinter Android SDK (package `net.posprinter`), minSdk 21,
  bundles `libprinter_serial_port.so` for arm64-v8a/armeabi-v7a/x86/x86_64. No external deps beyond Android.
  Demo app in `sdks/android/PrinterDemo/` (Kotlin), manuals as PDFs alongside.

**SDK API worth knowing (Android, `net.posprinter`):**
- `POSConnect.init(context)` once. `POSConnect.createDevice(POSConnect.DEVICE_TYPE_BLUETOOTH)` →
  `IDeviceConnection`; `conn.connect(macAddress, IConnectListener { code, info, msg -> })` with codes
  `CONNECT_SUCCESS`, `CONNECT_FAIL`, `CONNECT_INTERRUPT`, `SEND_FAIL`. `conn.isConnect()`, `conn.close()`,
  `conn.sendData(bytes)`, `conn.readData(cb)`, `conn.startReadLoop(cb)`.
- Discovery is NOT in the SDK: demo uses the plain `BluetoothAdapter` (bonded + `startDiscovery`),
  skips BLE-only devices (`type == 2`). The SDK connects over classic SPP by MAC.
- `TSPLPrinter(conn)` fluent builder: `sizeMm`, `gapMm(m,n)`, `blineMm`, `speed`, `density(0-15)`,
  `direction(TSPLConst.DIRECTION_FORWARD)`, `reference(x,y)`, `offsetMm`, `cls`,
  `text(x,y,font,rotation,xMul,yMul,content)`, `qrcode(x,y,ecLevel,cellWidth,mode,rotation,content)`,
  `barcode(x,y,type,height,readable,rotation,narrow,wide,content)`, `bar`, `box`, `bitmap`, `erase`,
  `reverse`, `feed`, `backFeed`, `formFeed`, `home`, `cut`, `setCutter`, `setPeel`, `setTear`,
  `print()`/`print(n)`, `printWithResponse(m,n,IStatusCallback)`, `listenPrinterResult`,
  `printerStatus(timeoutMs, IStatusCallback)` (same status byte map as iOS), `getSerialNumber`,
  `getFirmwareVersion`, `getPrinterModel`, `getPaperType`, `sendData(bytes)` for raw TSPL.
  No `gapDetect`/`autoDetect` helper on Android — send raw `GAPDETECT\r\n` / `AUTODETECT\r\n` via `sendData`.
- `TSPLConst`: `FNT_8_12="1"`, `FNT_12_20="2"`, `FNT_16_24="3"`, `FNT_24_32="4"`, `FNT_32_48="5"`,
  `FNT_14_19="6"`, `FNT_21_27="7"`, `FNT_14_25="8"`; `EC_LEVEL_L/M/Q/H`; `QRCODE_MODE_AUTO="A"`;
  `ROTATION_0/90/180/270`; `READABLE_NONE/LEFT/CENTER/RIGHT`; `BMP_MODE_OVERWRITE`.
- Plugin's `android/build.gradle` currently has `minSdk = 19`; the aar needs **21**. Bump it.
  Integration: copy aar to `android/libs/` and add `implementation files("libs/printer-lib-3.5.8.aar")`.

**SDK API worth knowing (iOS):**
- `XBLEManager.sharedInstance()`: `startScan`, `stopScan`, `connectDevice(peripheral)`,
  `disconnectRootPeripheral`, `isConnected`, `writeCommandWithData(_:writeCallBack:)`,
  `printerLabelStatus(block)` → 1–2 byte status (0x00 ready, 0x01 cover, 0x02 jam, 0x04 paper end,
  0x08 no ribbon, 0x10 pause, 0x20 printing). Delegate: `xbleDiscoverPeripheral`, `xbleConnectPeripheral`,
  `xbleFailToConnectPeripheral`, `xbleDisconnectPeripheral`, `xbleReceiveValueForCharacteristic`.
- `XTSPLCommand` fluent builder: `sizeMm`, `gapMm(m,n)`, `cls`, `direction`, `referenceAtX:y:`,
  `textAtX:y:font:rotation:xRatio:yRatio:content:`, `textBlockAtX:...` (word-wrapped paragraph),
  `qrCodeAtX:andY:ecLevel:cellWidth:mode:rotation:content:`, `barcodeAtX:...`, `barAtX:...`,
  `boxAtX:...`, `bitmapAtX:y:mode:image:`, `print:n:`, `formFeed`, `home`, `gapDetect`,
  `autoDetect`, `cut`, `setCutter`, `autoResponse`, `getCommand` → NSData.
- Fonts: `kFNT_8_12`, `kFNT_12_20`, `kFNT_16_24`, `kFNT_24_32`, `kFNT_32_48`, OCR variants.
  QR EC levels `kECLevelL/M/Q/H`, mode `kQRCodeModeAuto`.
