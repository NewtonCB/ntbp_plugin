# Troubleshooting (3.x)

Work through the section that matches the symptom. Each entry says what to check and the
exact fix. The first tool in every case is the printer status:

```dart
final s = await NtbpPlugin.queryPrinterStatus();
print('${s.code} ${s.description}');
```

## Table of contents

1. [Installation and build](#1-installation-and-build)
2. [Permissions](#2-permissions)
3. [Finding and connecting to the printer](#3-finding-and-connecting-to-the-printer)
4. [Nothing prints](#4-nothing-prints)
5. [Wrong output](#5-wrong-output)
6. [Series printing](#6-series-printing)
7. [Debug information](#7-debug-information)
8. [Reporting a bug](#8-reporting-a-bug)

---

## 1. Installation and build

**Android: `uses-sdk:minSdkVersion 19 cannot be smaller than version 21`**
The Xprinter SDK needs API 21. Set `minSdk = 21` in `android/app/build.gradle`.

**Android: `Direct local .aar file dependencies are not supported when building an AAR`**
You copied `printer-lib-3.5.8.aar` into your own project. Remove that `implementation
files(...)` line; the plugin already serves the aar from its internal Maven repository.

**Android: `Could not find net.posprinter:printer-lib:3.5.8`**
The plugin registers its repository on every project of the build. If your
`settings.gradle` uses `dependencyResolutionManagement { repositoriesMode =
FAIL_ON_PROJECT_REPOS }`, either switch to `PREFER_SETTINGS` or add the plugin's repository
there:

```kotlin
maven { url = uri("<path to pub cache>/ntbp_plugin-3.0.0/android/libs/repo") }
```

**iOS: `'ntbp_plugin/ntbp_plugin.h' file not found`**
Stale pod install. Run `cd ios && pod install`, then build again.

**iOS simulator: linker errors or `does not support arm64`**
The vendor library has no Apple-silicon simulator slice. Test on a real iPhone, or run the
simulator under Rosetta.

**iOS: `No profiles for '...' were found` / `No Accounts`**
Sign into Xcode (Settings → Accounts) with the Apple ID of your team, open
`ios/Runner.xcworkspace`, enable "Automatically manage signing" on the Runner target.

---

## 2. Permissions

**Android: scan fails with `PERMISSION_DENIED`**
Call `await NtbpPlugin().requestBluetoothPermissions()` and wait for `true` before scanning.
The dialog is "Nearby devices" on Android 12+ and "Location" on Android 11 and below.

**Android: the permission dialog does not appear**
- `requestBluetoothPermissions()` needs a foreground Activity. Calling it from a background
  isolate or before the first frame returns `NO_ACTIVITY`; call it from a button handler or in
  `WidgetsBinding.instance.addPostFrameCallback`.
- The user previously chose "Don't ask again". Android then never shows the dialog. Send the
  user to the app's Settings page (`permission_handler`'s `openAppSettings()` works for this).

**Android 11 and below: permission granted but discovery finds nothing**
Location services must be switched on in the phone's settings for classic Bluetooth
discovery to return results. Bonded printers are still listed.

**iOS: Bluetooth permission always "denied" when read with permission_handler**
`permission_handler` compiles the Bluetooth permission out unless the Podfile sets
`PERMISSION_BLUETOOTH=1` in `GCC_PREPROCESSOR_DEFINITIONS` (see the integration guide). The
plugin itself does not need this; only your permission_handler calls do.

**iOS: the app never asked for Bluetooth**
Make sure `NSBluetoothAlwaysUsageDescription` is in `Info.plist`. Without it iOS silently
blocks Bluetooth and may terminate the app on first use.

---

## 3. Finding and connecting to the printer

**The printer is not in the scan results (Android)**
- Pair it once in the phone's Bluetooth settings; bonded devices are always listed.
- The XP-420B advertises classic Bluetooth. BLE-only entries are skipped on Android on
  purpose because the SDK connects over SPP.
- Only one phone can hold the SPP connection; disconnect it from any other phone or PC.

**The printer is not in the scan results (iOS)**
- iOS uses BLE. Make sure the printer is on and not connected to another iOS device.
- Move closer; the scan window is 10 seconds.
- Bluetooth must be on in Control Centre and allowed for the app in Settings.

**`DEVICE_NOT_FOUND` on connect**
The address was not in the most recent scan. Scan again, then connect. Addresses are stable
(MAC on Android, peripheral identifier on iOS), so storing them is fine, but a scan must
precede the connect.

**`CONNECTION_ERROR` / `CONNECTION_TIMEOUT`**
- Printer off, asleep, or already connected elsewhere.
- Android 12+: `BLUETOOTH_CONNECT` not granted (the plugin now reports `PERMISSION_DENIED`
  for this before dialing).
- Power-cycle the printer and retry; the SDK gives up after 20 seconds.

**Connection drops after a while**
The example app re-checks the native connection when it returns to the foreground
(`plugin.isConnected()`). Do the same, and reconnect by scanning and matching the stored
address.

---

## 4. Nothing prints

1. **Ask the printer.** `queryPrinterStatus()` → "Out of paper", "Head opened", "Paper jam"
   or "Paused" tells you what to fix. "No response" means the link is up but the printer is
   not answering; power-cycle it.
2. **Check the return value.** `printCargoLabel` returns false, or throws `NOT_CONNECTED`,
   `SEND_ERROR`, `SEND_TIMEOUT` or `EMPTY_PAYLOAD`, when the bytes never left the phone.
3. **Check the media size.** If `LabelPrintConfig` says 100 x 150 mm but the roll is 100 x
   100 mm, the printer may feed past the gap looking for the end of the label and print
   nothing visible. Match `widthMm` / `heightMm` to the stock.
4. **Calibrate.** After a roll change run `calibrateGap()` once.
5. **Look at what was sent.** `NtbpPlugin.previewCargoLabel(label, config: c, logo: l)`
   returns the TSPL; `SIZE` and `GAP` should match the paper, and the `PRINT` line must be
   last.

---

## 5. Wrong output

| Symptom | Fix |
|---|---|
| Labels print upside down | `LabelPrintConfig(direction: 1)` |
| Content shifted down, or a blank label between prints | Run `calibrateGap()`; set `gapMm` to the real gap (2 to 3 mm) |
| Content cut off at the bottom | `heightMm` larger than the real label; fix the config |
| Print too light | Raise `density` (0 to 15). 10 to 12 for most stock |
| Print too dark, smeared | Lower `density`; lower `speed` (for example 3) |
| Logo prints as a black block | Logo has a dark or transparent background. Transparent areas are flattened on white; a dark background needs a different image or a higher `threshold` |
| Logo prints washed out or missing lines | Lower `threshold` (default 170), or use `dither: true` |
| Phone cannot scan the QR | The summary is long. Shorten sender and receiver text, or set `qrContent: CargoQrContent.itemReference` for that label |
| `?` printed instead of a character | The built-in fonts cover Latin-1 only. Use ASCII, or render the text as part of the logo image |
| Quotes missing from text | Double quotes are converted to single quotes; TSPL has no escape for them |
| Text truncated | The field is too long for the cell even in the smallest font. Shorten it or override the caption to free space |

---

## 6. Series printing

**The batch stopped early**
`PrintBatchResult.stoppedBy` holds the printer status that stopped it (out of paper, head
open, jam). Fix the printer and print `failedIndexes` again.

**Every label is reported printed but some are missing on paper**
The printer never answered the status query, so the plugin fell back to timing. Check that
the printer answers `queryPrinterStatus()`; if it never does, increase the fallback by
printing fewer copies per job, or set `waitForPrinter: false` and pace the batch yourself.

**A blank label between each printed label**
You are sending `FORMFEED` or `HOME` yourself between jobs. The plugin does not; remove them.

---

## 7. Debug information

```dart
await plugin.getDetailedConnectionStatus();
// {connectionState, socketConnected, socketAddress, socketName, lastError, transport}

NtbpPlugin.previewCargoLabel(label, config: config, logo: logo); // the TSPL
```

Android logs are tagged `NTBPPlugin`:

```bash
adb logcat -s NTBPPlugin
```

iOS logs appear in the Xcode console. The vendor SDK prints its own BLE write and status
messages there too.

Error codes raised as `PlatformException`:

| Code | Where | Meaning |
|---|---|---|
| `PERMISSION_DENIED` | scan, connect | A runtime permission is missing |
| `NO_ACTIVITY` | requestBluetoothPermissions | No foreground Activity to show the dialog |
| `BLUETOOTH_NOT_AVAILABLE` | scan, connect | Bluetooth off or unsupported |
| `DEVICE_NOT_FOUND` | connect | Address not in the last scan |
| `CONNECTION_ERROR`, `CONNECTION_TIMEOUT`, `CONNECTION_CANCELLED` | connect | Could not connect |
| `NOT_CONNECTED` | send, status | No open connection |
| `EMPTY_PAYLOAD` | send | Zero bytes arrived at the native side |
| `SEND_ERROR`, `SEND_TIMEOUT` | send | Transport failed |

---

## 8. Reporting a bug

Include:

- Printer model and firmware (the XP-420B prints a self-test page when powered on while
  holding the feed button).
- Phone model, OS version, plugin version.
- The TSPL from `previewCargoLabel` (attach as text).
- `queryPrinterStatus()` output before and after the failed print.
- Android: `adb logcat -s NTBPPlugin`. iOS: the Xcode console.
- A photo of the label if the output is wrong.

Open the issue at https://github.com/NewtonCB/ntbp_plugin/issues.
