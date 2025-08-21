package com.example.ntbp_plugin

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.IOException
import java.io.OutputStream
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.app.Activity

/** NtbpPlugin */
class NtbpPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private var bluetoothAdapter: BluetoothAdapter? = null
  private var bluetoothSocket: BluetoothSocket? = null
  private var outputStream: OutputStream? = null
  private val discoveredDevices = ConcurrentHashMap<String, BluetoothDevice>()
  private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
  private var discoveryReceiver: BroadcastReceiver? = null

  // Permission constants
  companion object {
    private const val BLUETOOTH_PERMISSION_REQUEST = 1001
    private const val LOCATION_PERMISSION_REQUEST = 1002
    private const val BLUETOOTH_CONNECT_PERMISSION_REQUEST = 1003
    private const val BLUETOOTH_SCAN_PERMISSION_REQUEST = 1004
  }
  
  // Required permissions for different Android versions
  private val requiredPermissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    arrayOf(
      Manifest.permission.BLUETOOTH_CONNECT,
      Manifest.permission.BLUETOOTH_SCAN,
      Manifest.permission.ACCESS_FINE_LOCATION,
      Manifest.permission.ACCESS_COARSE_LOCATION
    )
  } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    arrayOf(
      Manifest.permission.ACCESS_FINE_LOCATION,
      Manifest.permission.ACCESS_COARSE_LOCATION
    )
  } else {
    arrayOf<String>()
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ntbp_plugin")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    
    // Initialize Bluetooth adapter
    bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
    
    // Register discovery receiver
    discoveryReceiver = DiscoveryReceiver()
    val filter = IntentFilter().apply {
      addAction(BluetoothDevice.ACTION_FOUND)
      addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
    }
    context.registerReceiver(discoveryReceiver, filter)
    
    // Register pairing state change receiver
    val pairingFilter = IntentFilter().apply {
      addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
    }
    context.registerReceiver(PairingStateReceiver(), pairingFilter)
  }

  private fun initializeBluetooth() {
    val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    bluetoothAdapter = bluetoothManager.adapter
    setupDiscoveryReceiver()
  }

  private fun setupDiscoveryReceiver() {
    discoveryReceiver = object : BroadcastReceiver() {
      override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
          BluetoothDevice.ACTION_FOUND -> {
            val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
            device?.let {
              discoveredDevices[it.address] = it
            }
          }
          BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
            // Discovery finished
          }
        }
      }
    }

    val filter = IntentFilter().apply {
      addAction(BluetoothDevice.ACTION_FOUND)
      addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
    }
    context.registerReceiver(discoveryReceiver, filter)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "isBluetoothAvailable" -> {
        isBluetoothAvailable(result)
      }
      "requestBluetoothPermissions" -> {
        requestBluetoothPermissions(result)
      }
      "checkDevicePairingStatus" -> {
        val address = call.argument<String>("address")
        if (address != null) {
          val device = discoveredDevices[address] ?: bluetoothAdapter?.getRemoteDevice(address)
          if (device != null) {
            val pairingStatus = checkDevicePairingStatus(device)
            result.success(pairingStatus)
    } else {
            result.error("DEVICE_NOT_FOUND", "Device not found", null)
          }
        } else {
          result.error("MISSING_ADDRESS", "Device address is required", null)
        }
      }
      "requestDevicePairing" -> {
        val address = call.argument<String>("address")
        if (address != null) {
          val device = discoveredDevices[address] ?: bluetoothAdapter?.getRemoteDevice(address)
          if (device != null) {
            requestDevicePairing(device, result)
          } else {
            result.error("DEVICE_NOT_FOUND", "Device not found", null)
          }
        } else {
          result.error("MISSING_ADDRESS", "Device address is required", null)
        }
      }
      "requestDevicePairingWithPin" -> {
        val address = call.argument<String>("address")
        val pinCode = call.argument<String>("pinCode")
        if (address != null && pinCode != null) {
          val device = discoveredDevices[address] ?: bluetoothAdapter?.getRemoteDevice(address)
          if (device != null) {
            requestDevicePairingWithPin(device, pinCode, result)
          } else {
            result.error("DEVICE_NOT_FOUND", "Device not found", null)
          }
        } else {
          result.error("MISSING_PARAMETERS", "Device address and PIN code are required", null)
        }
      }
      "getStoredPinCode" -> {
        val address = call.argument<String>("address")
        if (address != null) {
          val pinCode = getStoredPinCode(address)
          result.success(pinCode)
        } else {
          result.error("MISSING_ADDRESS", "Device address is required", null)
        }
      }
      "removeStoredPinCode" -> {
        val address = call.argument<String>("address")
        if (address != null) {
          removeStoredPinCode(address)
          result.success(true)
        } else {
          result.error("MISSING_ADDRESS", "Device address is required", null)
        }
      }
      "getConnectionStatus" -> {
        result.success(connectionState)
      }
      "getDetailedConnectionStatus" -> {
        val socketConnected = bluetoothSocket?.isConnected == true
        val hasOutputStream = outputStream != null
        val socketAddress = bluetoothSocket?.remoteDevice?.address
        val socketName = bluetoothSocket?.remoteDevice?.name
        
        val statusMap = mapOf(
          "connectionState" to connectionState,
          "socketConnected" to socketConnected,
          "hasOutputStream" to hasOutputStream,
          "socketAddress" to socketAddress,
          "socketName" to socketName,
          "isConnectionInProgress" to isConnectionInProgress
        )
        
        result.success(statusMap)
      }
      "getLabelPaperConfig" -> {
        val width = call.argument<Double>("width") ?: 50.0
        val height = call.argument<Double>("height") ?: 30.0
        val unit = call.argument<String>("unit") ?: "mm"
        
        val config = getLabelPaperConfig(width, height, unit)
        val configMap = mapOf(
          "name" to config.name,
          "margin" to config.margin,
          "qrUsagePercent" to config.qrUsagePercent,
          "minQrSize" to config.minQrSize,
          "useMaxDimension" to config.useMaxDimension,
          "description" to config.description
        )
        result.success(configMap)
      }
      "startScan" -> {
        startScan(result)
      }
      "stopScan" -> {
        stopScan(result)
      }
      "getDiscoveredDevices" -> {
        getDiscoveredDevices(result)
      }
      "connectToDevice" -> {
        val deviceMap = call.arguments as Map<*, *>
        val address = deviceMap["address"] as String
        safeConnectToDevice(address, result)
      }
      "disconnect" -> {
        disconnect(result)
      }
      "isConnected" -> {
        result.success(isConnected())
      }
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
      "printTextAdvanced" -> {
        val args = call.arguments as Map<*, *>
        val text = args["text"] as String
        val x = args["x"] as? Double
        val y = args["y"] as? Double
        val fontNumber = args["fontNumber"] as? Int
        val codePage = args["codePage"] as? String
        val rotation = args["rotation"] as? Int
        val xMultiplication = args["xMultiplication"] as? Double
        val yMultiplication = args["yMultiplication"] as? Double
        printTextAdvanced(text, x, y, fontNumber, codePage, rotation, xMultiplication, yMultiplication, result)
      }
      "printBarcodeAdvanced" -> {
        val args = call.arguments as Map<*, *>
        val data = args["data"] as String
        val x = args["x"] as? Double
        val y = args["y"] as? Double
        val rotation = args["rotation"] as? Int
        val codePage = args["codePage"] as? String
        printBarcodeAdvanced(data, x, y, rotation, codePage, result)
      }
      "printQRCodeAdvanced" -> {
        val args = call.arguments as Map<*, *>
        val data = args["data"] as String
        val x = args["x"] as? Double
        val y = args["y"] as? Double
        val size = args["size"] as? String
        val errorCorrection = args["errorCorrection"] as? String
        val model = args["model"] as? String
        val rotation = args["rotation"] as? Int
        printQRCodeAdvanced(data, x, y, size, errorCorrection, model, rotation, result)
      }
      "printImage" -> {
        val args = call.arguments as Map<*, *>
        val imagePath = args["imagePath"] as String
        val x = args["x"] as? Double
        val y = args["y"] as? Double
        val width = args["width"] as? Double
        val height = args["height"] as? Double
        printImage(imagePath, x, y, width, height, result)
      }
      "printBlock" -> {
        val args = call.arguments as Map<*, *>
        val text = args["text"] as String
        val x = args["x"] as? Double
        val y = args["y"] as? Double
        val width = args["width"] as? Double
        val height = args["height"] as? Double
        val lineWidth = args["lineWidth"] as? Int
        val lineStyle = args["lineStyle"] as? Int
        printBlock(text, x, y, width, height, lineWidth, lineStyle, result)
      }
      "setPrintArea" -> {
        val args = call.arguments as Map<*, *>
        val width = args["width"] as Double
        val height = args["height"] as Double
        setPrintArea(width, height, result)
      }
      "clearPrintBuffer" -> {
        clearPrintBuffer(result)
      }
      "executePrint" -> {
        val args = call.arguments as Map<*, *>
        val copies = args["copies"] as Int
        val labels = args["labels"] as Int
        executePrint(copies, labels, result)
      }
      "getPrinterStatus" -> {
        getPrinterStatus(result)
      }
      "printBarcodeWithText" -> {
        val args = call.arguments as Map<*, *>
        val barcodeData = args["barcodeData"] as String
        val textData = args["textData"] as String
        val x = args["x"] as? Double
        val y = args["y"] as? Double
        val barcodeHeight = args["barcodeHeight"] as? Int
        val textFont = args["textFont"] as? Int
        val textScale = args["textScale"] as? Double
        printBarcodeWithText(barcodeData, textData, x, y, barcodeHeight, textFont, textScale, result)
      }
      "printSmartLabel" -> {
        val labelData = call.arguments as Map<String, Any>
        printSmartLabel(labelData, result)
      }
      "printProfessionalLabel" -> {
        val args = call.arguments as Map<String, Any>
        val qrData = args["qrData"] as? String ?: ""
        val textData = args["textData"] as? String ?: ""
        val width = (args["width"] as? Number)?.toDouble() ?: 100.0
        val height = (args["height"] as? Number)?.toDouble() ?: 50.0
        val unit = args["unit"] as? String ?: "mm"
        val dpi = (args["dpi"] as? Number)?.toInt() ?: 203
        val copies = (args["copies"] as? Number)?.toInt() ?: 1
        val speedMode = args["speedMode"] as? String ?: "normal"
        printProfessionalLabel(qrData, textData, width, height, unit, dpi, copies, speedMode, result)
      }
      "printLabelSequence" -> {
        val args = call.arguments as Map<String, Any>
        val labelDataList = args["labelDataList"] as? List<Map<String, Any>> ?: emptyList()
        printLabelSequence(labelDataList, result)
      }
      "printCustomLabel" -> {
        val args = call.arguments as Map<String, Any>
        val qrData = args["qrData"] as String
        val textData = args["textData"] as String
        val width = (args["width"] as? Number)?.toDouble() ?: 50.0
        val height = (args["height"] as? Number)?.toDouble() ?: 30.0
        val unit = args["unit"] as? String ?: "mm"
        val dpi = (args["dpi"] as? Number)?.toInt() ?: 203
        val qrSize = (args["qrSize"] as? Number)?.toDouble() ?: 0.0
        val textSize = (args["textSize"] as? Number)?.toDouble() ?: 0.0
        
        printCustomLabel(qrData, textData, width, height, unit, dpi, qrSize, textSize, result)
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

      "printSmartSequence" -> {
        val labelDataList = call.arguments as List<Map<String, Any>>
        printSmartSequence(labelDataList, result)
      }
      "printSingleLabelWithGapDetection" -> {
        val args = call.arguments as Map<String, Any>
        val qrData = args["qrData"] as String
        val textData = args["textData"] as String
        val width = (args["width"] as? Number)?.toDouble() ?: 75.0
        val height = (args["height"] as? Number)?.toDouble() ?: 50.0
        val unit = args["unit"] as? String ?: "mm"
        val dpi = (args["dpi"] as? Number)?.toInt() ?: 203
        val copies = (args["copies"] as? Number)?.toInt() ?: 1
        val textSize = (args["textSize"] as? Number)?.toInt() ?: 9
        
        printSingleLabelWithGapDetection(qrData, textData, width, height, unit, dpi, copies, textSize, result)
      }
      "printMultipleLabelsWithGapDetection" -> {
        val args = call.arguments as Map<String, Any>
        val labelDataList = args["labelDataList"] as? List<Map<String, Any>> ?: emptyList()
        val width = (args["width"] as? Number)?.toDouble() ?: 75.0
        val height = (args["height"] as? Number)?.toDouble() ?: 50.0
        val unit = args["unit"] as? String ?: "mm"
        val dpi = (args["dpi"] as? Number)?.toInt() ?: 203
        val copiesPerLabel = (args["copiesPerLabel"] as? Number)?.toInt() ?: 1
        val textSize = (args["textSize"] as? Number)?.toInt() ?: 9
        
        printMultipleLabelsWithGapDetection(labelDataList, width, height, unit, dpi, copiesPerLabel, textSize, result)
      }
      else -> {
      result.notImplemented()
      }
    }
  }

  private fun isBluetoothAvailable(result: Result) {
    try {
      // Check if Bluetooth is supported
      if (bluetoothAdapter == null) {
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter == null) {
          result.error("BLUETOOTH_NOT_SUPPORTED", "Bluetooth is not supported on this device", null)
          return
        }
      }
      
      // Check if Bluetooth is enabled
      if (!bluetoothAdapter!!.isEnabled) {
        result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled. Please enable Bluetooth in settings.", null)
        return
      }
      
      // Check permissions
      val permissionStatus = checkAndRequestPermissions()
      if (permissionStatus != "GRANTED") {
        result.error("PERMISSION_REQUIRED", permissionStatus, null)
        return
      }
      
      result.success(true)
    } catch (e: Exception) {
      result.error("BLUETOOTH_CHECK_ERROR", "Error checking Bluetooth availability: ${e.message}", null)
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
      
      // Check permissions
      val permissionStatus = checkAndRequestPermissions()
      permissionStatus == "GRANTED"
    } catch (e: Exception) {
      false
    }
  }
  
  private fun checkAndRequestPermissions(): String {
    // Check if all required permissions are granted
    val missingPermissions = mutableListOf<String>()
    
    for (permission in requiredPermissions) {
      if (ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) {
        missingPermissions.add(permission)
      }
    }
    
    if (missingPermissions.isEmpty()) {
      return "GRANTED"
    }
    
    // Request missing permissions
    if (context is Activity) {
      val activity = context as Activity
      ActivityCompat.requestPermissions(activity, missingPermissions.toTypedArray(), BLUETOOTH_PERMISSION_REQUEST)
      return "REQUESTING_PERMISSIONS"
    } else {
      return "PERMISSIONS_REQUIRED: ${missingPermissions.joinToString(", ")}"
    }
  }
  
  private fun requestBluetoothPermissions(result: Result) {
    try {
      val permissionStatus = checkAndRequestPermissions()
      
      when (permissionStatus) {
        "GRANTED" -> {
          result.success(true)
        }
        "REQUESTING_PERMISSIONS" -> {
          result.success("PERMISSIONS_REQUESTED")
        }
        else -> {
          result.error("PERMISSION_ERROR", permissionStatus, null)
        }
      }
    } catch (e: Exception) {
      result.error("PERMISSION_REQUEST_ERROR", "Error requesting permissions: ${e.message}", null)
    }
  }
  
  private fun checkDevicePairingStatus(device: BluetoothDevice): String {
    return when (device.bondState) {
      BluetoothDevice.BOND_BONDED -> "PAIRED"
      BluetoothDevice.BOND_BONDING -> "PAIRING"
      BluetoothDevice.BOND_NONE -> "NOT_PAIRED"
      else -> "UNKNOWN"
    }
  }
  
  private fun requestDevicePairing(device: BluetoothDevice, result: Result) {
    try {
      when (device.bondState) {
        BluetoothDevice.BOND_BONDED -> {
          result.success("ALREADY_PAIRED")
        }
        BluetoothDevice.BOND_BONDING -> {
          result.success("PAIRING_IN_PROGRESS")
        }
        BluetoothDevice.BOND_NONE -> {
          // Create pairing request
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            device.createBond()
            result.success("PAIRING_REQUESTED")
          } else {
            result.error("PAIRING_NOT_SUPPORTED", "Pairing not supported on this Android version", null)
          }
        }
        else -> {
          result.error("UNKNOWN_BOND_STATE", "Unknown device bonding state", null)
        }
      }
    } catch (e: Exception) {
      result.error("PAIRING_ERROR", "Error requesting device pairing: ${e.message}", null)
    }
  }

  private fun startScan(result: Result) {
    if (!isBluetoothAvailableBoolean()) {
      result.error("BLUETOOTH_NOT_AVAILABLE", "Bluetooth is not available or not enabled.", null)
      return
    }

    try {
      discoveredDevices.clear()
      
      // Get paired devices first (these are usually more reliable)
      val pairedDevices = bluetoothAdapter?.bondedDevices ?: emptySet()
      pairedDevices.forEach { device ->
        discoveredDevices[device.address] = device
      }
      
      // Start discovery for new devices
      try {
        bluetoothAdapter?.startDiscovery()
      } catch (e: SecurityException) {
        // Handle permission issues gracefully
        result.error("PERMISSION_DENIED", "Bluetooth permission denied", null)
        return
      }
      
      result.success(null)
    } catch (e: Exception) {
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

  // Enhanced connection management
  private var connectionState = "DISCONNECTED"
  private var connectionAttempts = 0
  private val maxConnectionAttempts = 5
  private var connectionTimeout = 30000L // 30 seconds
  private var isConnectionInProgress = false
  private var connectionJob: Job? = null
  
  // Connection state management
  private fun updateConnectionState(newState: String) {
    connectionState = newState
    android.util.Log.d("NTBPPlugin", "Connection state changed to: $newState")
  }
  
  // Safe connection with crash prevention
  private fun safeConnectToDevice(address: String, result: Result) {
    if (isConnectionInProgress) {
      result.error("CONNECTION_IN_PROGRESS", "Another connection attempt is already in progress", null)
      return
    }

    isConnectionInProgress = true
    updateConnectionState("CONNECTING")
    var resultSubmitted = false

    try {
      connectionJob?.cancel() // Cancel any existing job
      connectionJob = coroutineScope.launch {
        try {
          withTimeout(connectionTimeout) {
            connectToDeviceInternal(address, result, { resultSubmitted = true })
          }
        } catch (e: TimeoutCancellationException) {
          android.util.Log.e("NTBPPlugin", "Connection timeout after ${connectionTimeout}ms")
          updateConnectionState("TIMEOUT")
          if (!resultSubmitted) {
            result.error("CONNECTION_TIMEOUT", "Connection attempt timed out after ${connectionTimeout}ms", null)
            resultSubmitted = true
          }
        } catch (e: Exception) {
          android.util.Log.e("NTBPPlugin", "Connection error: ${e.message}")
          updateConnectionState("ERROR")
          if (!resultSubmitted) {
            result.error("CONNECTION_ERROR", "Connection failed: ${e.message}", null)
            resultSubmitted = true
          }
        } finally {
          isConnectionInProgress = false
        }
      }
    } catch (e: Exception) {
      isConnectionInProgress = false
      updateConnectionState("ERROR")
      if (!resultSubmitted) {
        result.error("CONNECTION_ERROR", "Failed to initiate connection: ${e.message}", null)
        resultSubmitted = true
      }
    }
  }
  
  // Internal connection method with retry logic
  private suspend fun connectToDeviceInternal(address: String, result: Result, resultSubmitted: (Boolean) -> Unit) {
    try {
      android.util.Log.d("NTBPPlugin", "Attempting to connect to device: $address")
      
      val device = discoveredDevices[address] ?: bluetoothAdapter?.getRemoteDevice(address)
      if (device == null) {
        android.util.Log.e("NTBPPlugin", "Device not found: $address")
        updateConnectionState("DEVICE_NOT_FOUND")
        result.error("DEVICE_NOT_FOUND", "Device not found", null)
        resultSubmitted(false)
        return
      }

      android.util.Log.d("NTBPPlugin", "Found device: ${device.name} (${device.address})")

      // Check device pairing status first
      val pairingStatus = checkDevicePairingStatus(device)
      android.util.Log.d("NTBPPlugin", "Device pairing status: $pairingStatus")
      
      when (pairingStatus) {
        "NOT_PAIRED" -> {
          android.util.Log.w("NTBPPlugin", "Device is not paired, requesting pairing first")
          updateConnectionState("NEEDS_PAIRING")
          result.error("DEVICE_NOT_PAIRED", "Device needs to be paired first. Please pair the device in Bluetooth settings.", null)
          resultSubmitted(false)
          return
        }
        "PAIRING" -> {
          android.util.Log.w("NTBPPlugin", "Device is currently pairing, please wait")
          updateConnectionState("PAIRING_IN_PROGRESS")
          result.error("DEVICE_PAIRING", "Device is currently pairing. Please wait for pairing to complete.", null)
          resultSubmitted(false)
          return
        }
        "PAIRED" -> {
          android.util.Log.d("NTBPPlugin", "Device is paired, proceeding with connection")
        }
        else -> {
          android.util.Log.w("NTBPPlugin", "Unknown pairing status: $pairingStatus")
          updateConnectionState("UNKNOWN_PAIRING_STATUS")
          result.error("UNKNOWN_PAIRING_STATUS", "Unknown device pairing status: $pairingStatus", null)
          resultSubmitted(false)
          return
        }
      }

      // Enhanced connection with multiple strategies
      var connected = false
      var lastError: String? = null
      
      for (attempt in 1..maxConnectionAttempts) {
        try {
          android.util.Log.d("NTBPPlugin", "Connection attempt $attempt of $maxConnectionAttempts")
          
          // Disconnect from current device first
          disconnect(null)
          delay(1000) // Wait for cleanup
          
          // Try different connection strategies
          connected = tryConnectionStrategy(device, attempt)
          
          if (connected) {
            android.util.Log.d("NTBPPlugin", "Successfully connected on attempt $attempt")
            updateConnectionState("CONNECTED")
            result.success(true)
            resultSubmitted(true)
            return
          }
          
        } catch (e: Exception) {
          lastError = e.message
          android.util.Log.e("NTBPPlugin", "Connection attempt $attempt failed: ${e.message}")
          
          if (attempt < maxConnectionAttempts) {
            val delayTime = (attempt * 2000L).coerceAtMost(10000L) // Progressive delay: 2s, 4s, 6s, 8s, 10s
            android.util.Log.d("NTBPPlugin", "Waiting ${delayTime}ms before retry...")
            delay(delayTime)
          }
        }
      }
      
      // All attempts failed
      android.util.Log.e("NTBPPlugin", "All connection attempts failed after $maxConnectionAttempts tries")
      updateConnectionState("FAILED")
      result.error("CONNECTION_FAILED", "Failed to connect after $maxConnectionAttempts attempts. Last error: $lastError", null)
      resultSubmitted(false)
      
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Unexpected error during connection: ${e.message}")
      updateConnectionState("ERROR")
      result.error("CONNECTION_ERROR", "Unexpected error: ${e.message}", null)
      resultSubmitted(false)
    }
  }
  
  // Multiple connection strategies
  private suspend fun tryConnectionStrategy(device: BluetoothDevice, attempt: Int): Boolean {
    return withContext(Dispatchers.IO) {
      try {
        when (attempt) {
          1 -> trySecureConnection(device)
          2 -> tryInsecureConnection(device)
          3 -> tryLegacyConnection(device)
          4 -> tryAlternativeServiceRecord(device)
          5 -> tryFallbackConnection(device)
          else -> false
        }
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Connection strategy $attempt failed: ${e.message}")
        false
      }
    }
  }
  
  // Strategy 1: Secure RFCOMM connection
  private suspend fun trySecureConnection(device: BluetoothDevice): Boolean {
    return withContext(Dispatchers.IO) {
      try {
        android.util.Log.d("NTBPPlugin", "Trying secure RFCOMM connection...")
        val socket = device.createRfcommSocketToServiceRecord(UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"))
        socket.connect()
        bluetoothSocket = socket
        outputStream = socket.outputStream
        android.util.Log.d("NTBPPlugin", "Secure connection successful, output stream created")
        true
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Secure connection failed: ${e.message}")
        false
      }
    }
  }
  
  // Strategy 2: Insecure RFCOMM connection
  private suspend fun tryInsecureConnection(device: BluetoothDevice): Boolean {
    return withContext(Dispatchers.IO) {
      try {
        android.util.Log.d("NTBPPlugin", "Trying insecure RFCOMM connection...")
        val socket = device.createInsecureRfcommSocketToServiceRecord(UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"))
        socket.connect()
        bluetoothSocket = socket
        outputStream = socket.outputStream
        android.util.Log.d("NTBPPlugin", "Insecure connection successful, output stream created")
        true
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Insecure connection failed: ${e.message}")
        false
      }
    }
  }
  
  // Strategy 3: Legacy connection method
  private suspend fun tryLegacyConnection(device: BluetoothDevice): Boolean {
    return withContext(Dispatchers.IO) {
      try {
        android.util.Log.d("NTBPPlugin", "Trying legacy connection method...")
        val socket = device.createRfcommSocketToServiceRecord(null)
        socket.connect()
        bluetoothSocket = socket
        outputStream = socket.outputStream
        android.util.Log.d("NTBPPlugin", "Legacy connection successful, output stream created")
        true
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Legacy connection failed: ${e.message}")
        false
      }
    }
  }
  
  // Strategy 4: Alternative service record
  private suspend fun tryAlternativeServiceRecord(device: BluetoothDevice): Boolean {
    return withContext(Dispatchers.IO) {
      try {
        android.util.Log.d("NTBPPlugin", "Trying alternative service record...")
        val socket = device.createRfcommSocketToServiceRecord(UUID.fromString("00001105-0000-1000-8000-00805F9B34FB"))
        socket.connect()
        bluetoothSocket = socket
        outputStream = socket.outputStream
        android.util.Log.d("NTBPPlugin", "Alternative service record connection successful, output stream created")
        true
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Alternative service record failed: ${e.message}")
        false
      }
    }
  }
  
  // Strategy 5: Fallback connection
  private suspend fun tryFallbackConnection(device: BluetoothDevice): Boolean {
    return withContext(Dispatchers.IO) {
      try {
        android.util.Log.d("NTBPPlugin", "Trying fallback connection...")
        val socket = device.createInsecureRfcommSocketToServiceRecord(null)
        socket.connect()
        bluetoothSocket = socket
        outputStream = socket.outputStream
        android.util.Log.d("NTBPPlugin", "Fallback connection successful, output stream created")
        true
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Fallback connection failed: ${e.message}")
        false
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
    try {
      val socketConnected = bluetoothSocket?.isConnected == true
      val hasOutputStream = outputStream != null
      
      android.util.Log.d("NTBPPlugin", "Connection check - Socket: $socketConnected, OutputStream: $hasOutputStream")
      
      return socketConnected && hasOutputStream
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error checking connection status: ${e.message}")
      return false
    }
  }

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
              val alignment = command["alignment"] as String
              val fontSize = command["fontSize"] as String
              val fontWeight = command["fontWeight"] as String
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
        val commands = mutableListOf<Byte>()
        
        // TSPL Protocol: TEXT command
        // Format: TEXT x,y,"font",rotation,x-multiplication,y-multiplication,content
        commands.addAll("TEXT 50,50,\"9\",0,1,1,\"$text\"\r\n".toByteArray().toList())
        
        outputStream?.write(commands.toByteArray())
        outputStream?.flush()
      } catch (e: IOException) {
        throw e
      }
    }
  }

  private suspend fun printBarcodeInternal(data: String) {
    withContext(Dispatchers.IO) {
      try {
        val commands = mutableListOf<Byte>()
        
        // TSPL Protocol: BARCODE command
        // Format: BARCODE x,y,"type",height,human_readable,rotation,x-multiplication,y-multiplication,content
        commands.addAll("BARCODE 50,100,\"128\",50,1,0,1,1,\"$data\"\r\n".toByteArray().toList())
        
        outputStream?.write(commands.toByteArray())
        outputStream?.flush()
      } catch (e: IOException) {
        throw e
      }
    }
  }

  private suspend fun printQRCodeInternal(data: String) {
    withContext(Dispatchers.IO) {
      try {
        val commands = mutableListOf<Byte>()
        
        // TSPL Protocol: QRCODE command
        // Format: QRCODE x,y,ECC_level,cell_width,mode,rotation,content
        commands.addAll("QRCODE 50,200,L,5,A,0,\"$data\"\r\n".toByteArray().toList())
        
        outputStream?.write(commands.toByteArray())
        outputStream?.flush()
      } catch (e: IOException) {
        throw e
      }
    }
  }

  // Advanced printing methods
  private fun printTextAdvanced(
    text: String,
    x: Double?,
    y: Double?,
    fontNumber: Int?,
    codePage: String?,
    rotation: Int?,
    xMultiplication: Double?,
    yMultiplication: Double?,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        val posX = x?.toInt() ?: 50
        val posY = y?.toInt() ?: 50
        val font = fontNumber ?: 9
        val rot = rotation ?: 0
        val xMult = xMultiplication?.toInt() ?: 1
        val yMult = yMultiplication?.toInt() ?: 1

        // TSPL Protocol: TEXT command with parameters
        val command = "TEXT $posX,$posY,\"$font\",$rot,$xMult,$yMult,\"$text\"\r\n"
        
        sendCommands(command.toByteArray().toList())
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_TEXT_ADVANCED_ERROR", "Failed to print advanced text: ${e.message}", null)
      }
    }
  }

  private fun printBarcodeAdvanced(
    data: String,
    x: Double?,
    y: Double?,
    rotation: Int?,
    codePage: String?,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        val posX = x?.toInt() ?: 50
        val posY = y?.toInt() ?: 100
        val rot = rotation ?: 0

        // TSPL Protocol: BARCODE command with parameters
        // Format: BARCODE x,y,"type",height,human_readable,rotation,x-multiplication,y-multiplication,content
        val command = "BARCODE $posX,$posY,\"128\",50,1,$rot,1,1,\"$data\"\r\n"
        
        sendCommands(command.toByteArray().toList())
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_BARCODE_ADVANCED_ERROR", "Failed to print advanced barcode: ${e.message}", null)
      }
    }
  }

  private fun printQRCodeAdvanced(
    data: String,
    x: Double?,
    y: Double?,
    size: String?,
    errorCorrection: String?,
    model: String?,
    rotation: Int?,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        val posX = x?.toInt() ?: 50
        val posY = y?.toInt() ?: 200
        val qrSize = size ?: "L"
        val qrErrorCorrection = errorCorrection ?: "5"
        val rot = rotation ?: 0

        // TSPL Protocol: QRCODE command with parameters
        // Format: QRCODE x,y,ECC_level,cell_width,mode,rotation,content
        val command = "QRCODE $posX,$posY,$qrSize,$qrErrorCorrection,A,$rot,\"$data\"\r\n"
        
        sendCommands(command.toByteArray().toList())
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_QR_ADVANCED_ERROR", "Failed to print advanced QR code: ${e.message}", null)
      }
    }
  }

  // New method for combined barcode + text printing
  private fun printBarcodeWithText(
    barcodeData: String,
    textData: String,
    x: Double?,
    y: Double?,
    barcodeHeight: Int?,
    textFont: Int?,
    textScale: Double?,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        val posX = x?.toInt() ?: 10
        val posY = y?.toInt() ?: 10
        val height = barcodeHeight ?: 50
        val font = textFont ?: 3
        val scale = textScale ?: 1.0

        // Print barcode first
        val barcodeCommand = "BARCODE $posX,$posY,\"128\",$height,1,0,1,1,\"$barcodeData\"\r\n"
        sendCommands(barcodeCommand.toByteArray().toList())
        
        // Print text below barcode
        val textY = posY + height + 10
        val textCommand = "TEXT $posX,$textY,\"3\",0,${scale.toInt()},${scale.toInt()},\"$textData\"\r\n"
        sendCommands(textCommand.toByteArray().toList())
        
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_BARCODE_WITH_TEXT_ERROR", "Failed to print barcode with text: ${e.message}", null)
      }
    }
  }

  // New method for smart label printing with auto-positioning
  private fun printSmartLabel(
    labelData: Map<String, Any>,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        val width = labelData["width"] as? Double ?: 100.0
        val height = labelData["height"] as? Double ?: 50.0
        val title = labelData["title"] as? String ?: ""
        val barcodeData = labelData["barcode"] as? String ?: ""
        val description = labelData["description"] as? String ?: ""
        val footer = labelData["footer"] as? String ?: ""

        // Set print area
        val sizeCommand = "SIZE ${width.toInt()},${height.toInt()}\r\n"
        sendCommands(sizeCommand.toByteArray().toList())

        // Clear buffer
        val clearCommand = "CLS\r\n"
        sendCommands(clearCommand.toByteArray().toList())

        // Print title (centered at top)
        if (title.isNotEmpty()) {
          val titleX = (width / 2).toInt()
          val titleCommand = "TEXT $titleX,10,\"8\",0,2,2,\"$title\"\r\n"
          sendCommands(titleCommand.toByteArray().toList())
        }

        // Print description (left-aligned below title)
        if (description.isNotEmpty()) {
          val descCommand = "TEXT 10,30,\"5\",0,1,1,\"$description\"\r\n"
          sendCommands(descCommand.toByteArray().toList())
        }

        // Print barcode (centered)
        if (barcodeData.isNotEmpty()) {
          val barcodeX = (width / 2 - 25).toInt()
          val barcodeY = (height / 2).toInt()
          val barcodeCommand = "BARCODE $barcodeX,$barcodeY,\"128\",40,1,0,1,1,\"$barcodeData\"\r\n"
          sendCommands(barcodeCommand.toByteArray().toList())
          
          // Print barcode text below
          val textY = barcodeY + 50
          val textCommand = "TEXT $barcodeX,$textY,\"3\",0,1,1,\"$barcodeData\"\r\n"
          sendCommands(textCommand.toByteArray().toList())
        }

        // Print footer (bottom)
        if (footer.isNotEmpty()) {
          val footerY = (height - 15).toInt()
          val footerCommand = "TEXT 10,$footerY,\"3\",0,1,1,\"$footer\"\r\n"
          sendCommands(footerCommand.toByteArray().toList())
        }

        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_SMART_LABEL_ERROR", "Failed to print smart label: ${e.message}", null)
      }
    }
  }

  private fun printImage(
    imagePath: String,
    x: Double?,
    y: Double?,
    width: Double?,
    height: Double?,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        // For now, implement basic image printing
        // In a full implementation, you would decode the image and convert to printer format
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_IMAGE_ERROR", "Failed to print image: ${e.message}", null)
      }
    }
  }

  private fun printBlock(
    text: String,
    x: Double?,
    y: Double?,
    width: Double?,
    height: Double?,
    lineWidth: Int?,
    lineStyle: Int?,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        val posX = x?.toInt() ?: 10
        val posY = y?.toInt() ?: 10
        val blockWidth = width?.toInt() ?: 200
        val blockHeight = height?.toInt() ?: 100
        val lineW = lineWidth ?: 0
        val lineS = lineStyle ?: 0

        // TSPL Protocol: BOX command for drawing rectangles
        val boxCommand = "BOX $posX,$posY,${posX + blockWidth},${posY + blockHeight},$lineW\r\n"
        val textCommand = "TEXT ${posX + 10},${posY + 10},\"9\",0,1,1,\"$text\"\r\n"
        
        sendCommands(boxCommand.toByteArray().toList())
        sendCommands(textCommand.toByteArray().toList())
        result.success(true)
      } catch (e: Exception) {
        result.error("PRINT_BLOCK_ERROR", "Failed to print block: ${e.message}", null)
      }
    }
  }

  private fun setPrintArea(width: Double, height: Double, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        // TSPL Protocol: SIZE command to set label dimensions
        val command = "SIZE ${width.toInt()},${height.toInt()}\r\n"
        
        sendCommands(command.toByteArray().toList())
        result.success(true)
      } catch (e: Exception) {
        result.error("SET_PRINT_AREA_ERROR", "Failed to set print area: ${e.message}", null)
      }
    }
  }

  // Buffer management and printer control methods
  private fun clearPrintBuffer(result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        // Send CLEAR command to clear buffer
        sendCommands("CLEAR".toByteArray().toList())
        android.util.Log.d("NTBPPlugin", "Print buffer cleared successfully")
        result.success(true)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error clearing buffer: ${e.message}")
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
        
        // Send STATUS command to get printer status
        sendCommands("STATUS".toByteArray().toList())
        
        // For now, return basic status info
        val statusInfo = mapOf(
          "connected" to true,
          "socketConnected" to (bluetoothSocket?.isConnected == true),
          "hasOutputStream" to (outputStream != null),
          "connectionState" to connectionState
        )
        
        result.success(statusInfo)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error getting printer status: ${e.message}")
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
        
        // Feed paper by specified number of lines
        val feedCommand = "FEED $lines"
        sendCommands(feedCommand.toByteArray().toList())
        
        android.util.Log.d("NTBPPlugin", "Paper fed by $lines lines")
        result.success(true)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error feeding paper: ${e.message}")
        result.error("FEED_PAPER_ERROR", "Failed to feed paper: ${e.message}", null)
      }
    }
  }

  private fun executePrint(copies: Int, labels: Int, result: Result) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        // TSPL Protocol: PRINT command to execute the print job
        val command = "PRINT $copies,$labels\r\n"
        
        sendCommands(command.toByteArray().toList())
        result.success(true)
      } catch (e: Exception) {
        result.error("EXECUTE_PRINT_ERROR", "Failed to execute print: ${e.message}", null)
      }
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
    
    // Unregister receivers
    discoveryReceiver?.let { context.unregisterReceiver(it) }
    discoveryReceiver = null
    
    // Clean up resources
    disconnect(null)
    coroutineScope.cancel()
  }

  // PIN code handling for secure pairing
  private val devicePinCodes = mutableMapOf<String, String>()
  private val pairingCallbacks = mutableMapOf<String, (Boolean, String?) -> Unit>()
  
  // Request device pairing with PIN code
  private fun requestDevicePairingWithPin(
    device: BluetoothDevice, 
    pinCode: String, 
    result: Result
  ) {
    try {
      when (device.bondState) {
        BluetoothDevice.BOND_BONDED -> {
          result.success("ALREADY_PAIRED")
        }
        BluetoothDevice.BOND_BONDING -> {
          result.success("PAIRING_IN_PROGRESS")
        }
        BluetoothDevice.BOND_NONE -> {
          // Store PIN code for this device
          devicePinCodes[device.address] = pinCode
          
          // Create pairing request with PIN
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            // Set up pairing callback
            pairingCallbacks[device.address] = { success, error ->
              if (success) {
                android.util.Log.d("NTBPPlugin", "Device ${device.address} paired successfully with PIN")
                result.success("PAIRING_SUCCESSFUL")
              } else {
                android.util.Log.e("NTBPPlugin", "Device ${device.address} pairing failed: $error")
                result.error("PAIRING_FAILED", error ?: "Unknown pairing error", null)
              }
              pairingCallbacks.remove(device.address)
            }
            
            // Start pairing process
            device.createBond()
            result.success("PAIRING_WITH_PIN_REQUESTED")
          } else {
            result.error("PAIRING_NOT_SUPPORTED", "PIN pairing not supported on this Android version", null)
          }
        }
        else -> {
          result.error("UNKNOWN_BOND_STATE", "Unknown device bonding state", null)
        }
      }
    } catch (e: Exception) {
      result.error("PAIRING_ERROR", "Error requesting device pairing with PIN: ${e.message}", null)
    }
  }
  
  // Handle pairing state changes
  private fun handlePairingStateChange(device: BluetoothDevice, bondState: Int) {
    val deviceAddress = device.address
    
    when (bondState) {
      BluetoothDevice.BOND_BONDED -> {
        android.util.Log.d("NTBPPlugin", "Device $deviceAddress paired successfully")
        val callback = pairingCallbacks[deviceAddress]
        callback?.invoke(true, null)
      }
      BluetoothDevice.BOND_NONE -> {
        android.util.Log.d("NTBPPlugin", "Device $deviceAddress pairing failed or cancelled")
        val callback = pairingCallbacks[deviceAddress]
        callback?.invoke(false, "Pairing failed or cancelled")
      }
    }
  }
  
  // Get stored PIN code for a device
  private fun getStoredPinCode(deviceAddress: String): String? {
    return devicePinCodes[deviceAddress]
  }
  
  // Remove stored PIN code for a device
  private fun removeStoredPinCode(deviceAddress: String) {
    devicePinCodes.remove(deviceAddress)
  }

  // Broadcast receiver for pairing state changes
  inner class PairingStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
          val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
          val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
          
          device?.let { handlePairingStateChange(it, bondState) }
        }
      }
    }
  }
  
  // Broadcast receiver for device discovery
  inner class DiscoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        BluetoothDevice.ACTION_FOUND -> {
          val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
          device?.let {
            discoveredDevices[it.address] = it
          }
        }
        BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
          // Discovery finished
        }
      }
    }
  }

  // Professional label printing system
  data class LabelPaperConfig(
    val name: String,
    val margin: Double,
    val qrUsagePercent: Double,
    val minQrSize: Int,
    val useMaxDimension: Boolean,
    val description: String
  )
  
  data class LabelData(
    val qrData: String,
    val textData: String,
    val width: Double,
    val height: Double,
    val unit: String,
    val dpi: Int,
    val copies: Int,
    val speedMode: String
  )
  
  // Get paper configuration based on dimensions
  private fun getLabelPaperConfig(width: Double, height: Double, unit: String): LabelPaperConfig {
    val paperArea = width * height
    
    return when {
      paperArea < 1000 -> LabelPaperConfig(
        name = "Tiny",
        margin = 2.0,
        qrUsagePercent = 0.7,
        minQrSize = 60,
        useMaxDimension = false,
        description = "< 1000mm² (e.g., 25x40mm)"
      )
      paperArea < 2000 -> LabelPaperConfig(
        name = "Small",
        margin = 3.0,
        qrUsagePercent = 0.8,
        minQrSize = 80,
        useMaxDimension = false,
        description = "1000-2000mm² (e.g., 40x30mm)"
      )
      paperArea < 4000 -> LabelPaperConfig(
        name = "Medium",
        margin = 4.0,
        qrUsagePercent = 0.85,
        minQrSize = 100,
        useMaxDimension = false,
        description = "2000-4000mm² (e.g., 50x50mm)"
      )
      else -> LabelPaperConfig(
        name = "Large",
        margin = 5.0,
        qrUsagePercent = 0.9,
        minQrSize = 120,
        useMaxDimension = true,
        description = "≥ 4000mm² (e.g., 80x60mm)"
      )
    }
  }
  
  // Calculate QR size based on paper configuration
  private fun calculateLabelQrSize(
    minDimension: Int,
    maxDimension: Int,
    heightInDots: Int,
    config: LabelPaperConfig,
    minQrSize: Int
  ): Int {
    val qrSize = if (config.useMaxDimension) {
      // For large labels, be more flexible with rectangular labels
      kotlin.math.min((maxDimension * config.qrUsagePercent).toInt(), maxDimension)
    } else {
      // For smaller labels, use minimum dimension
      (minDimension * config.qrUsagePercent).toInt()
    }
    
    // Apply minimum constraint
    return qrSize.coerceAtLeast(minQrSize)
  }
  
  // Calculate cell width for QR code
  private fun calculateQrLabelCellWidth(qrSize: Int, baseCellWidth: Int): Int {
    return when {
      qrSize < 150 -> baseCellWidth.coerceIn(6, 8) // Very small QR codes
      qrSize < 200 -> baseCellWidth.coerceIn(8, 12) // Small QR codes
      qrSize < 300 -> baseCellWidth.coerceIn(12, 14) // Medium QR codes
      qrSize < 500 -> baseCellWidth.coerceIn(12, 16) // Large QR codes
      else -> baseCellWidth.coerceIn(14, 18) // Very large QR codes
    }
  }
  
  // Convert dimensions to dots
  private fun convertToDots(dpi: Int, value: Double, unit: String): Int {
    val dotsPerMm = dpi / 25.4
    return when (unit.lowercase()) {
      "mm" -> (value * dotsPerMm).toInt()
      "inch" -> (value * dpi).toInt()
      else -> (value * dotsPerMm).toInt() // Default to mm
    }
  }
  
  // Print professional label with smart positioning
  private fun printProfessionalLabel(
    qrData: String,
    textData: String,
    labelWidth: Double,
    labelHeight: Double,
    labelUnit: String,
    dpi: Int,
    copies: Int,
    speedMode: String,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        android.util.Log.d("NTBPPlugin", "Starting professional label print...")
        android.util.Log.d("NTBPPlugin", "Parameters: width=$labelWidth, height=$labelHeight, unit=$labelUnit, dpi=$dpi, copies=$copies, speedMode=$speedMode")
        
        if (!isConnected()) {
          android.util.Log.e("NTBPPlugin", "Not connected to printer")
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        android.util.Log.d("NTBPPlugin", "Connection verified, proceeding with print...")
        
        // Get paper configuration
        val paperConfig = getLabelPaperConfig(labelWidth, labelHeight, labelUnit)
        android.util.Log.d("NTBPPlugin", "Paper config: ${paperConfig.name} - ${paperConfig.description}")
        
        // Convert dimensions to dots
        val widthInDots = convertToDots(dpi, labelWidth, labelUnit)
        val heightInDots = convertToDots(dpi, labelHeight, labelUnit)
        android.util.Log.d("NTBPPlugin", "Dimensions in dots: width=$widthInDots, height=$heightInDots")
        
        // Calculate margins (dynamic based on label size)
        val marginInDots = when {
          labelWidth <= 30 -> convertToDots(dpi, 2.0, "mm") // Small labels: 2mm margin
          labelWidth <= 60 -> convertToDots(dpi, 3.0, "mm") // Medium labels: 3mm margin
          else -> convertToDots(dpi, 4.0, "mm") // Large labels: 4mm margin
        }
        
        val availableWidth = widthInDots - 2 * marginInDots
        val availableHeight = heightInDots - 2 * marginInDots
        android.util.Log.d("NTBPPlugin", "Margins: $marginInDots dots, Available: ${availableWidth}x${availableHeight}")
        
        // Calculate QR size (proportional to label size)
        val qrSize = when {
          labelWidth <= 30 -> (availableWidth * 0.6).toInt() // Small labels: 60% of width
          labelWidth <= 60 -> (availableWidth * 0.7).toInt() // Medium labels: 70% of width
          else -> (availableWidth * 0.8).toInt() // Large labels: 80% of width
        }.coerceAtMost((availableHeight * 0.8).toInt()).coerceAtMost((availableWidth * 0.8).toInt())
        
        android.util.Log.d("NTBPPlugin", "QR size calculated: $qrSize dots")
        
        // Calculate cell width for QR code
        val cellWidth = when (speedMode.lowercase()) {
          "fast" -> 8
          "highspeed" -> 6
          else -> 10 // normal
        }
        
        // Calculate positions (properly centered)
        val qrX = marginInDots + (availableWidth - qrSize) / 2 // Center horizontally
        val qrY = marginInDots + (availableHeight - qrSize) / 2 - (qrSize * 0.1).toInt() // Slightly above center
        
        // Text positioning below QR code
        val textX = marginInDots + 10
        val textY = qrY + qrSize + 15 // Below QR code with proper spacing
        
        android.util.Log.d("NTBPPlugin", "Positions calculated: QR($qrX,$qrY), Text($textX,$textY)")
        
        // Build TSPL commands with proper buffer management
        val commands = buildString {
          appendLine("CLEAR") // Clear buffer first
          appendLine("SIZE $widthInDots,$heightInDots") // Set label size
          appendLine("GAP 0,0") // No gap between labels
          appendLine("DENSITY 12") // Print density
          appendLine("SET REPRINT OFF") // Disable reprint
          appendLine("CLS") // Clear screen
          
          // Add QR code with proper positioning
          appendLine("QRCODE $qrX,$qrY,H,$cellWidth,A,0,\"$qrData\"")
          
          // Add text below QR code with proper font and size
          appendLine("TEXT $textX,$textY,\"9\",0,1,1,\"$textData\"")
          
          // Print single copy and cut
          appendLine("PRINT 1")
          appendLine("CUT")
        }
        
        android.util.Log.d("NTBPPlugin", "Generated TSPL commands for ${paperConfig.name} label")
        android.util.Log.d("NTBPPlugin", "QR: ${qrSize}dots at ($qrX,$qrY), Cell: $cellWidth")
        android.util.Log.d("NTBPPlugin", "Text at ($textX,$textY)")
        android.util.Log.d("NTBPPlugin", "Commands length: ${commands.length} characters")
        
        // Send commands
        android.util.Log.d("NTBPPlugin", "Sending commands to printer...")
        sendCommands(commands.toByteArray().toList())
        android.util.Log.d("NTBPPlugin", "Commands sent successfully!")
        
        result.success(true)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error printing professional label: ${e.message}")
        android.util.Log.e("NTBPPlugin", "Stack trace: ${e.stackTraceToString()}")
        result.error("PRINT_LABEL_ERROR", "Failed to print label: ${e.message}", null)
      }
    }
  }
  
  // Print sequence of labels with proper frame management
  private fun printLabelSequence(labelDataList: List<Map<String, Any>>, result: Result) {
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
        
        android.util.Log.d("NTBPPlugin", "Starting sequence print of ${labelDataList.size} labels")
        
        var successCount = 0
        var failureCount = 0
        
        // Clear buffer first
        sendCommands("CLEAR".toByteArray().toList())
        delay(100) // Small delay for buffer clear
        
        for ((index, labelData) in labelDataList.withIndex()) {
          try {
            val qrData = labelData["qrData"] as? String ?: "Label${index + 1}"
            val textData = labelData["textData"] as? String ?: "Text${index + 1}"
            val width = when (labelData["width"]) {
              is Int -> (labelData["width"] as Int).toDouble()
              is Double -> labelData["width"] as Double
              is Number -> (labelData["width"] as Number).toDouble()
              else -> 50.0
            }
            val height = when (labelData["height"]) {
              is Int -> (labelData["height"] as Int).toDouble()
              is Double -> labelData["height"] as Double
              is Number -> (labelData["height"] as Number).toDouble()
              else -> 30.0
            }
            val unit = labelData["unit"] as? String ?: "mm"
            val dpi = when (labelData["dpi"]) {
              is Int -> labelData["dpi"] as Int
              is Number -> (labelData["dpi"] as Number).toInt()
              else -> 203
            }
            
            android.util.Log.d("NTBPPlugin", "Printing label ${index + 1}: ${width}x${height} $unit")
            
            // Convert dimensions to dots
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
            
            // Calculate QR size
            val qrSize = when {
              width <= 30 -> availableWidth * 0.6
              width <= 60 -> availableWidth * 0.7
              else -> availableWidth * 0.8
            }.toInt().coerceAtMost((availableHeight * 0.8).toInt()).coerceAtMost((availableWidth * 0.8).toInt())
            
            // Calculate positions
            val qrX = marginInDots + (availableWidth - qrSize) / 2
            val qrY = marginInDots + (availableHeight - qrSize) / 2 - (qrSize * 0.1).toInt()
            val textX = marginInDots + 10
            val textY = qrY + qrSize + 15
            
            // Build TSPL commands for this label
            val commands = buildString {
              appendLine("SIZE $widthInDots,$heightInDots")
              appendLine("GAP 0,0")
              appendLine("DENSITY 12")
              appendLine("SET REPRINT OFF")
              appendLine("CLS")
              appendLine("QRCODE $qrX,$qrY,H,10,A,0,\"$qrData\"")
              appendLine("TEXT $textX,$textY,\"9\",0,1,1,\"$textData\"")
              appendLine("PRINT 1")
            }
            
            // Send commands for this label
            sendCommands(commands.toByteArray().toList())
            
            // Wait for print completion (important for frame management)
            delay(500) // 500ms delay between labels
            
            android.util.Log.d("NTBPPlugin", "Label ${index + 1} printed successfully")
            successCount++
            
          } catch (e: Exception) {
            android.util.Log.e("NTBPPlugin", "Error printing label ${index + 1}: ${e.message}")
            failureCount++
          }
        }
        
        // Final cut command
        sendCommands("CUT".toByteArray().toList())
        
        android.util.Log.d("NTBPPlugin", "Sequence print completed: $successCount successful, $failureCount failed")
        
        if (failureCount == 0) {
          result.success(true)
        } else {
          result.success(false)
        }
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error in sequence printing: ${e.message}")
        result.error("SEQUENCE_PRINT_ERROR", "Failed to print sequence: ${e.message}", null)
      }
    }
  }
  
  // Print individual label (helper method)
  private suspend fun printIndividualLabel(
    qrData: String,
    textData: String,
    width: Double,
    height: Double,
    unit: String,
    dpi: Int,
    copies: Int,
    speedMode: String
  ): Boolean {
    return try {
      // Get paper configuration
      val paperConfig = getLabelPaperConfig(width, height, unit)
      
      // Convert dimensions to dots
      val widthInDots = convertToDots(dpi, width, unit)
      val heightInDots = convertToDots(dpi, height, unit)
      
      // Calculate margins and QR size
      val marginInDots = convertToDots(dpi, paperConfig.margin, "mm")
      val availableWidth = widthInDots - 2 * marginInDots
      val availableHeight = heightInDots - 2 * marginInDots
      
      val minDimension = kotlin.math.min(availableWidth, availableHeight)
      val maxDimension = kotlin.math.max(availableWidth, availableHeight)
      val qrSize = calculateLabelQrSize(minDimension, maxDimension, heightInDots, paperConfig, paperConfig.minQrSize)
      
      val baseCellWidth = when (speedMode.lowercase()) {
        "fast" -> 10
        "highspeed" -> 8
        else -> 12
      }
      val cellWidth = calculateQrLabelCellWidth(qrSize, baseCellWidth)
      
      // Calculate positions
      val qrX = marginInDots + (availableWidth - qrSize) / 2
      val qrY = marginInDots + (availableHeight - qrSize) / 2 - 20
      val textX = marginInDots + 10
      val textY = qrY + qrSize + 20
      
      // Build TSPL commands
      val commands = buildString {
        appendLine("CLEAR")
        appendLine("SIZE $widthInDots,$heightInDots")
        appendLine("GAP 0,0")
        appendLine("DENSITY 12")
        appendLine("SET REPRINT ON")
        appendLine("CLS")
        appendLine("QRCODE $qrX,$qrY,H,$cellWidth,A,0,\"$qrData\"")
        appendLine("TEXT $textX,$textY,\"9\",0,1,1,\"$textData\"")
        appendLine("PRINT $copies")
        appendLine("CUT")
      }
      
      // Send commands
      sendCommands(commands.toByteArray().toList())
      true
      
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error printing individual label: ${e.message}")
      false
    }
  }

  private fun printCustomLabel(
    qrData: String,
    textData: String,
    width: Double,
    height: Double,
    unit: String,
    dpi: Int,
    qrSize: Double,
    textSize: Double,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }

        // Get paper configuration
        val paperConfig = getLabelPaperConfig(width, height, unit)
        val widthInDots = convertToDots(dpi, width, unit)
        val heightInDots = convertToDots(dpi, height, unit)

        // Calculate margins
        val marginInDots = convertToDots(dpi, paperConfig.margin, "mm")
        val availableWidth = widthInDots - 2 * marginInDots
        val availableHeight = heightInDots - 2 * marginInDots

        // Determine QR size and cell width
        val calculatedQrSize = if (qrSize > 0) {
          qrSize.toInt().coerceAtMost((kotlin.math.min(availableWidth, availableHeight) * 0.8).toInt()).coerceAtMost((availableWidth * 0.8).toInt())
        } else {
          calculateLabelQrSize(kotlin.math.min(availableWidth, availableHeight), kotlin.math.max(availableWidth, availableHeight), heightInDots, paperConfig, paperConfig.minQrSize)
        }

        val baseCellWidth = when (paperConfig.name.lowercase()) {
          "fast", "highspeed" -> 8
          else -> 10
        }
        val cellWidth = calculateQrLabelCellWidth(calculatedQrSize, baseCellWidth)

        // Determine text size
        val textScale = if (textSize > 0) {
          textSize
        } else {
          1.0
        }

        // Calculate positions
        val qrX = marginInDots + (availableWidth - calculatedQrSize) / 2
        val qrY = marginInDots + (availableHeight - calculatedQrSize) / 2 - (calculatedQrSize * 0.1).toInt()
        val textX = marginInDots + 10
        val textY = qrY + calculatedQrSize + 15

        // Build TSPL commands
        val commands = buildString {
          appendLine("CLEAR")
          appendLine("SIZE $widthInDots,$heightInDots")
          appendLine("GAP 0,0")
          appendLine("DENSITY 12")
          appendLine("SET REPRINT ON")
          appendLine("CLS")
          appendLine("QRCODE $qrX,$qrY,H,$cellWidth,A,0,\"$qrData\"")
          appendLine("TEXT $textX,$textY,\"9\",0,${textScale.toInt()},${textScale.toInt()},\"$textData\"")
          appendLine("PRINT 1")
          appendLine("CUT")
        }

        sendCommands(commands.toByteArray().toList())
        result.success(true)

      } catch (e: Exception) {
        result.error("PRINT_CUSTOM_LABEL_ERROR", "Failed to print custom label: ${e.message}", null)
      }
    }
    }
  
  // Enhanced buffer clearing with multiple strategies
  // Java equivalent: HPRTPrinterHelper.CLS();
  // This method provides comprehensive buffer clearing to prevent content bleeding
  private suspend fun clearBufferAggressively() {
    try {
      // Strategy 1: Multiple clearing commands
      sendCommands("CLEAR".toByteArray().toList())
      Thread.sleep(150)
      sendCommands("CLS".toByteArray().toList())
      Thread.sleep(150)
      
      // Strategy 2: Reset printer position
      sendCommands("HOME".toByteArray().toList())
      Thread.sleep(200)
      
      // Strategy 3: Flush with empty commands
      sendCommands("".toByteArray().toList())
      Thread.sleep(100)
      
      android.util.Log.d("NTBPPlugin", "Aggressive buffer clearing completed")
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error in aggressive buffer clearing: ${e.message}")
    }
  }
  
  // Additional comprehensive buffer clearing for critical printing operations
  // Java equivalent: Multiple HPRTPrinterHelper calls for complete buffer reset
  private suspend fun clearBufferCompletely() {
    try {
      android.util.Log.d("NTBPPlugin", "Starting complete buffer clearing...")
      
      // Step 1: Clear all buffers and memory
      sendCommands("CLEAR".toByteArray().toList())
      Thread.sleep(200)
      
      // Step 2: Clear screen and reset position
      sendCommands("CLS".toByteArray().toList())
      Thread.sleep(150)
      
      // Step 3: Reset printer to home position
      sendCommands("HOME".toByteArray().toList())
      Thread.sleep(200)
      
      // Step 4: Reset print direction and reference
      sendCommands("DIRECTION 0".toByteArray().toList())
      Thread.sleep(100)
      sendCommands("REFERENCE 0,0".toByteArray().toList())
      Thread.sleep(100)
      
      // Step 5: Flush with empty commands to ensure complete clearing
      sendCommands("".toByteArray().toList())
      Thread.sleep(100)
      
      android.util.Log.d("NTBPPlugin", "Complete buffer clearing finished")
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error in complete buffer clearing: ${e.message}")
    }
  }
  
  // Enhanced TSPL commands for gap detection and label positioning
  private suspend fun sendGapDetectionCommands(labelWidth: Double, labelHeight: Double, unit: String, dpi: Int) {
    try {
      // Convert dimensions to dots for TSPL commands
      val widthInDots = convertToDots(dpi, labelWidth, unit)
      val heightInDots = convertToDots(dpi, labelHeight, unit)
      
      // Calculate gap size (typically 2-3mm for labels)
      val gapSize = when {
        labelHeight <= 20 -> convertToDots(dpi, 2.0, "mm") // Small labels: 2mm gap
        labelHeight <= 40 -> convertToDots(dpi, 2.5, "mm") // Medium labels: 2.5mm gap
        else -> convertToDots(dpi, 3.0, "mm") // Large labels: 3mm gap
      }
      
      val commands = buildString {
        appendLine("CLEAR") // Clear buffer first
        appendLine("SIZE $widthInDots dot,$heightInDots dot") // Set label size in dots
        appendLine("GAP $gapSize dot,0") // Set gap between labels
        appendLine("GAPDETECT ON") // Enable gap detection
        appendLine("AUTODETECT ON") // Enable auto-detection
        appendLine("CLS") // Clear screen
      }
      
      android.util.Log.d("NTBPPlugin", "Sending gap detection commands: ${commands.length} chars")
      sendCommands(commands.toByteArray().toList())
      
    } catch (e: Exception) {
      android.util.Log.e("NTBPPlugin", "Error sending gap detection commands: ${e.message}")
    }
  }
  
  // Smart label positioning with gap detection
  private fun printSmartLabel(
    qrData: String,
    textData: String,
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
        
        android.util.Log.d("NTBPPlugin", "Starting smart label print with gap detection...")
        
        // Step 1: Send gap detection commands
        sendGapDetectionCommands(labelWidth, labelHeight, unit, dpi)
        delay(200) // Wait for gap detection
        
        // Step 2: Calculate optimal positioning
        val widthInDots = convertToDots(dpi, labelWidth, unit)
        val heightInDots = convertToDots(dpi, labelHeight, unit)
        
        // Calculate margins (dynamic based on label size)
        val marginInDots = when {
          labelWidth <= 30 -> convertToDots(dpi, 2.0, "mm")
          labelWidth <= 60 -> convertToDots(dpi, 3.0, "mm")
          else -> convertToDots(dpi, 4.0, "mm")
        }
        
        val availableWidth = widthInDots - 2 * marginInDots
        val availableHeight = heightInDots - 2 * marginInDots
        
        // Calculate QR size (proportional to label size)
        val qrSize = when {
          labelWidth <= 30 -> (availableWidth * 0.6).toInt()
          labelWidth <= 60 -> (availableWidth * 0.7).toInt()
          else -> (availableWidth * 0.8).toInt()
        }.coerceAtMost((availableHeight * 0.8).toInt()).coerceAtMost((availableWidth * 0.8).toInt())
        
        // Calculate positions (perfectly centered)
        val qrX = marginInDots + (availableWidth - qrSize) / 2
        val qrY = marginInDots + (availableHeight - qrSize) / 2 - (qrSize * 0.1).toInt()
        val textX = marginInDots + 10
        val textY = qrY + qrSize + 15
        
        // Step 3: Build TSPL commands with proper positioning
        val commands = buildString {
          appendLine("CLS") // Clear screen
          appendLine("REFERENCE 0,0") // Set reference point
          appendLine("DIRECTION 0") // Normal direction
          
          // Add QR code with perfect positioning
          appendLine("QRCODE $qrX,$qrY,H,10,A,0,\"$qrData\"")
          
          // Add text below QR code
          appendLine("TEXT $textX,$textY,\"9\",0,1,1,\"$textData\"")
          
          // Print ONLY ONE label and STOP - no automatic feeding
          appendLine("PRINT 1")
        }
        
        android.util.Log.d("NTBPPlugin", "Smart label commands: QR($qrX,$qrY) size:$qrSize, Text($textX,$textY)")
        
        // Send commands
        sendCommands(commands.toByteArray().toList())
        result.success(true)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error printing smart label: ${e.message}")
        result.error("SMART_LABEL_ERROR", "Failed to print smart label: ${e.message}", null)
      }
    }
  }
  
  // Enhanced sequence printing with gap detection
  private fun printSmartSequence(labelDataList: List<Map<String, Any>>, result: Result) {
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
        
        android.util.Log.d("NTBPPlugin", "Starting smart sequence print of ${labelDataList.size} labels")
        
        var successCount = 0
        var failureCount = 0
        
        // Step 1: Initialize printer with gap detection
        val firstLabel = labelDataList.first()
        val width = when (firstLabel["width"]) {
          is Int -> (firstLabel["width"] as Int).toDouble()
          is Double -> firstLabel["width"] as Double
          is Number -> (firstLabel["width"] as Number).toDouble()
          else -> 50.0
        }
        val height = when (firstLabel["height"]) {
          is Int -> (firstLabel["height"] as Int).toDouble()
          is Double -> firstLabel["height"] as Double
          is Number -> (firstLabel["height"] as Number).toDouble()
          else -> 30.0
        }
        val unit = firstLabel["unit"] as? String ?: "mm"
        val dpi = when (firstLabel["dpi"]) {
          is Int -> firstLabel["dpi"] as Int
          is Number -> (firstLabel["dpi"] as Number).toInt()
          else -> 203
        }
        
        // Initialize gap detection
        sendGapDetectionCommands(width, height, unit, dpi)
        delay(300) // Wait for initialization
        
        // Step 2: Print each label with proper positioning
        for ((index, labelData) in labelDataList.withIndex()) {
          try {
            val qrData = labelData["qrData"] as? String ?: "Label${index + 1}"
            val textData = labelData["textData"] as? String ?: "Text${index + 1}"
            
            android.util.Log.d("NTBPPlugin", "Printing smart label ${index + 1}: ${width}x${height} $unit")
            
            // Calculate dimensions and positions
            val widthInDots = convertToDots(dpi, width, unit)
            val heightInDots = convertToDots(dpi, height, unit)
            
            val marginInDots = when {
              width <= 30 -> convertToDots(dpi, 2.0, "mm")
              width <= 60 -> convertToDots(dpi, 3.0, "mm")
              else -> convertToDots(dpi, 4.0, "mm")
            }
            
            val availableWidth = widthInDots - 2 * marginInDots
            val availableHeight = heightInDots - 2 * marginInDots
            
            val qrSize = when {
              width <= 30 -> (availableWidth * 0.6).toInt()
              width <= 60 -> (availableWidth * 0.7).toInt()
              else -> (availableWidth * 0.8).toInt()
            }.coerceAtMost((availableHeight * 0.8).toInt()).coerceAtMost((availableWidth * 0.8).toInt())
            
            val qrX = marginInDots + (availableWidth - qrSize) / 2
            val qrY = marginInDots + (availableHeight - qrSize) / 2 - (qrSize * 0.1).toInt()
            val textX = marginInDots + 10
            val textY = qrY + qrSize + 15
            
            // Build TSPL commands for this label
            val commands = buildString {
              appendLine("CLS") // Clear screen for each label
              appendLine("REFERENCE 0,0") // Set reference point
              appendLine("DIRECTION 0") // Normal direction
              appendLine("QRCODE $qrX,$qrY,H,10,A,0,\"$qrData\"")
              appendLine("TEXT $textX,$textY,\"9\",0,1,1,\"$textData\"")
              appendLine("PRINT 1")
            }
            
            // Send commands for this label
            sendCommands(commands.toByteArray().toList())
            
            // Wait for print completion
            delay(500)
            
            // Feed to next label position (except for last one)
            if (index < labelDataList.size - 1) {
              sendCommands("FEED".toByteArray().toList())
              delay(300) // Wait for paper feed
            }
            
            android.util.Log.d("NTBPPlugin", "Smart label ${index + 1} printed successfully")
            successCount++
            
          } catch (e: Exception) {
            android.util.Log.e("NTBPPlugin", "Error printing smart label ${index + 1}: ${e.message}")
            failureCount++
          }
        }
        
        // Final cut command
        sendCommands("CUT".toByteArray().toList())
        
        android.util.Log.d("NTBPPlugin", "Smart sequence print completed: $successCount successful, $failureCount failed")
        
        if (failureCount == 0) {
          result.success(true)
        } else {
          result.success(false)
        }
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error in smart sequence printing: ${e.message}")
        result.error("SMART_SEQUENCE_ERROR", "Failed to print smart sequence: ${e.message}", null)
      }
    }
  }
  
  // Enhanced single label printing with custom configurations and better positioning
  // Enhanced with aggressive buffer clearing to prevent content bleeding
  // Java equivalent: HPRTPrinterHelper.CLS() before printing
  private fun printSingleLabelWithGapDetection(
    qrData: String,
    textData: String,
    labelWidth: Double,
    labelHeight: Double,
    unit: String,
    dpi: Int,
    copies: Int,
    textSize: Int,
    result: Result
  ) {
    coroutineScope.launch {
      try {
        if (!isConnected()) {
          result.error("NOT_CONNECTED", "Not connected to printer", null)
          return@launch
        }
        
        android.util.Log.d("NTBPPlugin", "Starting enhanced single label print: ${labelWidth}x${labelHeight} $unit, $copies copies")
        
        // Step 1: Initialize printer with gap detection
        sendGapDetectionCommands(labelWidth, labelHeight, unit, dpi)
        Thread.sleep(300) // Wait for initialization
        
        // ENHANCED BUFFER CLEARING: Clear all buffers before printing to prevent content bleeding
        clearBufferAggressively()
        Thread.sleep(300) // Wait for printer to process all clearing commands
        
        // Step 2: Calculate optimal positioning for better content placement
        val widthInDots = convertToDots(dpi, labelWidth, unit)
        val heightInDots = convertToDots(dpi, labelHeight, unit)
        
        // Calculate margins (dynamic based on label size)
        val marginInDots = when {
          labelWidth <= 30 -> convertToDots(dpi, 2.0, "mm")
          labelWidth <= 60 -> convertToDots(dpi, 3.0, "mm")
          else -> convertToDots(dpi, 4.0, "mm")
        }
        
        val availableWidth = widthInDots - 2 * marginInDots
        val availableHeight = heightInDots - 2 * marginInDots
        
        // Calculate QR size (proportional to label size, but ensure it fits well)
        val qrSize = when {
          labelWidth <= 30 -> (availableWidth * 0.6).toInt()
          labelWidth <= 60 -> (availableWidth * 0.65).toInt()
          else -> (availableWidth * 0.7).toInt()
        }.coerceAtMost((availableHeight * 0.6).toInt()).coerceAtMost((availableWidth * 0.7).toInt())
        
        // Calculate positions with better spacing
        val qrX = marginInDots + (availableWidth - qrSize) / 2 // Center horizontally
        val qrY = marginInDots + (availableHeight * 0.15).toInt() // Position QR code in upper portion
        val textX = marginInDots + (availableWidth - convertToDots(dpi, 20.0, "mm")) / 2 // Center text horizontally
        val textY = qrY + qrSize + convertToDots(dpi, 8.0, "mm") // Text below QR with proper spacing
        
        // Step 3: Build TSPL commands for single label
        val commands = buildString {
          appendLine("REFERENCE 0,0") // Set reference point
          appendLine("DIRECTION 0") // Normal direction
          
          // Add QR code positioned in upper portion
          appendLine("QRCODE $qrX,$qrY,H,10,A,0,\"$qrData\"")
          
          // Add text below QR code with better positioning and custom size
          appendLine("TEXT $textX,$textY,\"$textSize\",0,1,1,\"$textData\"")
          
          // Print specified number of copies
          appendLine("PRINT $copies")
        }
        
        android.util.Log.d("NTBPPlugin", "Enhanced label commands: QR($qrX,$qrY) size:$qrSize, Text($textX,$textY), Copies: $copies")
        
        // Send commands
        sendCommands(commands.toByteArray().toList())
        
        // Wait for print completion
        Thread.sleep(500 * copies.toLong()) // Longer delay for multiple copies
        
        result.success(true)
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error printing enhanced single label: ${e.message}")
        result.error("ENHANCED_LABEL_ERROR", "Failed to print enhanced single label: ${e.message}", null)
      }
    }
  }
  


  // Print multiple labels with different content and proper gap detection
  // Enhanced with comprehensive buffer clearing to prevent content bleeding between labels
  // Java equivalent: Multiple HPRTPrinterHelper.CLS() calls before each label
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
        
        android.util.Log.d("NTBPPlugin", "Starting multiple labels print: ${labelDataList.size} labels, ${labelWidth}x${labelHeight} $unit, $copiesPerLabel copies each")
        
        // Step 1: Initialize printer with gap detection
        sendGapDetectionCommands(labelWidth, labelHeight, unit, dpi)
        Thread.sleep(300) // Wait for initialization
        
        // Step 1.5: Complete buffer clearing for multiple labels to prevent any content bleeding
        clearBufferCompletely()
        Thread.sleep(400) // Wait for complete buffer clearing
        
        var successCount = 0
        var failureCount = 0
        
        // Step 2: Print each label with proper positioning
        for ((index, labelData) in labelDataList.withIndex()) {
          try {
            val qrData = labelData["qrData"] as? String ?: "Label${index + 1}"
            val textData = labelData["textData"] as? String ?: "Text${index + 1}"
            
            android.util.Log.d("NTBPPlugin", "Printing label ${index + 1}: $qrData - $textData")
            
            // ENHANCED BUFFER CLEARING: Clear all buffers before each label to prevent content bleeding
            clearBufferAggressively()
            Thread.sleep(300) // Wait for printer to process all clearing commands
            
            // Calculate dimensions and positions
            val widthInDots = convertToDots(dpi, labelWidth, unit)
            val heightInDots = convertToDots(dpi, labelHeight, unit)
            
            val marginInDots = when {
              labelWidth <= 30 -> convertToDots(dpi, 2.0, "mm")
              labelWidth <= 60 -> convertToDots(dpi, 3.0, "mm")
              else -> convertToDots(dpi, 4.0, "mm")
            }
            
            val availableWidth = widthInDots - 2 * marginInDots
            val availableHeight = heightInDots - 2 * marginInDots
            
            val qrSize = when {
              labelWidth <= 30 -> (availableWidth * 0.6).toInt()
              labelWidth <= 60 -> (availableWidth * 0.65).toInt()
              else -> (availableWidth * 0.7).toInt()
            }.coerceAtMost((availableHeight * 0.6).toInt()).coerceAtMost((availableWidth * 0.7).toInt())
            
            val qrX = marginInDots + (availableWidth - qrSize) / 2
            val qrY = marginInDots + (availableHeight * 0.15).toInt()
            val textX = marginInDots + (availableWidth - convertToDots(dpi, 20.0, "mm")) / 2 // Center text horizontally
            val textY = qrY + qrSize + convertToDots(dpi, 8.0, "mm")
            
            // Build TSPL commands for this label
            // Step 3.3: Build TSPL commands for THIS SINGLE LABEL ONLY
            val commands = buildString {
              appendLine("REFERENCE 0,0") // Set reference point
              appendLine("DIRECTION 0") // Normal direction
              appendLine("CLS") // Clear screen
              appendLine("QRCODE $qrX,$qrY,H,10,A,0,\"$qrData\"")
              appendLine("TEXT $textX,$textY,\"$textSize\",0,1,1,\"$textData\"")
              appendLine("PRINT $copiesPerLabel")
            }
            
            // Send commands for this label
            sendCommands(commands.toByteArray().toList())
            
            // Wait for print completion
            Thread.sleep(500 * copiesPerLabel.toLong())
            
            // Feed to next label position (except for last one)
            if (index < labelDataList.size - 1) {
              sendCommands("FORMFEED".toByteArray().toList()) // Better label separation
              Thread.sleep(400) // Longer wait for form feed
            }
            
            android.util.Log.d("NTBPPlugin", "Label ${index + 1} printed successfully")
            successCount++
            
          } catch (e: Exception) {
            android.util.Log.e("NTBPPlugin", "Error printing label ${index + 1}: ${e.message}")
            failureCount++
          }
        }
        
        // Final cut command
        sendCommands("CUT".toByteArray().toList())
        
        android.util.Log.d("NTBPPlugin", "Multiple labels print completed: $successCount successful, $failureCount failed")
        
        if (failureCount == 0) {
          result.success(true)
        } else {
          result.success(false)
        }
        
      } catch (e: Exception) {
        android.util.Log.e("NTBPPlugin", "Error in multiple labels printing: ${e.message}")
        result.error("MULTIPLE_LABELS_ERROR", "Failed to print multiple labels: ${e.message}", null)
      }
    }
  }
}



