import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:collection';

// Import the BluetoothDevice type from the models
import 'package:ntbp_plugin/models/bluetooth_device.dart';

void main() {
  runApp(const NtbpExampleApp());
}

class NtbpExampleApp extends StatelessWidget {
  const NtbpExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NTBP Plugin Example - Enhanced Bluetooth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NtbpExamplePage(),
    );
  }
}

class NtbpExamplePage extends StatefulWidget {
  const NtbpExamplePage({super.key});

  @override
  State<NtbpExamplePage> createState() => _NtbpExamplePageState();
}

class _NtbpExamplePageState extends State<NtbpExamplePage> {
  final NtbpPlugin _ntbpPlugin = NtbpPlugin();
  
  bool _isInitialized = false;
  bool _isDiscovering = false;
  List<BluetoothDevice> _availableDevices = [];
  BluetoothDevice? _connectedDevice;
  final Map<String, String> _devicePairingStatus = {};
  
  // Queue management for multiple connections
  final Queue<BluetoothDevice> _connectionQueue = Queue<BluetoothDevice>();
  bool _isProcessingQueue = false;
  String _queueStatus = 'Ready';
  
  // Controllers for label configuration
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _copiesController = TextEditingController();
  final TextEditingController _textSizeController = TextEditingController();
  final TextEditingController _qrDataController = TextEditingController();
  final TextEditingController _textData1Controller = TextEditingController(); // Customer name
  final TextEditingController _textData2Controller = TextEditingController(); // Drop point
  final TextEditingController _textData3Controller = TextEditingController(); // Additional info
  
  // Multiple labels data
  final List<Map<String, String>> _multipleLabelsData = [];
  final TextEditingController _multipleLabelsController = TextEditingController();
  
  // Protocol selection
  String _selectedProtocol = 'Auto-Detect';
  final List<String> _availableProtocols = [
    'Auto-Detect',
    'TSPL (N41)',
    'ESC/POS (TSPL Forced)',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    _widthController.text = '75';
    _heightController.text = '60'; // Increased height for 2 text lines
    _copiesController.text = '1';
    _textSizeController.text = '9';
    _qrDataController.text = 'TEST_QR_001';
    _textData1Controller.text = 'Cust: Nashon Israel';
    _textData2Controller.text = 'Drp: Mwanza';
    _textData3Controller.text = 'Ref: 12345';
    
    // Initialize plugin after a short delay to ensure Scaffold is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlugin();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't call _initializePlugin here anymore
  }

  void _setupSampleData() {
    _widthController.text = '75';
    _heightController.text = '60'; // Increased height for 2 text lines
    _copiesController.text = '1';
    _textSizeController.text = '9';
    _qrDataController.text = 'XYZ185EVT';
    _textData1Controller.text = 'Cust: Emanuel Tarimo';
    _textData2Controller.text = 'Drp: Mbeya';
    _textData3Controller.text = 'Ref: 67890';
  }

  void _setupSampleMultipleLabels() {
    setState(() {
      _multipleLabelsData.clear();
      _multipleLabelsData.addAll([
        {
          'qrData': 'XYZ185EVT',
          'textData1': 'Cust: Nashon Israel',
          'textData2': 'Drp: Mwanza',
          'textData3': 'Ref: 11111',
        },
        {
          'qrData': 'XYZ186HYW',
          'textData1': 'Cust: Emanuel Tarimo',
          'textData2': 'Drp: Mbeya',
          'textData3': 'Ref: 22222',
        },
        {
          'qrData': 'XYZ187ABC',
          'textData1': 'Cust: John Doe',
          'textData2': 'Drp: Dar es Salaam',
          'textData3': 'Ref: 33333',
        },
      ]);
    });
    _showMessage('📋 Loaded sample multiple labels data');
  }

