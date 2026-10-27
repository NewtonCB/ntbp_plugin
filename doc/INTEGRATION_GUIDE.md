# Integrating `ntbp_plugin` into a Flutter app

This guide takes you from an empty Flutter project to printing cargo shipment labels on an
Xprinter XP-420B (or any TSPL label printer) over Bluetooth, on Android and iOS.

Version covered: **3.0.0**.

---

## 1. What the plugin does

- Renders the cargo label layout (logo, brand, booking and item references, QR code, sender,
  receiver, destination, weight, package, source, date, cargo name) to TSPL **in Dart**, so
  Android and iOS print identical labels.
- Talks to the printer through the Xprinter vendor SDKs bundled inside the plugin:
  classic Bluetooth (SPP) on Android, Bluetooth LE on iOS. You add nothing to your app for this.
- Queries the printer status (ready, out of paper, head open, jam, paused, printing).
- Prints a series of labels with feedback and stops at the first printer error.
- Lets you calibrate the gap sensor once per roll.

---

## 2. Installation

### 2.1 pubspec.yaml

```yaml
dependencies:
  ntbp_plugin: ^3.0.0
```

```bash
flutter pub get
```

### 2.2 Android

Requirements:

| Setting | Value |
|---|---|
| `minSdkVersion` | 21 or higher |
| `compileSdkVersion` | 31 or higher (35 recommended) |

Set them in `android/app/build.gradle` (or `.gradle.kts`):

```kotlin
android {
    compileSdk = 35
    defaultConfig {
        minSdk = 21
    }
}
```

The plugin's own manifest declares every Bluetooth permission (`BLUETOOTH`, `BLUETOOTH_ADMIN`,
`BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN` with `neverForLocation`, and location for Android 11 and
below), and Gradle merges them into your app. **You do not add permissions to your manifest.**

The plugin also requests the runtime permissions itself (see section 4). No extra permission
package is needed on Android.

The vendor SDK (`printer-lib-3.5.8.aar`) ships inside the plugin as a local Maven repository
and is resolved automatically.

### 2.3 iOS

Requirements: iOS 12.0 or higher, a **real device** for testing (the vendor library has no
Apple-silicon simulator slice).

Add the Bluetooth usage description to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to connect to the label printer.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Used to connect to the label printer.</string>
```

iOS shows the Bluetooth permission prompt automatically the first time the app uses Bluetooth.

If your app also uses `permission_handler` to read the Bluetooth permission state on iOS, add
the macro below to the `post_install` block of `ios/Podfile`, otherwise `Permission.bluetooth`
always reports "denied":

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_BLUETOOTH=1',
      ]
    end
  end
end
```

Then run `pod install` in `ios/`.

### 2.4 Printer setup

- Load a roll of 100 x 150 mm (4" x 6") die-cut labels. The layout is designed for that size
  and scales to other sizes.
- On **Android**, pair the printer in the phone's Bluetooth settings (or let discovery find it).
- On **iOS**, no pairing is needed; the printer appears in the scan as a BLE device.

---

## 3. Import and create the plugin

```dart
import 'package:ntbp_plugin/ntbp_plugin.dart';

final plugin = NtbpPlugin();
```

Connection methods are **instance** methods. Printing, status and calibration are **static**
methods on `NtbpPlugin`.

---

## 4. Permissions

Ask for Bluetooth permissions before scanning or connecting:

```dart
final granted = await plugin.requestBluetoothPermissions();
if (!granted) {
  // Show a message; on Android the user may have chosen "Don't ask again",
  // in which case they must enable it in the app's Settings page.
  return;
}
```

On Android this shows the system dialog for what the running OS version needs
(`BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` on Android 12+, fine location on older versions).
On iOS it returns the current authorization state.

`plugin.hasBluetoothPermissions()` checks without prompting.

---

## 5. Find and connect to the printer

```dart
// Starts a scan window (about 10-12 seconds) and completes when it ends.
await plugin.startScan();

final devices = await plugin.getDiscoveredDevices();
final printer = devices.firstWhere(
  (d) => d.name.toUpperCase().contains('XP'),
  orElse: () => devices.first,
);

final connected = await plugin.connectToDevice(printer);
```

You can call `getDiscoveredDevices()` repeatedly while the scan is running to show devices as
they appear. `BluetoothDevice.address` is the MAC address on Android and the peripheral
identifier on iOS; both are stable, so you can store it and reconnect later by scanning and
matching the address.

Other connection calls: `plugin.isConnected()`, `plugin.disconnect()`,
`plugin.getDetailedConnectionStatus()`.

Errors are thrown as `PlatformException` with these codes:

