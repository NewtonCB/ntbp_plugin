# Label Printing Flow (3.x)

How a `CargoLabel` becomes ink on an Xprinter XP-420B, and what happens between labels in a
series.

## Overview

```
CargoLabel + LabelPrintConfig + CargoLogo
        │
        ▼  CargoLabelLayout.buildJob()          (Dart, lib/src/tspl/)
TSPL script (text + binary logo bytes)
        │
        ▼  NtbpPlugin.sendTspl() → sendProtocolCommands(Uint8List)
Native transport
   Android: Xprinter printer-lib → classic Bluetooth SPP
   iOS:     Xprinter PrinterSDK  → Bluetooth LE
        │
        ▼
Printer prints; plugin polls ESC ! ? status between labels
```

Everything about the look of the label is decided in Dart. The native code never changes
the bytes, so Android and iOS print the same label for the same input.

## 1. The job

`CargoLabelLayout.buildJob(label, config, logo: logo)` returns one complete TSPL job:

```
SIZE 100 mm,150 mm            ← LabelPrintConfig.widthMm / heightMm
GAP 3 mm,0 mm                 ← gapMm / gapOffsetMm   (BLINE m,n when blackMark)
DENSITY 10                    ← only when density is set
DIRECTION 0,0                 ← direction (1 = rotated 180°)
REFERENCE 0,0
CLS                           ← clear the image buffer
TEXT 40,67,"5",0,1,1,"BM Coach"                       ← brand, top left
BITMAP 508,36,32,110,0,<3520 bytes>                   ← logo, top right
BAR 40,160,719,3                                      ← rule
QRCODE 552,186,M,3,A,0,"BOOKING REFERENCE: BK-1025 | ITEM: BK1025-001 | ..."
TEXT 40,190,"2",0,1,1,"BOOKING REFERENCE"
TEXT 40,220,"5",0,1,1,"BK-1025"
TEXT 40,304,"2",0,1,1,"ITEM"
TEXT 40,334,"5",0,1,1,"BK1025-001"
BOX 40,440,759,570,3
TEXT 56,454,"2",0,1,1,"SENDER"
TEXT 56,482,"4",0,1,1,"Otapp Agency Limited"
TEXT 56,526,"3",0,1,1,"Tel: +255 712 345 678"
BOX 40,570,759,699,3
TEXT 56,584,"2",0,1,1,"RECEIVER"
TEXT 56,611,"4",0,1,1,"John Mwakyusa"
TEXT 56,655,"3",0,1,1,"Tel: +255 765 432 109"
BOX 40,699,419,811,3   TEXT ... "DESTINATION"  TEXT ... "DAR ES SALAAM"
BOX 419,699,599,811,3  TEXT ... "WEIGHT"       TEXT ... "5.0 KG"
BOX 599,699,759,811,3  TEXT ... "PACKAGE"      TEXT ... "1 / 5"
BOX 40,811,454,904,3   TEXT ... "SOURCE"       TEXT ... "MWANZA"
BOX 454,811,759,904,3  TEXT ... "DATE"         TEXT ... "2025-10-19"
BOX 40,904,759,1159,3
TEXT 56,920,"2",0,1,1,"CARGO NAME"
TEXT 56,954,"5",0,1,1,"Spare parts (engine)"
PRINT 1,1                     ← 1 set, config.copies copies
```

`NtbpPlugin.previewCargoLabel(...)` returns exactly this text (with the logo bytes replaced
by a placeholder).

### Geometry

The layout is drawn on a reference grid of 800 x 1200 dots, which is a 100 x 150 mm label at
203 dpi (8 dots per mm). Every coordinate is multiplied by `widthDots / 800` and
`heightDots / 1200`, so other label sizes keep the same proportions.

| Band | Reference y | Content |
|---|---|---|
| Header | 36 – 146 | brand name (left, vertically centred), logo (right, box 360 x 110) |
| Rule | 160 | 3 dot bar |
| Top block | 186 – 422 | booking reference and item (left), QR code (right, up to 236 dots) |
| Sender | 440 – 570 | caption, name (font 4), phone (font 3) |
| Receiver | 570 – 700 | same |
| Row 1 | 700 – 812 | destination (380 wide), weight (180), package (160) |
| Row 2 | 812 – 905 | source (415), date (305) |
| Cargo name | 905 – 1160 | caption, name in the largest font that fits, wrapped |
| Margin | 1160 – 1200 | blank |

### Fonts

The printer's built-in bitmap fonts are used. `TsplFont.fit()` picks the largest font whose
rendering of the text fits the cell, and `TsplFont.clip()` truncates text that is too long
even for the smallest font.

