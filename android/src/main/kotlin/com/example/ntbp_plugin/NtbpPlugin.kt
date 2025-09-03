package com.example.ntbp_plugin

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.ConcurrentHashMap

/** NtbpPlugin - Focused on Thermal Label Printing */
class NtbpPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private var bluetoothAdapter: BluetoothAdapter? = null
  private var bluetoothSocket: BluetoothSocket? = null
  private var outputStream: OutputStream? = null
  private val discoveredDevices = ConcurrentHashMap<String, BluetoothDevice>()
  private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ntbp_plugin")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    
    // Initialize Bluetooth adapter
    bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
    
    // Register discovery receiver
    val discoveryReceiver = DiscoveryReceiver()
    val filter = IntentFilter().apply {
      addAction(BluetoothDevice.ACTION_FOUND)
      addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
      addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
    }
    context.registerReceiver(discoveryReceiver, filter)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      
      // Core printing methods - KEEP THESE
      "printSingleLabelWithGapDetection" -> {
        val args = call.arguments as Map<String, Any>
        val qrData = args["qrData"] as String
        val textData1 = args["textData1"] as? String ?: "" // Customer name
        val textData2 = args["textData2"] as? String ?: "" // Drop point
        val textData3 = args["textData3"] as? String ?: "" // Additional info
        val width = (args["width"] as? Number)?.toDouble() ?: 75.0
        val height = (args["height"] as? Number)?.toDouble() ?: 70.0 // Increased height for 3 text lines
        val unit = args["unit"] as? String ?: "mm"
        val dpi = (args["dpi"] as? Number)?.toInt() ?: 203
        val copies = (args["copies"] as? Number)?.toInt() ?: 1
        val textSize = (args["textSize"] as? Number)?.toInt() ?: 9
        
        printSingleLabelWithGapDetection(qrData, textData1, textData2, textData3, width, height, unit, dpi, copies, textSize, result)
      }
      
      "printMultipleLabelsWithGapDetection" -> {
        val args = call.arguments as Map<String, Any>
        val labelDataList = args["labelDataList"] as? List<Map<String, Any>> ?: emptyList()
        val width = (args["width"] as? Number)?.toDouble() ?: 75.0
        val height = (args["height"] as? Number)?.toDouble() ?: 60.0 // Increased height for 2 text lines
        val unit = args["unit"] as? String ?: "mm"
        val dpi = (args["dpi"] as? Number)?.toInt() ?: 203
        val copiesPerLabel = (args["copiesPerLabel"] as? Number)?.toInt() ?: 1
        val textSize = (args["textSize"] as? Number)?.toInt() ?: 9
        
        printMultipleLabelsWithGapDetection(labelDataList, width, height, unit, dpi, copiesPerLabel, textSize, result)
      }
      
      // Protocol support methods - NEW ARCHITECTURE
      "sendProtocolCommands" -> {
        val commands = call.argument<List<Int>>("commands") ?: emptyList()
        val protocolName = call.argument<String>("protocolName") ?: "TSPL"
        sendProtocolCommands(commands, protocolName, result)
      }
      
      "initializeProtocolPrinter" -> {
        val printerModel = call.argument<String>("printerModel") ?: ""
        val labelWidth = call.argument<Double>("labelWidth") ?: 75.0
        val labelHeight = call.argument<Double>("labelHeight") ?: 50.0
        val unit = call.argument<String>("unit") ?: "mm"
        val dpi = call.argument<Int>("dpi") ?: 203
        initializeProtocolPrinter(printerModel, labelWidth, labelHeight, unit, dpi, result)
      }
      
      "printWithProtocol" -> {
        val protocolName = call.argument<String>("protocolName") ?: "TSPL"
        val printData = call.argument<Map<String, Any>>("printData") ?: emptyMap()
        printWithProtocol(protocolName, printData, result)
      }
      
      // Legacy methods - KEPT FOR BACKWARD COMPATIBILITY
      "print" -> {
        val commands = call.arguments as List<Map<*, *>>
        printCommands(commands, result)
      }
      
      "printText" -> {
        val text = call.arguments as String
        printText(text, result)
      }
      
      "printBarcode" -> {
        val data = call.arguments as String
        printBarcode(data, result)
      }
      
      "printQRCode" -> {
        val data = call.arguments as String
        printQRCode(data, result)
      }
      
      "clearBuffer" -> {
        clearPrintBuffer(result)
      }
      
      "getPrinterStatus" -> {
        getPrinterStatus(result)
      }
      
      "feedPaper" -> {
        val lines = call.argument<Int>("lines") ?: 1
        feedPaper(lines, result)
      }
      
      // Connection methods - SIMPLIFIED for basic functionality
      "connectToDevice" -> {
        val deviceMap = call.arguments as Map<*, *>
        val address = deviceMap["address"] as String
        connectToDevice(address, result)
      }
      
      "disconnect" -> {
        disconnect(result)
      }
      
      "isConnected" -> {
        result.success(isConnected())
      }
      
      "getConnectionStatus" -> {
        result.success(if (isConnected()) "CONNECTED" else "DISCONNECTED")
      }
      
      "getDetailedConnectionStatus" -> {
        val statusMap = mapOf(
          "connectionState" to (if (isConnected()) "CONNECTED" else "DISCONNECTED"),
          "socketConnected" to (bluetoothSocket?.isConnected == true),
          "hasOutputStream" to (outputStream != null),
          "socketAddress" to bluetoothSocket?.remoteDevice?.address,
          "socketName" to bluetoothSocket?.remoteDevice?.name
        )
        result.success(statusMap)
      }
      
      // Device discovery - SIMPLIFIED
      "startScan" -> {
        startScan(result)
      }
      
      "stopScan" -> {
        stopScan(result)
      }
      
      "getDiscoveredDevices" -> {
        getDiscoveredDevices(result)
      }
      
      else -> {
        result.notImplemented()
      }
    }
  }

  // ============================================================================
  // CORE PRINTING METHODS - FOCUS ON LABEL PRINTING
  // ============================================================================

  /**
   * Print single label with gap detection - CORE METHOD
   * This is the main method used by the plugin for single label printing
   */
  private fun printSingleLabelWithGapDetection(
    qrData: String,
    textData1: String,
    textData2: String,
    textData3: String,
    labelWidth: Double,
    labelHeight: Double,
    labelUnit: String,
    labelDpi: Int,
    labelCopies: Int,
    labelTextSize: Int,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        android.util.Log.d("NTBPPlugin", "Starting enhanced single label print: ${labelWidth}x${labelHeight} $labelUnit, $labelCopies copies")
        
        // Step 1: Initialize printer with gap detection
        sendGapDetectionCommands(labelWidth, labelHeight, labelUnit, labelDpi)
        Thread.sleep(300) // Wait for initialization
        
        // ENHANCED BUFFER CLEARING: Clear all buffers before printing to prevent content bleeding
        clearBufferAggressively()
        Thread.sleep(300) // Wait for printer to process all clearing commands
        
        // Step 2: Calculate optimal positioning for better content placement
        val widthInDots = convertToDots(labelDpi, labelWidth, labelUnit)
        val heightInDots = convertToDots(labelDpi, labelHeight, labelUnit)
        
        // Calculate margins (dynamic based on label size)
        val marginInDots = when {
          labelWidth <= 30 -> convertToDots(labelDpi, 2.0, "mm")
          labelWidth <= 60 -> convertToDots(labelDpi, 3.0, "mm")
          else -> convertToDots(labelDpi, 4.0, "mm")
        }
        
        val availableWidth = widthInDots - 2 * marginInDots
        val availableHeight = heightInDots - 2 * marginInDots
        
        // Calculate QR size (back to original approach)
        val qrSize = when {
          labelWidth <= 30 -> (availableWidth * 0.55).toInt()
          labelWidth <= 60 -> (availableWidth * 0.6).toInt()
          else -> (availableWidth * 0.65).toInt()
        }.coerceAtMost((availableHeight * 0.45).toInt()).coerceAtMost((availableWidth * 0.65).toInt())
        
        // Calculate positions with original approach but optimized for 3 text lines
        val qrX = marginInDots + (availableWidth - qrSize) / 2 // Center horizontally
        val qrY = marginInDots + (availableHeight * 0.08).toInt() // Original QR position
        
        // Align all text lines to start at the same left position as the QR code
        val textX = qrX // Start text at the same X position as QR code
        
        val textY1 = qrY + qrSize + convertToDots(labelDpi, 8.0, "mm") // Increased gap after QR
        val textY2 = textY1 + convertToDots(labelDpi, 4.0, "mm") // Reduced gap between text lines (was 8mm)
        val textY3 = textY2 + convertToDots(labelDpi, 4.0, "mm") // Third text line with reduced gap
        
        // Ensure text doesn't go beyond label boundaries
        val maxTextY = heightInDots - marginInDots - convertToDots(labelDpi, 2.0, "mm")
        val finalTextY1 = if (textY1 > maxTextY) maxTextY - convertToDots(labelDpi, 8.0, "mm") else textY1
        val finalTextY2 = if (textY2 > maxTextY) maxTextY - convertToDots(labelDpi, 4.0, "mm") else textY2
        val finalTextY3 = if (textY3 > maxTextY) maxTextY else textY3
        
        // Step 3: Build TSPL commands for single label
        val commands = buildString {
          appendLine("REFERENCE 0,0") // Set reference point
          appendLine("DIRECTION 0") // Normal direction
          
          // Add QR code positioned in upper portion
          appendLine("QRCODE $qrX,$qrY,H,10,A,0,\"$qrData\"")
          
          // Add first text line (Customer name)
          if (textData1.isNotEmpty()) {
            appendLine("TEXT $textX,$finalTextY1,\"$labelTextSize\",0,1,1,\"$textData1\"")
          }
          
          // Add second text line (Drop point)
          if (textData2.isNotEmpty()) {
            appendLine("TEXT $textX,$finalTextY2,\"$labelTextSize\",0,1,1,\"$textData2\"")
          }
          
          // Add third text line (Additional info)
          if (textData3.isNotEmpty()) {
            appendLine("TEXT $textX,$finalTextY3,\"$labelTextSize\",0,1,1,\"$textData3\"")
          }
          
          // Print specified number of copies
          appendLine("PRINT $labelCopies")
        }
        
        android.util.Log.d("NTBPPlugin", "Enhanced label commands: QR($qrX,$qrY) size:$qrSize, Text1($textX,$finalTextY1): $textData1, Text2($textX,$finalTextY2): $textData2, Text3($textX,$finalTextY3): $textData3, Copies: $labelCopies")
        
        // Send commands
        sendCommands(commands.toByteArray().toList())
        
        // Wait for print completion
        Thread.sleep(500 * labelCopies.toLong()) // Longer delay for multiple copies
        
        result.success(true)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error printing enhanced single label: ${e.message}")
        result.error("ENHANCED_LABEL_ERROR", "Failed to print enhanced single label: ${e.message}", null)
      }
    }
  }

  /**
   * Print multiple labels with gap detection - CORE METHOD
   * This is the main method used by the plugin for multiple label printing
   */
  private fun printMultipleLabelsWithGapDetection(
    labelDataList: List<Map<String, Any>>,
    labelWidth: Double,
    labelHeight: Double,
    unit: String,
    dpi: Int,
    copiesPerLabel: Int,
    textSize: Int,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        if (labelDataList.isEmpty()) {
          result.error("EMPTY_LABEL_LIST", "Label data list is empty", null)
          return@launch
        }
        
        android.util.Log.d("NTBPPlugin", "Printing ${labelDataList.size} labels: ${labelWidth}x${labelHeight} $unit, $copiesPerLabel copies each")
        
        // Step 1: Initialize printer with gap detection
        sendGapDetectionCommands(labelWidth, labelHeight, unit, dpi)
        delay(300)
        
        // Step 2: Clear buffer completely
        clearBufferCompletely()
        delay(400)
        
        var successCount = 0
        var failureCount = 0
        
        // Step 3: Print each label
        for ((index, labelData) in labelDataList.withIndex()) {
          try {
            val qrData = labelData["qrData"] as? String ?: "Label${index + 1}"
            val textData1 = labelData["textData1"] as? String ?: ""
            val textData2 = labelData["textData2"] as? String ?: ""
            val textData3 = labelData["textData3"] as? String ?: ""
            
            android.util.Log.d("NTBPPlugin", "Printing label ${index + 1}: $qrData - $textData1, $textData2,$textData3")
            
            // Clear buffer before each label
            clearBufferAggressively()
            delay(300)
            
            // Calculate positions
            val positions = calculateLabelPositions(labelWidth, labelHeight, unit, dpi, textSize)
            android.util.Log.d("NTBPPlugin", "Label ${index + 1} positions: $positions")
            
            // Build commands for this individual label in the sequence
            val commands = buildString {
              appendLine("REFERENCE 0,0") // Set reference point for this label
              appendLine("DIRECTION 0") // Normal direction
              appendLine("CLS") // Clear buffer for this label
              appendLine("QRCODE ${positions["qrX"]},${positions["qrY"]},H,10,A,0,\"$qrData\"")
              
              // Add first text line (Customer name)
              if (textData1.isNotEmpty()) {
                appendLine("TEXT ${positions["textX"]},${positions["textY1"]},\"$textSize\",0,1,1,\"$textData1\"")
              }
              
              // Add second text line (Drop point)
              if (textData2.isNotEmpty()) {
                appendLine("TEXT ${positions["textX"]},${positions["textY2"]},\"$textSize\",0,1,1,\"$textData2\"")
              }

              // Add third text line (Additional info)
              if (textData3.isNotEmpty()) {
                appendLine("TEXT ${positions["textX"]},${positions["textY3"]},\"$textSize\",0,1,1,\"$textData3\"")
              }
              
              appendLine("PRINT $copiesPerLabel")
            }
            
            android.util.Log.d("NTBPPlugin", "Label ${index + 1} commands: $commands")
            sendCommands(commands.toByteArray().toList())
            
            // Wait for completion
            delay(500 * copiesPerLabel.toLong())
            
            // Feed to next label (except last)
            if (index < labelDataList.size - 1) {
              sendCommands("FORMFEED".toByteArray().toList())
              delay(400)
            }
            
            successCount++
            
          } catch (e: Exception) {
            android.util.Log.e("NTBPPlugin", "Error printing label ${index + 1}: ${e.message}")
            failureCount++
          }
        }
        
        // Final cut
        sendCommands("CUT".toByteArray().toList())
        
        android.util.Log.d("NTBPPlugin", "Multiple labels completed: $successCount successful, $failureCount failed")
        result.success(failureCount == 0)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error in multiple labels printing: ${e.message}")
        result.error("MULTIPLE_LABELS_ERROR", "Failed to print multiple labels: ${e.message}", null)
      }
    }
  }

  // ============================================================================
  // PROTOCOL SUPPORT METHODS - NEW ARCHITECTURE
  // ============================================================================

  /**
   * Send protocol commands to printer
   */
  private fun sendProtocolCommands(commands: List<Int>, protocolName: String, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        android.util.Log.d("NTBPPlugin", "Sending ${commands.size} protocol commands for $protocolName")
        
        // Convert Int list to Byte array and send
        val byteCommands = commands.map { it.toByte() }
        sendCommands(byteCommands)
        
        result.success(true)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error sending protocol commands: ${e.message}")
        result.error("PROTOCOL_COMMANDS_ERROR", "Failed to send protocol commands: ${e.message}", null)
      }
    }
  }

  /**
   * Initialize printer for specific protocol
   */
  private fun initializeProtocolPrinter(
    printerModel: String,
    labelWidth: Double,
    labelHeight: Double,
    unit: String,
    dpi: Int,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        android.util.Log.d("NTBPPlugin", "Initializing $printerModel for ${labelWidth}x${labelHeight} $unit")
        
        // Send gap detection commands
        sendGapDetectionCommands(labelWidth, labelHeight, unit, dpi)
        delay(300)
        
        result.success(true)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error initializing protocol printer: ${e.message}")
        result.error("INIT_PROTOCOL_ERROR", "Failed to initialize protocol printer: ${e.message}", null)
      }
    }
  }

  /**
   * Print with specific protocol
   */
  private fun printWithProtocol(protocolName: String, printData: Map<String, Any>, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        android.util.Log.d("NTBPPlugin", "Printing with protocol: $protocolName")
        
        // Extract print data
        val qrData = printData["qrData"] as? String ?: ""
        val textData1 = printData["textData1"] as? String ?: ""
        val textData2 = printData["textData2"] as? String ?: ""
        val width = (printData["width"] as? Number)?.toDouble() ?: 75.0
        val height = (printData["height"] as? Number)?.toDouble() ?: 60.0 // Increased height for 2 text lines
        val unit = printData["unit"] as? String ?: "mm"
        val dpi = (printData["dpi"] as? Number)?.toInt() ?: 203
        val copies = (printData["copies"] as? Number)?.toInt() ?: 1
        val textSize = (printData["textSize"] as? Number)?.toInt() ?: 9
        
        // Use the core printing method
        printSingleLabelWithGapDetection(qrData, textData1, textData2, "", width, height, unit, dpi, copies, textSize, result)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error printing with protocol: ${e.message}")
        result.error("PROTOCOL_PRINT_ERROR", "Failed to print with protocol: ${e.message}", null)
      }
    }
  }

  // ============================================================================
  // HELPER METHODS - LABEL POSITIONING AND COMMAND BUILDING
  // ============================================================================

  /**
   * Calculate optimal positions for label content
   */
  private fun calculateLabelPositions(
    width: Double,
    height: Double,
    unit: String,
    dpi: Int,
    textSize: Int
  ): Map<String, Int> {
    val widthInDots = convertToDots(dpi, width, unit)
    val heightInDots = convertToDots(dpi, height, unit)
    
    // Calculate margins
    val marginInDots = when {
      width <= 30 -> convertToDots(dpi, 2.0, "mm")
      width <= 60 -> convertToDots(dpi, 3.0, "mm")
      else -> convertToDots(dpi, 4.0, "mm")
    }
    
    val availableWidth = widthInDots - 2 * marginInDots
    val availableHeight = heightInDots - 2 * marginInDots
    
    // Calculate QR size (back to original approach)
    val qrSize = when {
      width <= 30 -> availableWidth * 0.55
      width <= 60 -> availableWidth * 0.6
      else -> availableWidth * 0.65
    }.toInt().coerceAtMost((availableHeight * 0.45).toInt()).coerceAtMost((availableWidth * 0.65).toInt())
    
    // Calculate positions with original approach but optimized for 3 text lines
    val qrX = marginInDots + (availableWidth - qrSize) / 2
    val qrY = marginInDots + (availableHeight * 0.08).toInt() // Original QR position
    
    // Align all text lines to start at the same left position as the QR code
    val textX = qrX // Start text at the same X position as QR code
    
    val textY1 = qrY + qrSize + convertToDots(dpi, 8.0, "mm") // Increased gap after QR
    val textY2 = textY1 + convertToDots(dpi, 4.0, "mm") // Reduced gap between text lines (was 8mm)
    val textY3 = textY2 + convertToDots(dpi, 4.0, "mm") // Third text line with reduced gap
    
    // Ensure text doesn't go beyond label boundaries
    val maxTextY = heightInDots - marginInDots - convertToDots(dpi, 2.0, "mm")
    val adjustedPositions = if (textY3 > maxTextY) {
      // If third text line would go beyond label, adjust all text positions
      val adjustedTextY1 = maxTextY - convertToDots(dpi, 8.0, "mm")
      val adjustedTextY2 = maxTextY - convertToDots(dpi, 4.0, "mm")
      val adjustedTextY3 = maxTextY
      mapOf(
        "qrX" to qrX,
        "qrY" to qrY,
        "textX" to textX,
        "textY1" to adjustedTextY1,
        "textY2" to adjustedTextY2,
        "textY3" to adjustedTextY3
      )
    } else {
      mapOf(
        "qrX" to qrX,
        "qrY" to qrY,
        "textX" to textX,
        "textY1" to textY1,
        "textY2" to textY2,
        "textY3" to textY3
      )
    }
    
    android.util.Log.d("NTBPPlugin", "Label positions: QR($qrX,$qrY) size:$qrSize, Text1($textX,$textY1), Text2($textX,$textY2), Text3($textX,$textY3)")
    return adjustedPositions
  }

  /**
   * Build TSPL commands for single label
   */
  private fun buildSingleLabelCommands(
    qrData: String,
    textData1: String,
    textData2: String,
    positions: Map<String, Int>,
    copies: Int,
    textSize: Int
  ): String {
    android.util.Log.d("NTBPPlugin", "Building commands for QR: $qrData, Text1: $textData1, Text2: $textData2")
    android.util.Log.d("NTBPPlugin", "Using positions: $positions")
    
    return buildString {
      appendLine("CLS")
      appendLine("QRCODE ${positions["qrX"]},${positions["qrY"]},H,10,A,0,\"$qrData\"")
      
      // Add first text line (Customer name)
      if (textData1.isNotEmpty()) {
        appendLine("TEXT ${positions["textX"]},${positions["textY1"]},\"$textSize\",0,1,1,\"$textData1\"")
        android.util.Log.d("NTBPPlugin", "Added text1: TEXT ${positions["textX"]},${positions["textY1"]},\"$textSize\",0,1,1,\"$textData1\"")
      }
      
      // Add second text line (Drop point)
      if (textData2.isNotEmpty()) {
        appendLine("TEXT ${positions["textX"]},${positions["textY2"]},\"$textSize\",0,1,1,\"$textData2\"")
        android.util.Log.d("NTBPPlugin", "Added text2: TEXT ${positions["textX"]},${positions["textY2"]},\"$textSize\",0,1,1,\"$textData2\"")
      }
      
      appendLine("PRINT $copies")
    }
  }

  // ============================================================================
  // UTILITY METHODS - CONVERSION AND BUFFER MANAGEMENT
  // ============================================================================

  /**
   * Convert dimensions to dots
   */
  private fun convertToDots(dpi: Int, value: Double, unit: String): Int {
    val dotsPerMm = dpi / 25.4
    return when (unit.lowercase()) {
      "mm" -> (value * dotsPerMm).toInt()
      "inch" -> (value * dpi).toInt()
      else -> (value * dotsPerMm).toInt()
    }
  }

  /**
   * Send gap detection commands
   */
  private suspend fun sendGapDetectionCommands(labelWidth: Double, labelHeight: Double, unit: String, dpi: Int) {
    try {
      val widthInDots = convertToDots(dpi, labelWidth, unit)
      val heightInDots = convertToDots(dpi, labelHeight, unit)
      
      val gapSize = when {
        labelHeight <= 20 -> convertToDots(dpi, 2.0, "mm")
        labelHeight <= 40 -> convertToDots(dpi, 2.5, "mm")
        else -> convertToDots(dpi, 3.0, "mm")
      }
      
      val commands = buildString {
        appendLine("CLEAR")
        appendLine("SIZE $widthInDots dot,$heightInDots dot")
        appendLine("GAP $gapSize dot,0")
        appendLine("GAPDETECT ON")
        appendLine("AUTODETECT ON")
        appendLine("CLS")
      }
      
      sendCommands(commands.toByteArray().toList())
      
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error sending gap detection commands: ${e.message}")
    }
  }

  /**
   * Clear buffer aggressively
   */
  private suspend fun clearBufferAggressively() {
    try {
      sendCommands("CLEAR".toByteArray().toList())
      delay(150)
      sendCommands("CLS".toByteArray().toList())
      delay(150)
      sendCommands("HOME".toByteArray().toList())
      delay(200)
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error in aggressive buffer clearing: ${e.message}")
    }
  }

  /**
   * Clear buffer completely
   */
  private suspend fun clearBufferCompletely() {
    try {
      sendCommands("CLEAR".toByteArray().toList())
      delay(200)
      sendCommands("CLS".toByteArray().toList())
      delay(150)
      sendCommands("HOME".toByteArray().toList())
      delay(200)
      sendCommands("DIRECTION 0".toByteArray().toList())
      delay(100)
      sendCommands("REFERENCE 0,0".toByteArray().toList())
      delay(100)
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error in complete buffer clearing: ${e.message}")
    }
  }

  // ============================================================================
  // LEGACY METHODS - KEPT FOR BACKWARD COMPATIBILITY
  // ============================================================================

  private fun printCommands(commands: List<Map<*, *>>, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        commands.forEach { command ->
          when {
            command["isBarcode"] == true -> {
              val data = command["barcodeData"] as String
              printBarcodeInternal(data)
            }
            command["isQRCode"] == true -> {
              val data = command["barcodeData"] as String
              printQRCodeInternal(data)
            }
            else -> {
              val text = command["text"] as String
              printTextInternal(text)
            }
          }
        }
        
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_ERROR", "Failed to print: ${e.message}", null)
      }
    }
  }

  private fun printText(text: String, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        printTextInternal(text)
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_TEXT_ERROR", "Failed to print text: ${e.message}", null)
      }
    }
  }

  private fun printBarcode(data: String, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        printBarcodeInternal(data)
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_BARCODE_ERROR", "Failed to print barcode: ${e.message}", null)
      }
    }
  }

  private fun printQRCode(data: String, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        printQRCodeInternal(data)
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_QR_ERROR", "Failed to print QR code: ${e.message}", null)
      }
    }
  }

  private suspend fun printTextInternal(text: String) {
    withContext(Dispatchers.IO) {
      try {
        val commands = "TEXT 50,50,\"9\",0,1,1,\"$text\"\r\n".toByteArray().toList()
        sendCommands(commands)
      } catch (e: IOException) {
        throw e
      }
    }
  }

  private suspend fun printBarcodeInternal(data: String) {
    withContext(Dispatchers.IO) {
      try {
        val commands = "BARCODE 50,100,\"128\",50,1,0,1,1,\"$data\"\r\n".toByteArray().toList()
        sendCommands(commands)
      } catch (e: IOException) {
        throw e
      }
    }
  }

  private suspend fun printQRCodeInternal(data: String) {
    withContext(Dispatchers.IO) {
      try {
        val commands = "QRCODE 50,200,L,5,A,0,\"$data\"\r\n".toByteArray().toList()
        sendCommands(commands)
      } catch (e: IOException) {
        throw e
      }
    }
  }

  private fun clearPrintBuffer(result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        sendCommands("CLEAR".toByteArray().toList())
        result.success(true)
        
      } catch (e: Exception) {
        result.error("CLEAR_BUFFER_ERROR", "Failed to clear buffer: ${e.message}", null)
      }
    }
  }
  
  private fun getPrinterStatus(result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        val statusInfo = mapOf(
          "connected" to true,
          "socketConnected" to (bluetoothSocket?.isConnected == true),
          "hasOutputStream" to (outputStream != null),
          "connectionState" to (if (isConnected()) "CONNECTED" else "DISCONNECTED")
        )
        
        result.success(statusInfo)
        
      } catch (e: Exception) {
        result.error("GET_STATUS_ERROR", "Failed to get printer status: ${e.message}", null)
      }
    }
  }
  
  private fun feedPaper(lines: Int, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        val feedCommand = "FEED $lines"
        sendCommands(feedCommand.toByteArray().toList())
        result.success(true)
        
      } catch (e: Exception) {
        result.error("FEED_PAPER_ERROR", "Failed to feed paper: ${e.message}", null)
      }
    }
  }

  // ============================================================================
  // SIMPLIFIED CONNECTION METHODS
  // ============================================================================

  private fun connectToDevice(address: String, result: Result) {
    coroutineScope.launch {
      try {
        val device = discoveredDevices[address] ?: bluetoothAdapter?.getRemoteDevice(address)
        if (device == null) {
          result.error("DEVICE_NOT_FOUND", "Device not found: $address", null)
          return@launch
        }

        // Simple connection
        val socket = device.createRfcommSocketToServiceRecord(
          java.util.UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        )
        socket.connect()
        
        bluetoothSocket = socket
        outputStream = socket.outputStream
        
        result.success(true)
        
      } catch (e: Exception) {
        result.error("CONNECTION_ERROR", "Failed to connect: ${e.message}", null)
      }
    }
  }

  private fun disconnect(result: Result?) {
    coroutineScope.launch {
      try {
        outputStream?.close()
        bluetoothSocket?.close()
        outputStream = null
        bluetoothSocket = null
        result?.success(true)
      } catch (e: Exception) {
        result?.error("DISCONNECT_ERROR", "Failed to disconnect: ${e.message}", null)
      }
    }
  }

  private fun isConnected(): Boolean {
    return try {
      val socketConnected = bluetoothSocket?.isConnected == true
      val hasOutputStream = outputStream != null
      socketConnected && hasOutputStream
    } catch (e: Exception) {
      false
    }
  }

  // ============================================================================
  // SIMPLIFIED DEVICE DISCOVERY
  // ============================================================================

  private fun startScan(result: Result) {
    if (!isBluetoothAvailableBoolean()) {
      result.error("BLUETOOTH_NOT_AVAILABLE", "Bluetooth is not available or not enabled.", null)
      return
    }

    try {
      // Clear previous discoveries
      discoveredDevices.clear()
      
      // Get paired devices first (these are usually more reliable)
      val pairedDevices = bluetoothAdapter?.bondedDevices ?: emptySet()
      pairedDevices.forEach { device ->
        discoveredDevices[device.address] = device
        android.util.Log.d("NTBPPlugin", "Found paired device: ${device.name} (${device.address})")
      }
      
      // Start discovery for new devices
      try {
        if (bluetoothAdapter?.isDiscovering == true) {
          bluetoothAdapter?.cancelDiscovery()
          Thread.sleep(1000) // Wait for previous discovery to stop
        }
        
        val discoveryStarted = bluetoothAdapter?.startDiscovery()
        if (discoveryStarted == true) {
          android.util.Log.d("NTBPPlugin", "Bluetooth discovery started successfully")
          
          // Wait for discovery to complete (typically 12 seconds)
          coroutineScope.launch {
            delay(12000) // Wait for discovery to complete
            
            // Get final discovered devices
            val totalDevices = discoveredDevices.size
            android.util.Log.d("NTBPPlugin", "Discovery completed. Total devices found: $totalDevices")
            
            // Send success result after discovery completes
            result.success(totalDevices)
          }
        } else {
          android.util.Log.e("NTBPPlugin", "Failed to start Bluetooth discovery")
          result.error("DISCOVERY_FAILED", "Failed to start Bluetooth discovery", null)
        }
      } catch (e: SecurityException) {
        android.util.Log.e("NTBPPlugin", "Permission denied for Bluetooth discovery: ${e.message}")
        result.error("PERMISSION_DENIED", "Bluetooth permission denied: ${e.message}", null)
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error starting discovery: ${e.message}")
        result.error("DISCOVERY_ERROR", "Error starting discovery: ${e.message}", null)
      }
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Failed to start scan: ${e.message}")
      result.error("SCAN_ERROR", "Failed to start scan: ${e.message}", null)
    }
  }

  private fun stopScan(result: Result) {
    try {
      bluetoothAdapter?.cancelDiscovery()
      result.success(null)
    } catch (e: Exception) {
      result.error("STOP_SCAN_ERROR", "Failed to stop scan: ${e.message}", null)
    }
  }

  private fun getDiscoveredDevices(result: Result) {
    val devices = discoveredDevices.values.map { device ->
      mapOf(
        "name" to (device.name ?: "Unknown Device"),
        "address" to device.address,
        "isConnected" to (device.address == bluetoothSocket?.remoteDevice?.address),
        "rssi" to 0,
        "deviceClass" to device.bluetoothClass.toString()
      )
    }
    result.success(devices)
  }

  // ============================================================================
  // CORE UTILITY METHODS
  // ============================================================================

  private fun checkDevicePairingStatus(address: String): String {
    return try {
      val device = discoveredDevices[address] ?: bluetoothAdapter?.getRemoteDevice(address)
      if (device != null) {
        when (device.bondState) {
          BluetoothDevice.BOND_BONDED -> "PAIRED"
          BluetoothDevice.BOND_BONDING -> "PAIRING"
          BluetoothDevice.BOND_NONE -> "NOT_PAIRED"
          else -> "UNKNOWN"
        }
      } else {
        "UNKNOWN"
      }
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error checking pairing status: ${e.message}")
      "UNKNOWN"
    }
  }

  private fun isBluetoothAvailableBoolean(): Boolean {
    return try {
      // Check if Bluetooth is supported
      if (bluetoothAdapter == null) {
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter == null) {
          return false
        }
      }
      
      // Check if Bluetooth is enabled
      if (!bluetoothAdapter!!.isEnabled) {
        return false
      }
      
      return true
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error checking Bluetooth availability: ${e.message}")
      false
    }
  }

  private suspend fun sendCommands(commands: List<Byte>) {
    withContext(Dispatchers.IO) {
      try {
        outputStream?.write(commands.toByteArray())
        outputStream?.flush()
      } catch (e: IOException) {
        throw e
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    disconnect(null)
    coroutineScope.cancel()
  }

  // Broadcast receiver for device discovery
  inner class DiscoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        BluetoothDevice.ACTION_FOUND -> {
          val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
          device?.let {
            discoveredDevices[it.address] = it
            android.util.Log.d("NTBPPlugin", "Discovered device: ${it.name ?: "Unknown"} (${it.address})")
          }
        }
        BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
          android.util.Log.d("NTBPPlugin", "Bluetooth discovery finished")
        }
        BluetoothAdapter.ACTION_DISCOVERY_STARTED -> {
          android.util.Log.d("NTBPPlugin", "Bluetooth discovery started")
        }
      }
    }
  }
} 