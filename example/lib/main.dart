import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

void main() {
  runApp(const NtbpExampleApp());
}

class NtbpExampleApp extends StatelessWidget {
  const NtbpExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NTBP Plugin Example',
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
  Map<String, String> _devicePairingStatus = {};
  
  // Label configuration
  final TextEditingController _qrDataController = TextEditingController();
  final TextEditingController _textDataController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _copiesController = TextEditingController();
  final TextEditingController _textSizeController = TextEditingController();
  
  // Multiple labels data
  final List<Map<String, String>> _multipleLabelsData = [];
  final TextEditingController _multipleLabelsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializePlugin();
    _setupDefaultValues();
  }

  void _setupDefaultValues() {
    _widthController.text = '75.0';
    _heightController.text = '50.0';
    _copiesController.text = '1';
    _textSizeController.text = '9';
    _qrDataController.text = 'TEST_QR_001';
    _textDataController.text = 'Sample Label Text';
  }

  Future<void> _initializePlugin() async {
    try {
      // Check if Bluetooth is available
      final isAvailable = await _ntbpPlugin.isBluetoothAvailable();
      setState(() {
        _isInitialized = isAvailable;
      });
      if (isAvailable) {
        _showMessage('✅ NTBP Plugin initialized successfully');
      } else {
        _showMessage('❌ Bluetooth not available');
      }
    } catch (e) {
      _showMessage('❌ Failed to initialize plugin: $e');
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final granted = await _ntbpPlugin.requestBluetoothPermissions();
      if (granted) {
        _showMessage('✅ Bluetooth permissions granted');
      } else {
        _showMessage('❌ Bluetooth permissions denied');
      }
    } catch (e) {
      _showMessage('❌ Error requesting permissions: $e');
    }
  }

  Future<void> _startDiscovery() async {
    try {
      setState(() {
        _isDiscovering = true;
      });
      
      await _ntbpPlugin.startScan();
      
      // Wait for discovery to complete
      await Future.delayed(const Duration(seconds: 10));
      
      final devices = await _ntbpPlugin.getDiscoveredDevices();
      
      setState(() {
        _availableDevices = devices;
        _isDiscovering = false;
      });
      
      // Check pairing status for each device
      for (final device in devices) {
        if (device.address != null) {
          final status = await _ntbpPlugin.checkDevicePairingStatus(device.address!);
          setState(() {
            _devicePairingStatus[device.address!] = status;
          });
        }
      }
      
      _showMessage('🔍 Device discovery completed. Found ${devices.length} device(s)');
    } catch (e) {
      _showMessage('❌ Error during discovery: $e');
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  Future<void> _stopDiscovery() async {
    try {
      await _ntbpPlugin.stopScan();
      setState(() {
        _isDiscovering = false;
      });
      _showMessage('⏹️ Discovery stopped');
    } catch (e) {
      _showMessage('❌ Error stopping discovery: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _showMessage('🔌 Connecting to ${device.name ?? 'Unknown Device'}...');
      
      final success = await _ntbpPlugin.connectToDevice(device);
      
      if (success) {
        setState(() {
          _connectedDevice = device;
        });
        _showMessage('✅ Connected to ${device.name ?? 'Unknown Device'}');
      } else {
        _showMessage('❌ Failed to connect to ${device.name ?? 'Unknown Device'}');
      }
    } catch (e) {
      _showMessage('❌ Connection error: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      final success = await _ntbpPlugin.disconnect();
      if (success) {
        setState(() {
          _connectedDevice = null;
        });
        _showMessage('🔌 Disconnected from device');
      } else {
        _showMessage('❌ Failed to disconnect');
      }
    } catch (e) {
      _showMessage('❌ Error disconnecting: $e');
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
      final textData = _textDataController.text.isNotEmpty ? _textDataController.text : 'Sample Text';

      _showMessage('🏷️ Printing single label: ${width}x${height}mm, $copies copies, text size: $textSize...');
      
      final success = await NtbpPlugin.printSingleLabelWithGapDetection(
        qrData: qrData,
        textData: textData,
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
      
      final success = await NtbpPlugin.printMultipleLabelsWithGapDetection(
        labelDataList: _multipleLabelsData.map((data) => {
          'qrData': data['qrData'] ?? 'QR_${DateTime.now().millisecondsSinceEpoch}',
          'textData': data['textData'] ?? 'Text_${DateTime.now().millisecondsSinceEpoch}',
        }).toList(),
        width: width,
        height: height,
        unit: 'mm',
        dpi: 203,
        copiesPerLabel: copiesPerLabel,
        textSize: textSize,
      );

      if (success) {
        _showMessage('✅ Multiple labels printed successfully!');
      } else {
        _showMessage('❌ Failed to print multiple labels');
      }
    } catch (e) {
      _showMessage('❌ Error printing multiple labels: $e');
    }
  }

  void _addLabelData() {
    final qrData = _qrDataController.text.isNotEmpty ? _qrDataController.text : 'QR_${_multipleLabelsData.length + 1}';
    final textData = _textDataController.text.isNotEmpty ? _textDataController.text : 'Text_${_multipleLabelsData.length + 1}';

    setState(() {
      _multipleLabelsData.add({
        'qrData': qrData,
        'textData': textData,
      });
    });
    
    _showMessage('➕ Added label data: $qrData - $textData');
  }

  void _clearLabelData() {
    setState(() {
      _multipleLabelsData.clear();
    });
    _showMessage('🗑️ Cleared all label data');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: const Text('NTBP Plugin - Label Printing'),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _checkPermissions,
                            icon: const Icon(Icons.security),
                            label: const Text('Check Permissions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isInitialized ? _startDiscovery : null,
                            icon: const Icon(Icons.search),
                            label: Text(_isDiscovering ? 'Discovering...' : 'Start Discovery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isDiscovering ? _stopDiscovery : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
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
                        final pairingStatus = _devicePairingStatus[device.address] ?? 'UNKNOWN';
                        final needsPairing = pairingStatus == 'NOT_PAIRED';
                        final isConnected = _connectedDevice?.address == device.address;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isConnected ? Colors.blue[50] : null,
                          child: ListTile(
                            title: Text(device.name ?? 'Unknown Device'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(device.address ?? ''),
                                Text(
                                  'Status: $pairingStatus',
                                  style: TextStyle(
                                    color: needsPairing ? Colors.orange : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isConnected)
                                  Text(
                                    '✅ CONNECTED',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isConnected) ...[
                                  ElevatedButton(
                                    onPressed: _disconnect,
                                    child: const Text('Disconnect'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ] else ...[
                                  ElevatedButton(
                                    onPressed: needsPairing ? null : () => _connectToDevice(device),
                                    child: Text(needsPairing ? 'Pair First' : 'Connect'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: needsPairing ? Colors.grey : Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            decoration: const InputDecoration(
                              labelText: 'Width (mm)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height (mm)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _copiesController,
                            decoration: const InputDecoration(
                              labelText: 'Copies',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textSizeController,
                            decoration: const InputDecoration(
                              labelText: 'Text Size (1-10)',
                              border: OutlineInputBorder(),
                              helperText: 'Larger numbers = bigger text',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(), // Spacer
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qrDataController,
                            decoration: const InputDecoration(
                              labelText: 'QR Code Data',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _textDataController,
                            decoration: const InputDecoration(
                              labelText: 'Text Data',
                              border: OutlineInputBorder(),
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
                        icon: const Icon(Icons.print),
                        label: const Text('Print Single Label'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                            icon: const Icon(Icons.add),
                            label: const Text('Add Label Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _multipleLabelsData.isNotEmpty ? _clearLabelData : null,
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
                            subtitle: Text(data['textData'] ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _multipleLabelsData.removeAt(index);
                                });
                                _showMessage('🗑️ Removed label ${index + 1}');
                              },
                            ),
                          ),
                        );
                      })),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _connectedDevice != null ? _printMultipleLabels : null,
                          icon: const Icon(Icons.print),
                          label: const Text('Print Multiple Labels'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
    _textDataController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _copiesController.dispose();
    _textSizeController.dispose();
    _multipleLabelsController.dispose();
    super.dispose();
  }
}