  Future<void> _initializePlugin() async {
    try {
      _showMessage('🔄 Starting plugin initialization...');
      
      // Request Bluetooth permissions first
      _showMessage('🔐 Requesting Bluetooth permissions...');
      await _requestPermissions();
      
      // For now, let's assume Bluetooth is available to enable basic functionality
      // We'll handle actual Bluetooth checks when needed
      setState(() {
        _isInitialized = true;
      });
      
      _showMessage('✅ NTBP Plugin initialized successfully');
      _showMessage('✅ Ready for Bluetooth operations');
      
    } catch (e) {
      _showMessage('❌ Failed to initialize plugin: $e');
      // Set as initialized anyway to allow basic functionality
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      _showMessage('🔐 Requesting Bluetooth permissions...');
      // Request Bluetooth permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();
      
      // Check if all permissions are granted
      bool allGranted = true;
      statuses.forEach((permission, status) {
        _showMessage('🔐 Permission ${permission.toString()}: $status');
        if (!status.isGranted) {
          allGranted = false;
        }
      });
      
      if (allGranted) {
        _showMessage('✅ All Bluetooth permissions granted');
      } else {
        _showMessage('⚠️ Some permissions not granted');
      }
    } catch (e) {
      _showMessage('❌ Error requesting permissions: $e');
    }
  }

