import 'package:flutter/material.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

/// Example demonstrating the new scalable protocol system
class ProtocolExample extends StatefulWidget {
  const ProtocolExample({super.key});

  @override
  State<ProtocolExample> createState() => _ProtocolExampleState();
}

class _ProtocolExampleState extends State<ProtocolExample> {
  String _selectedPrinter = 'N41';
  String _status = 'Ready';
  bool _isLoading = false;

  final List<String> _supportedPrinters = [
    'N41', 'KT58L', 'Romeson', 'TSPL', 'ESC/POS'
  ];

  @override
  void initState() {
    super.initState();
    _checkSupportedPrinters();
  }

  void _checkSupportedPrinters() {
    final supported = NtbpPlugin.getSupportedPrinterModels();
    setState(() {
      _status = 'Supported printers: $supported';
    });
  }

  Future<void> _initializeProtocol() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing protocol...';
    });

    try {
      final success = await NtbpPlugin.initializeProtocol(_selectedPrinter);
      
      if (success) {
        final info = NtbpPlugin.getProtocolInfo();
        setState(() {
          _status = 'Protocol initialized: ${info['currentProtocol']} for $_selectedPrinter';
        });
        
        // Show capabilities
        final capabilities = info['capabilities'] as Map<String, dynamic>;
        _showCapabilities(capabilities);
      } else {
        setState(() {
          _status = 'Failed to initialize protocol for $_selectedPrinter';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _autoDetectProtocol() async {
    setState(() {
      _isLoading = true;
      _status = 'Auto-detecting protocol...';
    });

    try {
      final success = await NtbpPlugin.autoDetectProtocol(
        deviceName: _selectedPrinter,
      );
      
      if (success) {
        final info = NtbpPlugin.getProtocolInfo();
        setState(() {
          _status = 'Auto-detected: ${info['currentProtocol']} for ${info['currentPrinterModel']}';
        });
      } else {
        setState(() {
          _status = 'Auto-detection failed';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _printTestLabel() async {
    if (!NtbpPlugin.getProtocolInfo()['isInitialized']) {
      setState(() {
        _status = 'Please initialize protocol first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Printing test label...';
    });

    try {
      final success = await NtbpPlugin.printSingleLabelWithProtocol(
        qrData: 'Test QR Code',
        textData: 'Test Label',
        labelWidth: 75.0,
        labelHeight: 50.0,
        unit: 'mm',
        dpi: 203,
        copies: 1,
        textSize: 8,
      );
      
      setState(() {
        _status = success ? 'Test label printed successfully!' : 'Failed to print test label';
      });
    } catch (e) {
      setState(() {
        _status = 'Error printing: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCapabilities(Map<String, dynamic> capabilities) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Protocol Capabilities'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Protocol: ${capabilities['protocolName']}'),
            Text('Printer: ${capabilities['printerModel']}'),
            const SizedBox(height: 16),
            Text('Features:', style: Theme.of(context).textTheme.titleMedium),
            ...capabilities.entries
                .where((entry) => entry.key != 'protocolName' && entry.key != 'printerModel' && entry.key != 'supported')
                .map((entry) => Text('• ${entry.key}: ${entry.value}')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protocol System Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scalable Protocol System',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This example demonstrates the new scalable architecture that supports multiple printer protocols (TSPL, ESC/POS) automatically.',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Printer Selection',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedPrinter,
                      decoration: const InputDecoration(
                        labelText: 'Select Printer Model',
                        border: OutlineInputBorder(),
                      ),
                      items: _supportedPrinters.map((printer) {
                        return DropdownMenuItem(
                          value: printer,
                          child: Text(printer),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedPrinter = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protocol Management',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _initializeProtocol,
                            child: const Text('Initialize Protocol'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _autoDetectProtocol,
                            child: const Text('Auto-Detect'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _printTestLabel,
                        child: const Text('Print Test Label'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_status),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protocol Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, dynamic>>(
                      future: Future.value(NtbpPlugin.getProtocolInfo()),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final info = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Initialized: ${info['isInitialized']}'),
                              Text('Protocol: ${info['currentProtocol'] ?? 'None'}'),
                              Text('Printer: ${info['currentPrinterModel'] ?? 'None'}'),
                            ],
                          );
                        }
                        return const Text('Loading...');
                      },
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
} 