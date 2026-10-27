# Advanced Integration Guide (3.x)

Read `INTEGRATION_GUIDE.md` first. This document covers what comes after the first label
prints: driving labels from a backend, localising, custom layouts, resilience, testing and
going to production.

## 1. Labels from a backend

`CargoLabel` serialises to a flat JSON object with `toMap()` and back with
`CargoLabel.fromMap()`:

```json
{
  "brandName": "BM Coach",
  "bookingReference": "BK-1025",
  "item": "BK1025-001",
  "cargoName": "Spare parts (engine)",
  "sender": ["Otapp Agency Limited", "Tel: +255 712 345 678"],
  "receiver": ["John Mwakyusa", "Tel: +255 765 432 109"],
  "source": "MWANZA",
  "destination": "DAR ES SALAAM",
  "weight": "5.0 KG",
  "package": "1 / 5",
  "date": "2025-10-19",
  "qrContent": "summary"
}
```

Captions are included in the map too, so a backend can localise them per label. Unknown keys
are ignored and missing keys fall back to defaults, so older payloads keep working.

A typical flow for a booking with several packages:

```dart
final booking = await api.fetchBooking(id);           // your model
final labels = [
  for (var i = 0; i < booking.packages; i++)
    CargoLabel(
      brandName: company.name,
      bookingReference: booking.reference,
      item: CargoLabel.generateReference(booking.reference, i + 1),
      cargoName: booking.description,
      sender: [booking.sender.name, 'Tel: ${booking.sender.phone}'],
      receiver: [booking.receiver.name, 'Tel: ${booking.receiver.phone}'],
      source: booking.origin,
      destination: booking.destination,
      weight: '${booking.weightKg} KG',
      package: '${i + 1} / ${booking.packages}',
      date: booking.date,
    ),
];
final result = await NtbpPlugin.printCargoLabels(labels, config: config, logo: logo);
await api.markPrinted(id, printed: result.printed, failed: result.failedIndexes);
```

Record `failedIndexes` on the server so a reprint only re-sends what is missing.

## 2. Localising captions

Every heading is a constructor parameter:

```dart
CargoLabel(
  ...,
  bookingReferenceCaption: 'NAMBA YA BUKU',
  itemCaption: 'KIFURUSHI',
  senderCaption: 'MTUMAJI',
  receiverCaption: 'MPOKEAJI',
  sourceCaption: 'KUTOKA',
  destinationCaption: 'KWENDA',
  weightCaption: 'UZITO',
  packageCaption: 'IDADI',
  dateCaption: 'TAREHE',
  cargoNameCaption: 'JINA LA MZIGO',
)
```

The built-in printer fonts cover Latin-1 only. Letters outside it print as `?`. For scripts
the printer cannot render, put that text in the logo image, or build a custom layout that
prints text as a bitmap (section 4).

## 3. QR payload strategies

| `qrContent` | Encodes | Use when |
|---|---|---|
| `summary` (default) | all fields as text | staff scan with any phone camera and read the details |
| `itemReference` | `item` only | a scanner app looks the item up in your system |
| `custom` + `qrData` | anything | a URL to a tracking page, a JSON blob, a signed token |

A URL keeps the QR small and lets you change what the user sees later:

```dart
qrContent: CargoQrContent.custom,
qrData: 'https://track.example.com/${label.item}',
```

## 4. Custom layouts

`TsplBuilder` gives you every command the cargo layout uses. A different label is a function
from your model to a job:

```dart
String buildReceipt(MyModel m, LabelPrintConfig config, CargoLogo? logo) {
  final b = TsplBuilder();
  config.writeHeader(b);                     // SIZE, GAP, DIRECTION, REFERENCE, CLS
  if (logo != null) {
    b.bitmap(40, 30, logo.toMono(maxWidth: 300, maxHeight: 100));
  }
  final font = TsplFont.fit(m.title, config.widthDots - 80);
  b.text(40, 150, font, m.title);
  b.box(30, 220, config.widthDots - 30, config.heightDots - 30, thickness: 3);
  b.qrCode(60, 250, m.url, cellWidth: 6);
  b.print(copies: config.copies);
  return b.build();
}

await NtbpPlugin.sendTspl(buildReceipt(model, config, logo));
```

Rules of thumb:

- Coordinates are dots: 8 per mm at 203 dpi. `config.widthDots` and `heightDots` give the
  label size.