| Code | Meaning |
|---|---|
| `PERMISSION_DENIED` | A Bluetooth permission is missing; call `requestBluetoothPermissions()` |
| `BLUETOOTH_NOT_AVAILABLE` | Bluetooth is off or unsupported |
| `DEVICE_NOT_FOUND` | The address was not seen in the last scan |
| `CONNECTION_ERROR`, `CONNECTION_TIMEOUT` | The printer refused or did not answer |
| `NOT_CONNECTED` | A print or status call was made without a connection |

---

## 6. Calibrate once per roll

The printer measures the label length and gap by feeding two or three labels:

```dart
await NtbpPlugin.calibrateGap();      // gap (die-cut) media
// or
await NtbpPlugin.calibrateBlackMark(); // black-mark media
await NtbpPlugin.autoCalibrate();      // let the printer decide
```

Do this after loading a new roll, not before every print.

---

## 7. Print a cargo label

### 7.1 Load the logo once

Add your logo to the app's assets (`pubspec.yaml` → `flutter: assets:`), then:

```dart
final data = await rootBundle.load('assets/logo.png');
final logo = CargoLogo.fromBytes(data.buffer.asUint8List());
```

`CargoLogo` accepts PNG, JPEG, GIF, BMP and WebP. Colour artwork is reduced to black with a
luminance threshold (`threshold`, default 170). Use `dither: true` for photos. Keep one
instance and reuse it for every label; decoding happens once.

### 7.2 Describe the label

```dart
final label = CargoLabel(
  brandName: 'BM Coach',
  bookingReference: 'BK-1025',
  item: CargoLabel.generateReference('BK-1025', 1), // "BK1025-001"
  cargoName: 'Spare parts (engine)',
  sender: ['Otapp Agency Limited', 'Tel: +255 712 345 678'],
  receiver: ['John Mwakyusa', 'Tel: +255 765 432 109'],
  source: 'MWANZA',
  destination: 'DAR ES SALAAM',
  weight: '5.0 KG',
  package: '1 / 5',
  date: '2025-10-19',
);
```

Field notes:

- `sender` and `receiver` take `[name, phone]`. Only the first two entries print.
- `cargoName` prints large in the box at the bottom and wraps to several lines when long.
- The QR code encodes a readable summary of all fields by default, so any phone camera shows
  the shipment details when it is scanned. Use `qrContent: CargoQrContent.itemReference` to
  encode only the item reference, or `CargoQrContent.custom` with `qrData` for a URL or any text.
- Every caption (`BOOKING REFERENCE`, `SENDER`, ...) can be overridden with the `*Caption`
  parameters, for example `senderCaption: 'MTUMAJI'`.
- `toMap()` / `CargoLabel.fromMap()` convert to and from JSON for storage or a backend.

### 7.3 Media settings

```dart
const config = LabelPrintConfig(
  widthMm: 100,
  heightMm: 150,
  gapMm: 3,        // physical gap between labels
  density: 10,     // darkness 0..15
  copies: 1,
  // blackMark: true,   for black-mark media
  // direction: 1,      if labels come out upside down
);
```

### 7.4 Print

```dart
final ok = await NtbpPlugin.printCargoLabel(label, config: config, logo: logo);
```

`ok` is true when the job was written to the printer. To know whether the printer actually
finished, query the status (section 9).

---

## 8. Print a series of labels

```dart
final labels = List.generate(5, (i) => label.copyWith(
  item: CargoLabel.generateReference('BK-1025', i + 1),
  package: '${i + 1} / 5',
));

final result = await NtbpPlugin.printCargoLabels(labels, config: config, logo: logo);

if (result.success) {
  print('Printed ${result.printed} labels');
} else {
  print('Printed ${result.printed} of ${result.total}; failed: ${result.failedIndexes}');
  if (result.stoppedBy != null) print(result.stoppedBy!.description); // e.g. "Out of paper"
}
```

Each label is sent as its own job. Between jobs the plugin polls the printer status and stops
at the first error, so a paper-out in the middle of a batch does not leave jobs buffered that
print when the roll is replaced. Pass `waitForPrinter: false` to fire everything without
checking.

---

## 9. Printer status

```dart
final status = await NtbpPlugin.queryPrinterStatus();
print(status.description); // "Ready", "Out of paper", "Head opened", "Printing", ...

if (status.isReady) { ... }
if (status.hasError) { ... }   // head open, jam, out of paper, out of ribbon
if (!status.responded) { ... } // printer did not answer (code -1) or not connected (-2)
```

`NtbpPlugin.waitUntilIdle()` polls until the printer stops reporting "printing".

---

## 10. Preview without a printer

```dart
final tspl = NtbpPlugin.previewCargoLabel(label, config: config, logo: logo);
print(tspl);
```

Returns the TSPL script with the binary logo data replaced by a placeholder. Useful in unit
tests and for support tickets.

---

## 11. Custom TSPL

For layouts of your own, build the script with `TsplBuilder` and send it:

