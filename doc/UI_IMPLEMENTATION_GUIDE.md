# UI Implementation Guide (3.x)

The plugin has no UI of its own. This guide shows a structure that works well for a label
printing screen and is what the bundled example app (`example/lib/`) implements. Copy the
parts you need.

## 1. Shape of the screen

```
┌─────────────────────────────────────┐
│ Printer header                      │  connection + live printer status
│   name / address / Online pill      │  Connect · Status · Calibrate
│   [permission banner when needed]   │
├─────────────────────────────────────┤
│ Media summary  100×150 · gap 3 · 10 │  tap → media settings page
├─────────────────────────────────────┤
│ Labels in series (3)        + Add   │
│  ┌ 1  BK-1025 · BK1025-001 ───────┐ │  tap → edit form
│  │    Spare parts · John → DAR    │ │  long-press → reorder
│  └────────────────────────────────┘ │  menu → print / duplicate / TSPL / delete
│  ┌ 2 …                                │
├─────────────────────────────────────┤
│ [+]   Print 3 labels                │  bottom bar
└─────────────────────────────────────┘
```

## 2. One controller for printer state

Keep every plugin call behind a `ChangeNotifier` so widgets only read state. The example's
`PrinterController` (`example/lib/state/printer_controller.dart`) exposes:

```dart
class PrinterController extends ChangeNotifier {
  final NtbpPlugin _plugin = NtbpPlugin();

  BluetoothPermission permission;   // unknown / granted / denied / blocked
  List<BluetoothDevice> devices;    // refreshed every second while scanning
  bool scanning, connecting, printing, checkingStatus;
  BluetoothDevice? connected;
  PrinterStatus? status;            // last ESC ! ? answer
  LabelPrintConfig config;          // media settings
  CargoLogo? logo;                  // decoded once at startup
  final List<CargoLabel> labels;    // the series

  Future<bool> requestPermissions();
  Future<void> scan();
  Future<bool> connect(BluetoothDevice d);
  Future<void> disconnect();
  Future<PrinterStatus> refreshStatus();
  Future<bool> calibrate();
  Future<bool> printLabel(CargoLabel l);
  Future<PrintBatchResult?> printAll();
  void addLabel / updateLabel / removeLabel / duplicateLabel / moveLabel;
}
```

Expose it with an `InheritedNotifier` (the example's `PrinterScope`), or with Provider,
Riverpod or Bloc; the plugin does not care.

Three habits that make the UI feel solid:

- **Poll the device list while scanning.** `startScan()` only completes when the window
  ends. Call `getDiscoveredDevices()` on a 1 second timer in the meantime so printers appear
  as they are found.
- **Refresh status after every print.** The header then shows "Out of paper" the moment it
  happens instead of after the next tap.
- **Re-check the connection on resume.** In `didChangeAppLifecycleState`, call
  `isConnected()`; Bluetooth links drop while the app is in the background.

## 3. Permissions banner

Show a banner in the header whenever `permission != granted`, with one button:

| State | Text | Button action |
|---|---|---|
| denied / unknown | "Bluetooth permission needed" | `requestPermissions()` → plugin shows the dialog |
| blocked | "Bluetooth is blocked for this app" | open the app's Settings page |

On Android the plugin is the authority (`hasBluetoothPermissions()`,
`requestBluetoothPermissions()`); use `permission_handler` only to detect "Don't ask again".
On iOS read `Permission.bluetooth` (with the Podfile macro) or simply try to scan.

## 4. Printer picker as a bottom sheet

The example uses `smooth_sheets`:

```dart
Navigator.of(context, rootNavigator: true).push(ModalSheetRoute<bool>(
  swipeDismissible: true,
  builder: (_) => PrinterScope(controller: c, child: const DeviceSheet()),
));
```

Inside, a `Sheet` with `SheetScrollConfiguration()` and a `ListView` of devices. Start the
scan in `initState`, show a `LinearProgressIndicator` while `scanning`, sort entries whose
name contains "XP", "print" or "label" to the top, and pop the sheet with `true` once
`connect()` succeeds. Any bottom sheet implementation works the same way.

## 5. Label form

One full-screen `Form` (`example/lib/screens/label_form_screen.dart`) with these sections:

| Section | Fields |
|---|---|
| Shipment | brand name, booking reference, item reference (auto-generated from the booking reference, with a regenerate button), cargo name, date (date picker) |
| Sender | name, phone |
| Receiver | name, phone |
| Package | source, destination, weight, package |
| QR code | summary / item reference / custom payload |

Validate the fields the layout cannot live without: booking reference, item reference, cargo
name, sender name, receiver name, source, destination. Return the `CargoLabel` with
`Navigator.pop(context, label)`.

Generate item references with `CargoLabel.generateReference(bookingRef, index)` so the top
of each label in a series carries `BK1025-001`, `BK1025-002`, ...

## 6. Series list

A `ReorderableListView` of cards. Each card shows the index, booking and item references,
cargo name, receiver and destination, plus chips for source, weight, package and date. The
overflow menu offers: print this label, edit, duplicate (bumps the item reference and the
package counter), view TSPL (`previewCargoLabel` in a dialog with a copy button), delete.

While a series prints, disable the cards and show a spinner on the one being printed
(`printingIndex`).

## 7. Print bar

A sticky bottom bar with an icon-only "new label" button and the primary action:

| State | Label |
|---|---|
| not connected | Connect printer (disabled) |
| idle | Print 3 labels (× copies when copies > 1) |
| printing | Printing 2/3… with a spinner |

After `printAll()` show a snackbar on success, or a dialog with `stoppedBy.description` and
how many labels remain when the printer stopped the batch.

## 8. Media settings page

Width and height in mm, gap (or black-mark height) with a black-mark switch, a 180° rotation
switch, a darkness slider (0 to 15), a copies stepper and a "print logo" switch. Save into a
`LabelPrintConfig` with `copyWith`.

## 9. Messages the user should see

| Event | Message |
|---|---|
| Scan finished, nothing found | "No printers found. Make sure the printer is on." |
| Connect failed | the `PlatformException.message` from the plugin |
| Calibrate tapped | "The printer feeds a few labels to measure the gap." (confirm first) |
| Print sent | "Sent BK-1025 to the printer" |
| Printer error after print | `status.description` ("Out of paper") |
| Batch stopped | "2 of 5 printed. Printer reported: Out of paper. Fix it and print the rest." |

## 10. Testing the UI without a printer

Swap the platform implementation with a mock in widget tests:

```dart
class FakePlatform extends NtbpPluginPlatform with MockPlatformInterfaceMixin {
  @override Future<bool> sendProtocolCommands(List<int> c, String p) async => true;
  @override Future<int> queryPrinterStatus({int timeoutMs = 2000}) async => 0;
  @override Future<bool> hasBluetoothPermissions() async => true;
  // ...other methods as needed
}

setUp(() => NtbpPluginPlatform.instance = FakePlatform());
```

`test/ntbp_plugin_test.dart` in the plugin repository has a complete mock to copy.