| TSPL font | Glyph size (dots) | Used for |
|---|---|---|
| `"2"` | 12 x 20 | captions |
| `"3"` | 16 x 24 | phone numbers, long cargo names |
| `"4"` | 24 x 32 | party names, row values, two-line cargo names |
| `"5"` | 32 x 48 | brand, booking, item, short cargo names |

Text is escaped by `TsplBuilder.escape()`: double quotes become single quotes, line breaks
become spaces, and characters outside Latin-1 become `?` because the built-in fonts do not
have them.

### QR code

The QR encodes `CargoLabel.effectiveQrData`: by default `summaryText()`, which joins every
field with ` | ` (TSPL quoted strings cannot contain line breaks). The symbol version is
estimated from the byte length and the cell size is chosen so the code fits a 236 dot box,
never smaller than 3 dots per module so phones can read it.

### Logo

`CargoLogo.fromBytes()` decodes the image once. `toMono(maxWidth, maxHeight)` scales it to
fit (upscaling at most 2x), converts to 1 bit with a luminance threshold (or dithering) and
packs it in `BITMAP` row format: `widthBytes` bytes per row, most significant bit first,
1 = white. `TsplBuilder.bitmap()` emits `BITMAP x,y,widthBytes,height,0,` followed by the raw
bytes and CRLF.

## 2. Sending

`NtbpPlugin.sendTspl()` Latin-1 encodes the script into a `Uint8List` and calls the
`sendProtocolCommands` channel method. The typed list crosses the channel as binary data and
is written to the printer unchanged:

- **Android**: `IDeviceConnection.sendData(bytes)` on a background executor.
- **iOS**: `XBLEManager.writeCommand(with:writeCallBack:)`; the SDK chunks for BLE.

The call resolves true when the bytes were handed to the transport. It does not wait for the
paper to come out.

## 3. Series printing

`NtbpPlugin.printCargoLabels(labels, ...)` (and the legacy
`printMultipleLabelsWithGapDetection`) run this loop:

```
for each label:
    build job
    send job
    wait 200 ms
    poll ESC ! ? every 300 ms until the printer stops reporting "printing"
        (up to perLabelTimeout, default 15 s)
    if the printer reports head open / jam / out of paper / out of ribbon:
        stop, mark this and the remaining labels as failed
    if the printer never answers the status query:
        fall back to a timed delay (600 ms + 900 ms per copy) and continue
```

The result is a `PrintBatchResult` with `printed`, `failedIndexes` and `stoppedBy`.

What is **not** sent between labels, on purpose:

- no `FORMFEED` (the printer already advances to the next gap after `PRINT`; an extra feed
  ejects a blank label),
- no `HOME` (feeds to the next gap, also wasting a label),
- no `CLEAR` (not a TSPL command),
- no calibration (`GAPDETECT` / `AUTODETECT` feed several labels and belong to roll changes).

## 4. Calibration

`calibrateGap()` sends `GAPDETECT`, `calibrateBlackMark()` sends `BLINEDETECT`,
`autoCalibrate()` sends `AUTODETECT`. The printer feeds two or three labels through the sensor
and stores the measured label length and gap. Do it once after loading a roll. The `GAP` value
in every job must still match the physical gap of the stock (2 to 3 mm on common rolls).

## 5. Status

`queryPrinterStatus()` sends `ESC ! ?` and the printer answers with one status byte:

| Bit | Meaning |
|---|---|
| 0x00 | ready |
| 0x01 | head open |
| 0x02 | paper jam |
| 0x04 | out of paper |
| 0x08 | out of ribbon |
| 0x10 | paused |
| 0x20 | printing |

`PrinterStatus` decodes it; `code` is -1 when the printer did not answer and -2 when there is
no connection.

## 6. The legacy three-line label

`printSingleLabelWithGapDetection` still produces the 2.x layout (QR centred on top, up to
three text lines aligned to its left edge). The arithmetic is a direct port of the 2.0.0
Kotlin code into `ThreeLineQrLayout`, so output is unchanged on Android and now identical on
iOS. The only differences from 2.x are the removed non-TSPL commands and the removed per-print
calibration.

## 7. Timings (XP-420B over Bluetooth)

| Step | Typical |
|---|---|
| Build job in Dart | under 5 ms (logo already decoded) |
| Transfer, Android SPP, 6 KB job with logo | under 200 ms |
| Transfer, iOS BLE, same job | 1 to 3 s |
| Print one 100 x 150 mm label | about 1.5 s |
| Status poll round trip | 50 to 200 ms |
| Calibration | 3 to 6 s, feeds 2 to 3 labels |