```dart
final job = TsplBuilder()
  ..sizeMm(100, 150)
  ..gapMm(3)
  ..cls()
  ..text(40, 40, TsplFont.f24x32, 'Hello')
  ..qrCode(40, 100, 'https://example.com', cellWidth: 6)
  ..box(20, 20, 780, 1180, thickness: 3)
  ..print(copies: 2);

await NtbpPlugin.sendTspl(job.build());
```

`TsplFont` lists the printer's built-in fonts with their glyph sizes and has `fit()` to pick
the largest font that fits a width. Coordinates are in dots (203 per inch, 8 per mm).

---

## 12. Complete minimal example

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

class PrintPage extends StatefulWidget {
  const PrintPage({super.key});
  @override
  State<PrintPage> createState() => _PrintPageState();
}

class _PrintPageState extends State<PrintPage> {
  final plugin = NtbpPlugin();
  CargoLogo? logo;
  BluetoothDevice? printer;
  String message = '';

  @override
  void initState() {
    super.initState();
    rootBundle.load('assets/logo.png').then((d) {
      logo = CargoLogo.fromBytes(d.buffer.asUint8List());
    });
  }

  Future<void> connect() async {
    if (!await plugin.requestBluetoothPermissions()) {
      setState(() => message = 'Bluetooth permission needed');
      return;
    }
    await plugin.startScan();
    final devices = await plugin.getDiscoveredDevices();
    if (devices.isEmpty) {
      setState(() => message = 'No printer found');
      return;
    }
    final target = devices.firstWhere(
      (d) => d.name.toUpperCase().contains('XP'),
      orElse: () => devices.first,
    );
    final ok = await plugin.connectToDevice(target);
    setState(() {
      printer = ok ? target : null;
      message = ok ? 'Connected to ${target.name}' : 'Connection failed';
    });
  }

  Future<void> printLabel() async {
    final label = CargoLabel(
      brandName: 'BM Coach',
      bookingReference: 'BK-1025',
      item: CargoLabel.generateReference('BK-1025', 1),
      cargoName: 'Spare parts (engine)',
      sender: ['Otapp Agency Limited', 'Tel: +255 712 345 678'],
      receiver: ['John Mwakyusa', 'Tel: +255 765 432 109'],
      source: 'MWANZA',
      destination: 'DAR ES SALAAM',
      weight: '5.0 KG',
      package: '1 / 1',
      date: '2025-10-19',
    );
    final ok = await NtbpPlugin.printCargoLabel(
      label,
      config: const LabelPrintConfig(density: 10),
      logo: logo,
    );
    final status = await NtbpPlugin.waitUntilIdle();
    setState(() => message = ok ? 'Sent. Printer: ${status.description}' : 'Print failed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Label printer')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(onPressed: connect, child: const Text('Connect')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: printer == null ? null : printLabel,
              child: const Text('Print label'),
            ),
            const SizedBox(height: 24),
            Text(message),
          ],
        ),
      ),
    );
  }
}
```

The example app in `example/` shows a complete UI: a printer picker in a bottom sheet, a form
to add labels with different data, a reorderable series, media settings and a status header.

---

## 13. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Nothing prints, no error | Call `queryPrinterStatus()`. "Out of paper" or "Head opened" are reported there. Also check the label size in `LabelPrintConfig` matches the roll. |
| Labels come out upside down | Set `direction: 1` in `LabelPrintConfig`. |
| Printer skips a blank label between prints, or content drifts | Run `calibrateGap()` once with the loaded roll; check `gapMm` matches the real gap (usually 2 to 3 mm). |
| Printout is too light | Raise `density` (10 to 12 for most stock). |
| QR code hard to scan | Shorten the sender and receiver text, or switch that label to `CargoQrContent.itemReference`. |
| `PERMISSION_DENIED` on Android | Call `requestBluetoothPermissions()` first. If the dialog no longer appears the user chose "Don't ask again"; send them to the app's Settings page. |
| `DEVICE_NOT_FOUND` | The address was not in the last scan. Scan again before connecting. |
| iOS simulator build fails | The vendor library has no arm64 simulator slice. Use a real device. |
| Gradle: "Direct local .aar file dependencies are not supported" | Do not copy the aar into your app; the plugin serves it from its own Maven repo. Remove any `implementation files(...aar)` line you added. |

---

## 14. Migrating from 2.x

- `printSingleLabelWithGapDetection` and `printMultipleLabelsWithGapDetection` still exist and
  now work on iOS too. They render in Dart and no longer run calibration before every print.
- `getPrinterStatus()` now returns a decoded map (`code`, `status`, `description`, `ready`,
  `printing`, `error`). Prefer `NtbpPlugin.queryPrinterStatus()`.
- Android `minSdkVersion` must be 21.
- Permissions: call `requestBluetoothPermissions()`; you no longer need `permission_handler`
  on Android.