- `TsplFont.textWidth(font, text)` and `charHeight(font)` let you centre and align.
- Keep 3 to 4 mm of margin; the XP-420B cannot print to the very edge.
- Use `TsplBuilder.makeReadable(script)` when logging a job that contains a bitmap.

You can also reuse pieces of the cargo layout: `CargoLabelLayout.writeContent(b, label,
config, logo: logo)` draws the cargo label into your builder without the header or the
`PRINT` line, so you can add a footer, change copies, or print two different labels in one
job.

## 5. Connection resilience

```dart
class PrinterSession {
  final plugin = NtbpPlugin();
  String? savedAddress;

  Future<bool> ensureConnected() async {
    if (await plugin.isConnected()) return true;
    if (savedAddress == null) return false;
    if (!await plugin.requestBluetoothPermissions()) return false;
    await plugin.startScan();
    final devices = await plugin.getDiscoveredDevices();
    final match = devices.where((d) => d.address == savedAddress);
    if (match.isEmpty) return false;
    return plugin.connectToDevice(match.first);
  }
}
```

- Store the address after the first successful connection (MAC on Android, identifier on
  iOS; both are stable per phone).
- Call `ensureConnected()` before every print job and when the app returns to the
  foreground.
- Treat `CONNECTION_TIMEOUT` as "printer off or taken by another device" and tell the user.
- Keep one `NtbpPlugin` instance; the native side holds a single connection regardless.

## 6. Error handling matrix

| Stage | Failure | Surface to user as |
|---|---|---|
| permission | `requestBluetoothPermissions()` false | banner with Grant / Settings |
| scan | `PERMISSION_DENIED`, `BLUETOOTH_NOT_AVAILABLE` | ask to enable Bluetooth / grant |
| connect | `DEVICE_NOT_FOUND`, `CONNECTION_*` | "Printer not reachable, is it on?" |
| send | `NOT_CONNECTED`, `SEND_*`, `EMPTY_PAYLOAD` | "Lost connection, reconnecting…" then retry once |
| after send | `PrinterStatus.hasError` | the status description, with a Retry button |
| series | `PrintBatchResult.stoppedBy` | "N of M printed, printer reports X" + reprint remaining |

Wrap plugin calls in `try { } on PlatformException catch (e) { e.code, e.message }`.

## 7. Testing

**Layout tests without a printer.** `previewCargoLabel` is deterministic. Assert on the
TSPL text:

```dart
final tspl = NtbpPlugin.previewCargoLabel(label, config: const LabelPrintConfig());
expect(tspl, contains('"BK1025-001"'));
expect(tspl.trimRight().split('\r\n').last, 'PRINT 1,1');
```

**Flow tests with a fake platform.** Replace `NtbpPluginPlatform.instance` with a mock
(see `test/ntbp_plugin_test.dart` in the repository) that records what `sendProtocolCommands`
received and returns scripted statuses from `queryPrinterStatus`. This lets you test the
"out of paper in the middle of a batch" path.

**Hardware checks before release.** Print one label of each kind on the real stock, scan the
QR with two different phones, and run a 10 label series with the roll deliberately running
out to confirm the batch stops and reports correctly.

## 8. Production checklist

- Media settings are per roll, not per app build. Expose width, height, gap, darkness and
  rotation in a settings screen and persist them.
- Offer a "Calibrate" action next to "Change roll" instructions; run it once per roll.
- Decode the logo once at startup (`CargoLogo.fromBytes`) and keep it; never decode per label.
- Darkness 10 to 12 for standard thermal stock; lower for high-sensitivity paper.
- Batch sizes above 20 labels: print in chunks and show progress using `printingIndex`.
- Log `previewCargoLabel` output on failures; it is the fastest way to reproduce a layout
  problem without the printer.

## 9. Platform notes

**Android**
- Classic Bluetooth SPP through the Xprinter SDK; the printer must be paired or discoverable.
- `minSdk 21`, `compileSdk 31+`.
- The plugin requests `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (12+) or fine location (≤ 11).
- One SPP connection per printer; disconnect other phones first.

**iOS**
- Bluetooth LE through the Xprinter SDK; no pairing step.
- Large jobs (with a logo) take 1 to 3 seconds to transfer over BLE; show a spinner.
- Real devices only; the vendor library has no arm64 simulator slice.
- `NSBluetoothAlwaysUsageDescription` required.
