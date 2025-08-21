# NTBP Plugin - Label Printing Flow

## 🏷️ QR + Text Label Printing Process

This document explains how the NTBP Plugin handles label printing, specifically the flow for printing QR codes with text below them.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Printing Flow](#printing-flow)
3. [TSPL Commands](#tspl-commands)
4. [Positioning](#positioning)
5. [Buffer Management](#buffer-management)
6. [Single vs Multiple Labels](#single-vs-multiple-labels)

## 🎯 Overview

The plugin implements a sophisticated label printing system that:
- Combines QR codes and text in single label frames
- Automatically positions content based on label dimensions
- Uses gap detection for proper label boundaries
- Manages print buffer to prevent content bleeding

## 🔄 Printing Flow

### High-Level Process
```
User Request → Validate Input → Connect to Printer → Send TSPL Commands → Print → Return Result
```

### Detailed Steps

#### 1. **Input Validation**
```dart
final success = await _plugin.printSingleLabelWithGapDetection(
  qrData: "QR123456",
  textData: "Sample Label",
  width: 75.0,    // mm
  height: 50.0,   // mm
  unit: "mm",
  dpi: 203,
  copies: 1,
  textSize: 9,
);
```

#### 2. **Dimension Conversion**
```kotlin
// Convert mm to printer dots (203 DPI)
val widthInDots = (width * dpi / 25.4).toInt()  // 75mm = 1488 dots
val heightInDots = (height * dpi / 25.4).toInt() // 50mm = 992 dots
```

#### 3. **Position Calculation**
```kotlin
// Calculate margins and available space
val marginInDots = when {
  labelWidth <= 30 -> convertToDots(dpi, 2.0, "mm")   // 2mm margin
  labelWidth <= 60 -> convertToDots(dpi, 3.0, "mm")   // 3mm margin
  else -> convertToDots(dpi, 4.0, "mm")               // 4mm margin
}

val availableWidth = widthInDots - 2 * marginInDots
val availableHeight = heightInDots - 2 * marginInDots

// QR code positioning (centered, upper portion)
val qrSize = (availableWidth * 0.7).toInt().coerceAtMost((availableHeight * 0.6).toInt())
val qrX = marginInDots + (availableWidth - qrSize) / 2
val qrY = marginInDots + (availableHeight * 0.15).toInt()

// Text positioning (centered, below QR)
val textX = marginInDots + (availableWidth - textWidth) / 2
val textY = qrY + qrSize + convertToDots(dpi, 8.0, "mm") // 8mm below QR
```

## 🔧 TSPL Commands

### Command Sequence

#### **Phase 1: Printer Setup**
```tspl
CLEAR                    # Clear print buffer
SIZE 1488,992           # Set label size (75mm x 50mm at 203 DPI)
GAP 40,0                # Set gap between labels (2mm)
GAPDETECT ON            # Enable gap detection
AUTODETECT ON           # Enable auto-detection
CLS                     # Clear screen
```

#### **Phase 2: Content Positioning**
```tspl
REFERENCE 0,0           # Set reference point to top-left
DIRECTION 0             # Set print direction (normal)
```

#### **Phase 3: Content Printing**
```tspl
QRCODE 334,148,H,10,A,0,"QR123456"    # Print QR code
TEXT 334,968,"9",0,1,1,"Sample Label" # Print text below QR
PRINT 1                                # Execute print
```

### Command Details

| Command | Purpose | Parameters |
|---------|---------|------------|
| `SIZE` | Set label dimensions | `width,height` in dots |
| `GAP` | Set gap between labels | `gapSize,0` in dots |
| `QRCODE` | Print QR code | `x,y,model,size,alignment,0,"data"` |
| `TEXT` | Print text | `x,y,font,rotation,xScale,yScale,"text"` |
| `PRINT` | Execute print | `copies` |

## 📐 Positioning

### Dynamic Positioning System

The plugin automatically calculates optimal positions:

#### **Small Labels (≤30mm width)**
- Margin: 2mm
- QR size: 60% of available width
- Text: 8mm below QR code

#### **Medium Labels (31-60mm width)**
- Margin: 3mm
- QR size: 65% of available width
- Text: 8mm below QR code

#### **Large Labels (>60mm width)**
- Margin: 4mm
- QR size: 70% of available width
- Text: 8mm below QR code

### Example: 75mm x 50mm Label
```
Label: 75mm x 50mm (1488 x 992 dots)
Margins: 3mm (24 dots)
Available: 1440 x 944 dots

QR Code: 820 x 820 dots
Position: (310, 142) dots

Text: 20mm width (160 dots)
Position: (640, 962) dots
```

## 🧹 Buffer Management

### Buffer Clearing Strategy

#### **Aggressive Buffer Clearing**
```kotlin
private suspend fun clearBufferAggressively() {
  sendCommands("CLEAR".toByteArray().toList())  // Clear buffer
  Thread.sleep(150)
  sendCommands("CLS".toByteArray().toList())    // Clear screen
  Thread.sleep(150)
  sendCommands("HOME".toByteArray().toList())   // Reset position
  Thread.sleep(200)
}
```

#### **When Buffer is Cleared**
1. **Before each label** to prevent content bleeding
2. **After gap detection** initialization
3. **Between multiple labels** in sequence printing

### Buffer Management Flow
```
Print Request → Clear Buffer → Print Content → Wait → Next Label
     ↓            ↓            ↓           ↓        ↓
  Validate    CLEAR+CLS    TSPL Comm   Monitor   Repeat or
  Parameters  +HOME        +Content     Progress  Complete
```

## 🏷️ Single vs Multiple Labels

### Single Label Printing

#### **Flow**
```
1. Initialize printer
2. Send gap detection commands
3. Clear buffer
4. Calculate positions
5. Print QR + text
6. Wait for completion
7. Return success
```

#### **TSPL Commands**
```tspl
CLEAR
SIZE 1488,992
GAP 40,0
GAPDETECT ON
AUTODETECT ON
CLS
CLEAR
CLS
HOME
REFERENCE 0,0
DIRECTION 0
QRCODE 334,148,H,10,A,0,"QR123456"
TEXT 334,968,"9",0,1,1,"Sample Label"
PRINT 1
```

### Multiple Labels Printing

#### **Flow**
```
1. Initialize printer
2. Send gap detection commands
3. For each label:
   a. Clear buffer
   b. Calculate positions
   c. Print QR + text
   d. Feed to next label
4. Final cut
5. Return success/failure
```

#### **TSPL Commands for Multiple Labels**
```tspl
# Initialization
CLEAR
SIZE 1488,992
GAP 40,0
GAPDETECT ON
AUTODETECT ON
CLS

# Label 1
CLEAR
CLS
HOME
REFERENCE 0,0
DIRECTION 0
QRCODE 334,148,H,10,A,0,"QR001"
TEXT 334,968,"9",0,1,1,"Product A"
PRINT 1
FORMFEED

# Label 2
CLEAR
CLS
HOME
REFERENCE 0,0
DIRECTION 0
QRCODE 334,148,H,10,A,0,"QR002"
TEXT 334,968,"9",0,1,1,"Product B"
PRINT 1

# Final cut
CUT
```

## 🔍 Gap Detection

### How It Works
- **GAPDETECT ON**: Enables automatic gap detection
- **AUTODETECT ON**: Enables automatic label detection
- **GAP command**: Sets expected gap size between labels

### Gap Size Calculation
```kotlin
val gapSize = when {
  labelHeight <= 20 -> convertToDots(dpi, 2.0, "mm")   // 2mm gap
  labelHeight <= 40 -> convertToDots(dpi, 2.5, "mm")   // 2.5mm gap
  else -> convertToDots(dpi, 3.0, "mm")                // 3mm gap
}
```

## ❌ Error Handling

### Common Errors
1. **NOT_CONNECTED**: Printer not connected
2. **PRINTING_ERROR**: TSPL command failure
3. **TIMEOUT_ERROR**: Operation timeout
4. **BUFFER_ERROR**: Buffer clearing failure

### Error Recovery
```kotlin
try {
  sendCommands(commands.toByteArray().toList())
} catch (e: Exception) {
  result.error("PRINTING_ERROR", "Failed to send commands: ${e.message}", null)
  return@launch
}
```

## ⚡ Performance

### Typical Timings
- **Buffer Clear**: 200-400ms
- **Position Calculation**: 1-5ms
- **TSPL Command Send**: 50-100ms
- **Print Execution**: 500-2000ms
- **Paper Feed**: 300-500ms

### Optimization Tips
1. **Batch commands** instead of sending separately
2. **Reuse connections** when possible
3. **Clear buffer** only when necessary
4. **Use appropriate delays** between operations

## 🐛 Troubleshooting

### Content Bleeding
- Use aggressive buffer clearing
- Add delays between labels
- Check TSPL command sequence

### Misaligned Content
- Verify label dimensions and DPI
- Check positioning calculations
- Ensure proper reference point

### Gap Detection Issues
- Check label gap size (2-3mm typical)
- Verify gap detection is enabled
- Test with different label materials

## 📊 Monitoring

### Debug Logging
```kotlin
android.util.Log.d("NTBPPlugin", "Label dimensions: ${width}mm x ${height}mm")
android.util.Log.d("NTBPPlugin", "Calculated positions: QR($qrX,$qrY), Text($textX,$textY)")
android.util.Log.d("NTBPPlugin", "TSPL commands: $commands")
```

### Connection Status
```dart
final status = await _plugin.getConnectionStatus();
final details = await _plugin.getDetailedConnectionStatus();
```

---

This document provides the essential information about how the NTBP Plugin handles label printing. For more details, refer to the [API Reference](API_REFERENCE.md) and [Troubleshooting Guide](TROUBLESHOOTING.md). 