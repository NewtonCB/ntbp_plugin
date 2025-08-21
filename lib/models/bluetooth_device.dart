class BluetoothDevice {
  final String name;
  final String address;
  final bool isConnected;
  final int rssi;
  final String? deviceClass;

  BluetoothDevice({
    required this.name,
    required this.address,
    this.isConnected = false,
    this.rssi = 0,
    this.deviceClass,
  });

  factory BluetoothDevice.fromMap(Map<String, dynamic> map) {
    return BluetoothDevice(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      isConnected: map['isConnected'] ?? false,
      rssi: map['rssi'] ?? 0,
      deviceClass: map['deviceClass'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'isConnected': isConnected,
      'rssi': rssi,
      'deviceClass': deviceClass,
    };
  }

  @override
  String toString() {
    return 'BluetoothDevice(name: $name, address: $address, isConnected: $isConnected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothDevice && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;
} 