  Future<void> _startDiscovery() async {
    try {
      setState(() {
        _isDiscovering = true;
        _availableDevices.clear();
      });

      _showMessage('🔍 Starting Bluetooth discovery...');

      // Use NTBP plugin for device discovery
      // Start scanning first
      await _ntbpPlugin.startScan();
      
      // Wait for discovery to complete
      await Future.delayed(const Duration(seconds: 10));
      
      // Get scan results
      final devices = await _ntbpPlugin.getDiscoveredDevices();
      
      if (devices.isNotEmpty) {
        setState(() {
          _availableDevices = devices;
        });
        
        _showMessage('✅ Found ${devices.length} Bluetooth devices');
        
        // Check pairing status for each device
        for (final device in devices) {
          if (device.address != null) {
            try {
              final pairingStatus = await _ntbpPlugin.checkDevicePairingStatus(device.address!);
              _devicePairingStatus[device.address!] = pairingStatus;
            } catch (e) {
              _devicePairingStatus[device.address!] = 'UNKNOWN';
            }
          }
        }
      } else {
        _showMessage('⚠️ No Bluetooth devices found');
      }
    } catch (e) {
      _showMessage('❌ Discovery error: $e');
    } finally {
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  Future<void> _stopDiscovery() async {
    try {
      await _ntbpPlugin.stopScan();
      _showMessage('⏹️ Discovery stopped');
    } catch (e) {
      _showMessage('❌ Error stopping discovery: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _showMessage('🔌 Connecting to ${device.name ?? 'Unknown Device'}...');
      
      // Add to connection queue
      _addToConnectionQueue(device);
      
      // Process queue
      await _processConnectionQueue();
      
    } catch (e) {
      _showMessage('❌ Connection error: $e');
    }
  }

  void _addToConnectionQueue(BluetoothDevice device) {
    if (!_connectionQueue.contains(device)) {
      _connectionQueue.add(device);
      _showMessage('➕ Added ${device.name ?? 'Unknown Device'} to connection queue');
    }
  }

  Future<void> _processConnectionQueue() async {
    if (_isProcessingQueue || _connectionQueue.isEmpty) return;

    setState(() {
      _isProcessingQueue = true;
      _queueStatus = 'Processing...';
    });
    
    while (_connectionQueue.isNotEmpty) {
      final device = _connectionQueue.removeFirst();
      
      try {
        _showMessage('🔄 Processing connection to ${device.name ?? 'Unknown Device'}...');
        
        // Try NTBP plugin connection first
        bool connected = false;
        try {
          connected = await _ntbpPlugin.connectToDevice(device);
        } catch (e) {
          _showMessage('⚠️ NTBP connection failed, trying alternative method: $e');
          // Could implement alternative connection method here
        }
        
        if (connected) {
          setState(() {
            _connectedDevice = device;
          });
          _showMessage('✅ Connected to ${device.name ?? 'Unknown Device'}');
          
          // Auto-detect protocol for this device
          await _autoDetectProtocol(device);
          break; // Exit queue processing after successful connection
        } else {
          _showMessage('❌ Failed to connect to ${device.name ?? 'Unknown Device'}');
        }
        
        // Wait before next connection attempt
        await Future.delayed(const Duration(seconds: 2));
        
      } catch (e) {
        _showMessage('❌ Error connecting to ${device.name ?? 'Unknown Device'}: $e');
      }
    }

    setState(() {
      _isProcessingQueue = false;
      _queueStatus = 'Ready';
    });
  }

  Future<void> _autoDetectProtocol(BluetoothDevice device) async {
    try {
      final deviceName = device.name?.toLowerCase() ?? '';
      
      if (deviceName.contains('n41') || deviceName.contains('tspl')) {
        setState(() {
          _selectedProtocol = 'TSPL (N41)';
        });
        _showMessage('🔍 Auto-detected: TSPL Protocol');
      } else if (deviceName.contains('kt58l') || deviceName.contains('romeson') || deviceName.contains('esc/pos')) {
        setState(() {
          _selectedProtocol = 'ESC/POS (TSPL Forced)';
        });
        _showMessage('🔍 Auto-detected: ESC/POS Protocol (TSPL Forced)');
      } else {
        setState(() {
          _selectedProtocol = 'Auto-Detect';
        });
        _showMessage('🔍 Protocol: Auto-Detect (will determine at print time)');
      }
    } catch (e) {
      _showMessage('⚠️ Could not auto-detect protocol: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      // Disconnect from NTBP plugin
      await _ntbpPlugin.disconnect();
      
      setState(() {
        _connectedDevice = null;
      });
      _showMessage('🔌 Disconnected from device');
    } catch (e) {
      _showMessage('❌ Failed to disconnect: $e');
    }
  }

  Future<void> _printSingleLabel() async {
    try {
      if (_connectedDevice == null) {
        _showMessage('❌ Please connect to a printer first');
        return;
      }

      final width = double.tryParse(_widthController.text) ?? 75.0;
      final height = double.tryParse(_heightController.text) ?? 50.0;
      final copies = int.tryParse(_copiesController.text) ?? 1;
      final textSize = int.tryParse(_textSizeController.text) ?? 9;
      final qrData = _qrDataController.text.isNotEmpty ? _qrDataController.text : 'TEST_QR_001';
      final textData1 = _textData1Controller.text.isNotEmpty ? _textData1Controller.text : 'Sample Customer Name';
      final textData2 = _textData2Controller.text.isNotEmpty ? _textData2Controller.text : 'Sample Drop Point';
      final textData3 = _textData3Controller.text.isNotEmpty ? _textData3Controller.text : 'Sample Additional Info';

      _showMessage('🏷️ Printing single label: ${width}x${height}mm, $copies copies, text size: $textSize...');
      
      final success = await NtbpPlugin.printSingleLabelWithGapDetection(
          qrData: qrData,
          textData1: textData1,
          textData2: textData2,
          textData3: textData3,
          width: width,
          height: height,
          unit: 'mm',
          dpi: 203,
          copies: copies,
          textSize: textSize,
        );

      if (success) {
        _showMessage('✅ Single label printed successfully!');
      } else {
        _showMessage('❌ Failed to print single label');
      }
    } catch (e) {
      _showMessage('❌ Error printing single label: $e');
    }
  }

  Future<void> _printMultipleLabels() async {
    try {
      if (_connectedDevice == null) {
        _showMessage('❌ Please connect to a printer first');
        return;
      }

      if (_multipleLabelsData.isEmpty) {
        _showMessage('❌ Please add some label data first');
        return;
      }

      final width = double.tryParse(_widthController.text) ?? 75.0;
      final height = double.tryParse(_heightController.text) ?? 50.0;
      final copiesPerLabel = int.tryParse(_copiesController.text) ?? 1;
      final textSize = int.tryParse(_textSizeController.text) ?? 9;

      _showMessage('🏷️ Printing ${_multipleLabelsData.length} labels: ${width}x${height}mm, $copiesPerLabel copies each, text size: $textSize...');
      
      bool success = false;
      
      // Use protocol-aware printing
      if (_selectedProtocol == 'ESC/POS (TSPL Forced)' || 
          (_selectedProtocol == 'Auto-Detect' && _shouldUseForcedTSPL())) {
        
        // Use traditional TSPL printing for now (protocol methods not yet implemented)
        // TODO: Implement protocol-based printing when available
        success = await NtbpPlugin.printMultipleLabelsWithGapDetection(
          labelDataList: _multipleLabelsData.map((data) => {
            'qrData': data['qrData'] ?? 'QR_${DateTime.now().millisecondsSinceEpoch}',
            'textData1': data['textData1'] ?? 'Customer_${DateTime.now().millisecondsSinceEpoch}',
            'textData2': data['textData2'] ?? 'Drop_${DateTime.now().millisecondsSinceEpoch}',
            'textData3': data['textData3'] ?? 'Drop_${DateTime.now().millisecondsSinceEpoch}',
          }).toList(),
          width: width,
          height: height,
          unit: 'mm',
          dpi: 203,
          copiesPerLabel: copiesPerLabel,
          textSize: textSize,
        );
      } else {
        // Use traditional TSPL printing
        success = await NtbpPlugin.printMultipleLabelsWithGapDetection(
          labelDataList: _multipleLabelsData.map((data) => {
            'qrData': data['qrData'] ?? 'QR_${DateTime.now().millisecondsSinceEpoch}',
            'textData1': data['textData1'] ?? 'Customer_${DateTime.now().millisecondsSinceEpoch}',
            'textData2': data['textData2'] ?? 'Drop_${DateTime.now().millisecondsSinceEpoch}',
            'textData3': data['textData3'] ?? 'Drop_${DateTime.now().millisecondsSinceEpoch}',
          }).toList(),
          width: width,
          height: height,
          unit: 'mm',
          dpi: 203,
          copiesPerLabel: copiesPerLabel,
          textSize: textSize,
        );
      }

      if (success) {
        _showMessage('✅ Multiple labels printed successfully!');
      } else {
        _showMessage('❌ Failed to print multiple labels');
      }
    } catch (e) {
      _showMessage('❌ Error printing multiple labels: $e');
    }
  }

  bool _shouldUseForcedTSPL() {
    final deviceName = _connectedDevice?.name?.toLowerCase() ?? '';
    return deviceName.contains('kt58l') || 
           deviceName.contains('romeson') || 
           deviceName.contains('esc/pos');
  }

  void _addLabelData() {
    final qrData = _qrDataController.text.isNotEmpty ? _qrDataController.text : 'QR_${_multipleLabelsData.length + 1}';
    final textData1 = _textData1Controller.text.isNotEmpty ? _textData1Controller.text : 'Customer_${_multipleLabelsData.length + 1}';
    final textData2 = _textData2Controller.text.isNotEmpty ? _textData2Controller.text : 'Drop_${_multipleLabelsData.length + 1}';
    final textData3 = _textData3Controller.text.isNotEmpty ? _textData3Controller.text : 'Ref_${_multipleLabelsData.length + 1}';

    setState(() {
      _multipleLabelsData.add({
        'qrData': qrData,
        'textData1': textData1,
        'textData2': textData2,
        'textData3': textData3,
      });
    });
    
    _showMessage('➕ Added label data: $qrData - $textData1, $textData2, $textData3');
  }

  void _removeLabelData(int index) {
    setState(() {
      _multipleLabelsData.removeAt(index);
    });
    _showMessage('🗑️ Removed label ${index + 1}');
  }

  void _clearLabelData() {
    setState(() {
      _multipleLabelsData.clear();
    });
    _showMessage('🗑️ Cleared all label data');
  }

  void _showMessage(String message) {
    if (mounted && ScaffoldMessenger.of(context).mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // Also print to console for debugging
    print('NTBP Plugin: $message');
  }

  Widget _buildStatusButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildConfigField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: helperText,
      ),
      keyboardType: keyboardType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: const Text('NTBP Plugin - Enhanced Bluetooth'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Responsive button layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          // Wide layout - horizontal buttons
                          return Row(
                            children: [
                              Expanded(
                                child: _buildStatusButton(
                                  onPressed: _requestPermissions,
                                  icon: Icons.security,
                                  label: 'Check Permissions',
                                  backgroundColor: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatusButton(
                                  onPressed: _isInitialized ? _startDiscovery : null,
                                  icon: Icons.search,
                                  label: _isDiscovering ? 'Discovering...' : 'Start Discovery',
                                  backgroundColor: Colors.green,
                                  isLoading: _isDiscovering,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatusButton(
                                  onPressed: _isDiscovering ? _stopDiscovery : null,
                                  icon: Icons.stop,
                                  label: 'Stop Discovery',
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Narrow layout - vertical buttons
                          return Column(
                            children: [
                              _buildStatusButton(
                                onPressed: _requestPermissions,
                                icon: Icons.security,
                                label: 'Check Permissions',
                                backgroundColor: Colors.orange,
                              ),
                              const SizedBox(height: 12),
                              _buildStatusButton(
                                onPressed: _isInitialized ? _startDiscovery : null,
                                icon: Icons.search,
                                label: _isDiscovering ? 'Discovering...' : 'Start Discovery',
                                backgroundColor: Colors.green,
                                isLoading: _isDiscovering,
                              ),
                              const SizedBox(height: 12),
                              _buildStatusButton(
                                onPressed: _isDiscovering ? _stopDiscovery : null,
                                icon: Icons.stop,
                                label: 'Stop Discovery',
                                backgroundColor: Colors.red,
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Protocol Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔧 Protocol Selection',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedProtocol,
                      decoration: const InputDecoration(
                        labelText: 'Printing Protocol',
                        border: OutlineInputBorder(),
                        helperText: 'Select the protocol for your printer',
                      ),
                      items: _availableProtocols.map((protocol) {
                        return DropdownMenuItem(
                          value: protocol,
                          child: Text(protocol),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProtocol = value ?? 'Auto-Detect';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Queue Status
            if (_connectionQueue.isNotEmpty || _isProcessingQueue)
              Card(
                color: Colors.amber[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔄 Connection Queue',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Status: $_queueStatus'),
                      Text('Queue Length: ${_connectionQueue.length}'),
                      if (_isProcessingQueue)
                        const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Device List
            if (_availableDevices.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔍 Available Devices (${_availableDevices.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_availableDevices.map((device) {
                        final pairingStatus = _devicePairingStatus[device.address ?? ''] ?? 'UNKNOWN';
                        final needsPairing = pairingStatus == 'NOT_PAIRED';
                        final isConnected = _connectedDevice?.address == device.address && device.address != null;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isConnected ? Colors.blue[50] : null,
                          elevation: isConnected ? 4 : 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                                      color: isConnected ? Colors.blue[700] : Colors.grey[600],
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device.name ?? 'Unknown Device',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isConnected ? Colors.blue[700] : Colors.grey[800],
                                            ),
                                          ),
                                          Text(
                                            device.address ?? '',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: needsPairing ? Colors.orange[100] : Colors.green[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: needsPairing ? Colors.orange : Colors.green,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Status: $pairingStatus',
                                        style: TextStyle(
                                          color: needsPairing ? Colors.orange[800] : Colors.green[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (isConnected) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.blue,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '✅ CONNECTED',
                                          style: TextStyle(
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    if (isConnected) ...[
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _disconnect,
                                          icon: const Icon(Icons.link_off, size: 18),
                                          label: const Text('Disconnect'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: needsPairing ? null : () => _connectToDevice(device),
                                          icon: Icon(
                                            needsPairing ? Icons.lock : Icons.link,
                                            size: 18,
                                          ),
                                          label: Text(needsPairing ? 'Pair First' : 'Connect'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: needsPairing ? Colors.grey : Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Label Configuration Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚙️ Label Configuration',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Responsive layout for configuration fields
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          // Wide layout - horizontal fields
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildConfigField(
                                      controller: _widthController,
                                      label: 'Width (mm)',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildConfigField(
                                      controller: _heightController,
                                      label: 'Height (mm)',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildConfigField(
                                      controller: _copiesController,
                                      label: 'Copies',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildConfigField(
                                      controller: _textSizeController,
                                      label: 'Text Size (1-10)',
                                      keyboardType: TextInputType.number,
                                      helperText: 'Larger numbers = bigger text',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(child: Container()), // Spacer
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildConfigField(
                                      controller: _qrDataController,
                                      label: 'QR Code Data',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildConfigField(
                                      controller: _textData1Controller,
                                      label: 'Customer Name',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildConfigField(
                                      controller: _textData2Controller,
                                      label: 'Drop Point',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildConfigField(
                                      controller: _textData3Controller,
                                      label: 'Additional Info',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        } else {
                          // Narrow layout - vertical fields
                          return Column(
                            children: [
                              _buildConfigField(
                                controller: _widthController,
                                label: 'Width (mm)',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              _buildConfigField(
                                controller: _heightController,
                                label: 'Height (mm)',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              _buildConfigField(
                                controller: _copiesController,
                                label: 'Copies',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              _buildConfigField(
                                controller: _textSizeController,
                                label: 'Text Size (1-10)',
                                keyboardType: TextInputType.number,
                                helperText: 'Larger numbers = bigger text',
                              ),
                              const SizedBox(height: 16),
                              _buildConfigField(
                                controller: _qrDataController,
                                label: 'QR Code Data',
                              ),
                              const SizedBox(height: 16),
                              _buildConfigField(
                                controller: _textData1Controller,
                                label: 'Customer Name',
                              ),
                              const SizedBox(height: 16),
                              _buildConfigField(
                                controller: _textData2Controller,
                                label: 'Drop Point',
                              ),
                              const SizedBox(height: 16),
                              _buildConfigField(
                                controller: _textData3Controller,
                                label: 'Additional Info',
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _setupSampleData,
                            icon: const Icon(Icons.data_usage, size: 18),
                            label: const Text('Load Sample Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Single Label Printing
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏷️ Single Label Printing',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _connectedDevice != null ? _printSingleLabel : null,
                        icon: const Icon(Icons.print, size: 20),
                        label: const Text('Print Single Label'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Multiple Labels Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Multiple Labels Management',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addLabelData,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Label Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _setupSampleMultipleLabels,
                            icon: const Icon(Icons.data_usage, size: 18),
                            label: const Text('Load Sample'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _multipleLabelsData.isNotEmpty ? _clearLabelData : null,
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Clear All Labels'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    if (_multipleLabelsData.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Label Data (${_multipleLabelsData.length} items):',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...(_multipleLabelsData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            title: Text('${index + 1}. ${data['qrData']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Customer: ${data['textData1'] ?? ''}'),
                                Text('Drop: ${data['textData2'] ?? ''}'),
                                Text('Ref: ${data['textData3'] ?? ''}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeLabelData(index),
                            ),
                          ),
                        );
                      })),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _connectedDevice != null ? _printMultipleLabels : null,
                          icon: const Icon(Icons.print, size: 20),
                          label: const Text('Print Multiple Labels'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Status
            if (_connectedDevice != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.bluetooth_connected, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '✅ Connected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            Text(_connectedDevice?.name ?? 'Unknown Device'),
                            Text(_connectedDevice?.address ?? ''),
                            Text('Protocol: $_selectedProtocol'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _qrDataController.dispose();
    _textData1Controller.dispose();
    _textData2Controller.dispose();
    _textData3Controller.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _copiesController.dispose();
    _textSizeController.dispose();
    _multipleLabelsController.dispose();
    super.dispose();
  }
} 