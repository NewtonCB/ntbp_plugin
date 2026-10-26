package com.example.ntbp_plugin

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import net.posprinter.IConnectListener
import net.posprinter.IDeviceConnection
import net.posprinter.POSConnect
import net.posprinter.TSPLPrinter
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * NTBP plugin, Android side.
 *
 * Transport only: Bluetooth discovery with the platform adapter, connection
 * and byte transfer through the Xprinter `net.posprinter` SDK (classic
 * Bluetooth SPP), and the printer status query. Label layouts are rendered to
 * TSPL on the Dart side and arrive here as raw bytes via `sendProtocolCommands`.
 */
class NtbpPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var bluetoothAdapter: BluetoothAdapter? = null
  private val discoveredDevices = ConcurrentHashMap<String, BluetoothDevice>()
  private var discoveryReceiver: BroadcastReceiver? = null

  private var connection: IDeviceConnection? = null
  private var connectedAddress: String? = null
  private var connectedName: String? = null
  private var connecting = false
  private var lastError: String? = null

  private val mainHandler = Handler(Looper.getMainLooper())
  private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
  private var pendingScanResult: Result? = null
  private var scanTimeout: Runnable? = null

  companion object {
    private const val TAG = "NTBPPlugin"
    private const val SCAN_WINDOW_MS = 12_000L
    private const val CONNECT_TIMEOUT_MS = 20_000L
    private const val WRITE_TIMEOUT_MS = 30_000L
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "ntbp_plugin")
    channel.setMethodCallHandler(this)
    context = binding.applicationContext

    POSConnect.init(context)

    bluetoothAdapter = try {
      (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        ?: BluetoothAdapter.getDefaultAdapter()
    } catch (e: Exception) {
      null
    }

    val receiver = DiscoveryReceiver()
    val filter = IntentFilter().apply {
      addAction(BluetoothDevice.ACTION_FOUND)
      addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
      addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
    } else {
      context.registerReceiver(receiver, filter)
    }
    discoveryReceiver = receiver
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    discoveryReceiver?.let {
      try { context.unregisterReceiver(it) } catch (_: Exception) {}
    }
    discoveryReceiver = null
    closeConnection()
    ioExecutor.shutdown()
  }

  // ===========================================================================
  // Method dispatch
  // ===========================================================================

  override fun onMethodCall(call: MethodCall, result: Result) {
    try {
      when (call.method) {
        "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")

        // --- Bluetooth -----------------------------------------------------
        "isBluetoothAvailable" -> result.success(isBluetoothAvailable())
        "requestBluetoothPermissions" -> result.success(hasBluetoothPermissions())
        "checkDevicePairingStatus" -> {
          result.success(checkDevicePairingStatus(call.argument<String>("address") ?: ""))
        }
        "requestDevicePairing", "requestDevicePairingWithPin" -> {
          // Pairing is handled by the OS dialog on Android; the SDK connects to
          // bonded and unbonded SPP devices alike.
          result.success("NOT_REQUIRED")
        }
        "getStoredPinCode" -> result.success(null)
        "removeStoredPinCode" -> result.success(true)

        "startScan" -> startScan(result)
        "stopScan" -> stopScan(result)
        "getDiscoveredDevices" -> result.success(discoveredDeviceMaps())

        "connectToDevice" -> {
          val args = call.arguments as? Map<*, *>
          val address = args?.get("address") as? String
          if (address.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENTS", "Device address is required", null)
          } else {
            connectToDevice(address, args["name"] as? String, result)
          }
        }
        "disconnect" -> {
          closeConnection()
          result.success(true)
        }
        "isConnected" -> result.success(isConnected())
        "getConnectionStatus" -> result.success(connectionState())
        "getDetailedConnectionStatus" -> result.success(
          mapOf(
            "connectionState" to connectionState(),
            "socketConnected" to isConnected(),
            "hasOutputStream" to isConnected(),
            "socketAddress" to connectedAddress,
            "socketName" to connectedName,
            "lastError" to lastError,
            "transport" to "xprinter-sdk-spp"
          )
        )

        // --- Raw transport and status --------------------------------------
        "sendProtocolCommands" -> {
          val commands = call.argument<List<Int>>("commands") ?: emptyList()
          sendBytes(ByteArray(commands.size) { commands[it].toByte() }, result)
        }
        "queryPrinterStatus" -> {
          queryPrinterStatus(call.argument<Int>("timeoutMs") ?: 2000, result)
        }
        "initializeProtocolPrinter" -> {
          val w = (call.argument<Number>("labelWidth") ?: 100).toDouble()
          val h = (call.argument<Number>("labelHeight") ?: 150).toDouble()
          val unit = call.argument<String>("unit") ?: "mm"
          val size = if (unit.equals("inch", true)) "SIZE $w,$h" else "SIZE $w mm,$h mm"
          sendBytes("$size\r\nGAP 3 mm,0 mm\r\nCLS\r\n".toByteArray(), result)
        }

        // --- Simple legacy prints (TSPL built here) --------------------------
        "clearBuffer", "clearPrintBuffer" -> sendBytes("CLS\r\n".toByteArray(), result)
        "feedPaper" -> {
          val dots = (call.argument<Number>("lines") ?: 1).toInt().coerceIn(1, 9999)
          sendBytes("FEED $dots\r\n".toByteArray(), result)
        }
        "printText" -> {
          val text = tsplEscape(call.argument<String>("text") ?: "")
          sendBytes("TEXT 50,50,\"3\",0,1,1,\"$text\"\r\nPRINT 1,1\r\n".toByteArray(), result)
        }
        "printBarcode" -> {
          val data = tsplEscape(call.argument<String>("data") ?: "")
          sendBytes("BARCODE 50,100,\"128\",80,1,0,2,2,\"$data\"\r\nPRINT 1,1\r\n".toByteArray(), result)
        }
        "printQRCode" -> {
          val data = tsplEscape(call.argument<String>("data") ?: "")
          sendBytes("QRCODE 50,50,M,6,A,0,\"$data\"\r\nPRINT 1,1\r\n".toByteArray(), result)
        }
        "print" -> {
          val commands = call.argument<List<Map<String, Any?>>>("commands") ?: emptyList()
          val script = StringBuilder("CLS\r\n")
          for (cmd in commands) {
            val x = (cmd["x"] as? Number)?.toInt() ?: 50
            val y = (cmd["y"] as? Number)?.toInt() ?: 50
            when {
              cmd["isBarcode"] == true -> script.append(
                "BARCODE $x,$y,\"128\",80,1,0,2,2,\"${tsplEscape(cmd["barcodeData"] as? String ?: "")}\"\r\n")
              cmd["isQRCode"] == true -> script.append(
                "QRCODE $x,$y,M,6,A,0,\"${tsplEscape(cmd["barcodeData"] as? String ?: "")}\"\r\n")
              else -> {
                val text = cmd["text"] as? String ?: ""
                if (text.isNotEmpty()) {
                  val font = (cmd["fontNumber"] as? Number)?.toInt()?.toString() ?: "3"
                  script.append("TEXT $x,$y,\"$font\",0,1,1,\"${tsplEscape(text)}\"\r\n")
                }
              }
            }
          }
          script.append("PRINT 1,1\r\n")
          sendBytes(script.toString().toByteArray(), result)
        }

        else -> result.notImplemented()
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error handling ${call.method}: ${e.message}", e)
      result.error("PLUGIN_ERROR", "${call.method} failed: ${e.message}", null)
    }
  }

  // ===========================================================================
  // Bluetooth availability and discovery
  // ===========================================================================

  private fun isBluetoothAvailable(): Boolean {
    val adapter = bluetoothAdapter ?: return false
    return try { adapter.isEnabled } catch (_: Exception) { false }
  }

  private fun hasBluetoothPermissions(): Boolean {
    fun granted(p: String) =
      ContextCompat.checkSelfPermission(context, p) == PackageManager.PERMISSION_GRANTED
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      granted(Manifest.permission.BLUETOOTH_SCAN) && granted(Manifest.permission.BLUETOOTH_CONNECT)
    } else {
      granted(Manifest.permission.ACCESS_FINE_LOCATION)
    }
  }

  private fun startScan(result: Result) {
    val adapter = bluetoothAdapter
    if (adapter == null || !adapter.isEnabled) {
      result.error("BLUETOOTH_NOT_AVAILABLE", "Bluetooth is not available or not enabled.", null)
      return
    }
    if (!hasBluetoothPermissions()) {
      result.error("PERMISSION_DENIED",
        "Bluetooth permissions not granted. Request BLUETOOTH_SCAN/BLUETOOTH_CONNECT " +
          "(Android 12+) or ACCESS_FINE_LOCATION before scanning.", null)
      return
    }

    // A previous scan still pending: resolve it now.
    finishScan()

    discoveredDevices.clear()
    try {
      adapter.bondedDevices?.forEach { device ->
        if (device.type != BluetoothDevice.DEVICE_TYPE_LE) {
          discoveredDevices[device.address] = device
        }
      }
      if (adapter.isDiscovering) adapter.cancelDiscovery()

      pendingScanResult = result
      val started = adapter.startDiscovery()
      if (!started) {
        // Discovery refused (often location services off). Still return the
        // bonded devices so a paired printer can be used.
        Log.w(TAG, "startDiscovery() returned false; returning bonded devices only")
        finishScan()
        return
      }
      val timeout = Runnable { finishScan() }
      scanTimeout = timeout
      mainHandler.postDelayed(timeout, SCAN_WINDOW_MS)
    } catch (e: SecurityException) {
      pendingScanResult = null
      result.error("PERMISSION_DENIED", "Bluetooth permission denied: ${e.message}", null)
    } catch (e: Exception) {
      pendingScanResult = null
      result.error("SCAN_ERROR", "Failed to start scan: ${e.message}", null)
    }
  }

  private fun finishScan() {
    scanTimeout?.let { mainHandler.removeCallbacks(it) }
    scanTimeout = null
    val pending = pendingScanResult ?: return
    pendingScanResult = null
    Log.d(TAG, "Scan finished with ${discoveredDevices.size} devices")
    pending.success(discoveredDevices.size)
  }

  private fun stopScan(result: Result) {
    try {
      bluetoothAdapter?.cancelDiscovery()
    } catch (_: Exception) {}
    finishScan()
    result.success(null)
  }

  private fun discoveredDeviceMaps(): List<Map<String, Any?>> {
    return discoveredDevices.values.map { device ->
      val name = try { device.name } catch (_: SecurityException) { null }
      val cls = try { device.bluetoothClass?.toString() } catch (_: Exception) { null }
      mapOf(
        "name" to (name ?: "Unknown Device"),
        "address" to device.address,
        "isConnected" to (device.address == connectedAddress && isConnected()),
        "rssi" to 0,
        "deviceClass" to cls,
        "bonded" to (try { device.bondState == BluetoothDevice.BOND_BONDED } catch (_: Exception) { false })
      )
    }
  }

  private fun checkDevicePairingStatus(address: String): String {
    return try {
      val device = discoveredDevices[address] ?: bluetoothAdapter?.getRemoteDevice(address)
      when (device?.bondState) {
        BluetoothDevice.BOND_BONDED -> "PAIRED"
        BluetoothDevice.BOND_BONDING -> "PAIRING"
        BluetoothDevice.BOND_NONE -> "NOT_PAIRED"
        else -> "UNKNOWN"
      }
    } catch (e: Exception) {
      "UNKNOWN"
    }
  }

  inner class DiscoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        BluetoothDevice.ACTION_FOUND -> {
          @Suppress("DEPRECATION")
          val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
          if (device != null && device.type != BluetoothDevice.DEVICE_TYPE_LE) {
            discoveredDevices[device.address] = device
          }
        }
        BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> finishScan()
      }
    }
  }

  // ===========================================================================
  // Connection (Xprinter SDK)
  // ===========================================================================

  private fun isConnected(): Boolean = connection?.isConnect == true

  private fun connectionState(): String = when {
    isConnected() -> "CONNECTED"
    connecting -> "CONNECTING"
    else -> "DISCONNECTED"
  }

  private fun connectToDevice(address: String, name: String?, result: Result) {
    if (!isBluetoothAvailable()) {
      result.error("BLUETOOTH_NOT_AVAILABLE", "Bluetooth is not available or not enabled.", null)
      return
    }
    try { bluetoothAdapter?.cancelDiscovery() } catch (_: Exception) {}
    finishScan()
    closeConnection()

    val conn = POSConnect.createDevice(POSConnect.DEVICE_TYPE_BLUETOOTH)
    val replied = AtomicBoolean(false)
    connecting = true
    lastError = null

    val listener = IConnectListener { code, _, msg ->
      when (code) {
        POSConnect.CONNECT_SUCCESS -> {
          Log.d(TAG, "Connected to $address")
          connection = conn
          connectedAddress = address
          connectedName = name
          connecting = false
          if (replied.compareAndSet(false, true)) mainHandler.post { result.success(true) }
        }
        POSConnect.CONNECT_FAIL -> {
          Log.e(TAG, "Connect failed: $msg")
          lastError = msg ?: "Connection failed"
          connecting = false
          if (replied.compareAndSet(false, true)) {
            mainHandler.post { result.error("CONNECTION_ERROR", "Failed to connect: $lastError", null) }
          }
        }
        POSConnect.CONNECT_INTERRUPT, POSConnect.BLUETOOTH_INTERRUPT -> {
          Log.w(TAG, "Connection interrupted: $msg")
          lastError = msg ?: "Connection interrupted"
          if (connection === conn) {
            connection = null
            connectedAddress = null
          }
          connecting = false
          if (replied.compareAndSet(false, true)) {
            mainHandler.post { result.error("CONNECTION_ERROR", "Connection interrupted: $lastError", null) }
          }
        }
        POSConnect.SEND_FAIL -> {
          Log.e(TAG, "Send failed: $msg")
          lastError = msg ?: "Send failed"
        }
      }
    }

    mainHandler.postDelayed({
      if (replied.compareAndSet(false, true)) {
        connecting = false
        try { conn.close() } catch (_: Exception) {}
        result.error("CONNECTION_TIMEOUT", "Timed out connecting to $address", null)
      }
    }, CONNECT_TIMEOUT_MS)

    try {
      conn.connect(address, listener)
    } catch (e: Exception) {
      connecting = false
      if (replied.compareAndSet(false, true)) {
        result.error("CONNECTION_ERROR", "Failed to connect: ${e.message}", null)
      }
    }
  }

  private fun closeConnection() {
    val conn = connection
    connection = null
    connectedAddress = null
    connectedName = null
    connecting = false
    if (conn != null) {
      try { conn.close() } catch (e: Exception) { Log.w(TAG, "close: ${e.message}") }
    }
  }

  // ===========================================================================
  // Data transfer and status
  // ===========================================================================

  private fun sendBytes(bytes: ByteArray, result: Result) {
    val conn = connection
    if (conn == null || !conn.isConnect) {
      result.error("NOT_CONNECTED", "Not connected to printer", null)
      return
    }
    val replied = AtomicBoolean(false)
    ioExecutor.execute {
      try {
        conn.sendData(bytes)
        if (replied.compareAndSet(false, true)) mainHandler.post { result.success(true) }
      } catch (e: Exception) {
        Log.e(TAG, "sendData failed: ${e.message}")
        lastError = e.message
        if (replied.compareAndSet(false, true)) {
          mainHandler.post { result.error("SEND_ERROR", "Failed to send data: ${e.message}", null) }
        }
      }
    }
    mainHandler.postDelayed({
      if (replied.compareAndSet(false, true)) {
        result.error("SEND_TIMEOUT", "Timed out sending ${bytes.size} bytes", null)
      }
    }, WRITE_TIMEOUT_MS)
  }

  /**
   * Status byte as defined by TSPL `ESC ! ?`: 0 ready, bit0 head open, bit1
   * paper jam, bit2 out of paper, bit3 out of ribbon, bit4 paused, bit5 printing.
   * Returns -1 when the printer does not answer, -2 when not connected.
   */
  private fun queryPrinterStatus(timeoutMs: Int, result: Result) {
    val conn = connection
    if (conn == null || !conn.isConnect) {
      result.success(-2)
      return
    }
    val replied = AtomicBoolean(false)
    try {
      TSPLPrinter(conn).printerStatus(timeoutMs) { code ->
        if (replied.compareAndSet(false, true)) mainHandler.post { result.success(code) }
      }
    } catch (e: Exception) {
      Log.e(TAG, "printerStatus failed: ${e.message}")
      if (replied.compareAndSet(false, true)) result.success(-1)
      return
    }
    mainHandler.postDelayed({
      if (replied.compareAndSet(false, true)) result.success(-1)
    }, timeoutMs + 500L)
  }

  private fun tsplEscape(value: String): String =
    value.replace('"', '\'').replace("\r", " ").replace("\n", " ")
}
