import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../constants/app_constants.dart';

class BluetoothDeviceSelectionScreen extends StatefulWidget {
  const BluetoothDeviceSelectionScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothDeviceSelectionScreen> createState() =>
      _BluetoothDeviceSelectionScreenState();
}

class _BluetoothDeviceSelectionScreenState
    extends State<BluetoothDeviceSelectionScreen> {
  bool _isConnecting = false;
  String _statusMessage = "Looking for ESP32-Thermo device...";

  @override
  void initState() {
    super.initState();
    _connectToESP32();
  }

  Future<void> _connectToESP32() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = "Looking for ESP32-Thermo device...";
    });

    final bluetoothProvider = Provider.of<BluetoothProvider>(
      context,
      listen: false,
    );

    try {
      bool success = await bluetoothProvider.findAndConnectToESP32();

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _isConnecting = false;
            _statusMessage =
                "Failed to connect to ESP32-Thermo device. Tap to retry.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = "Error: $e. Tap to retry.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Thermometer'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<BluetoothProvider>(
        builder: (context, bluetoothProvider, child) {
          String displayStatus = _statusMessage;
          if (bluetoothProvider.isProcessingBluetoothAction &&
              bluetoothProvider.bluetoothActionStatus.isNotEmpty) {
            displayStatus = bluetoothProvider.bluetoothActionStatus;
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.thermostat_rounded,
                    color: Colors.blue,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'ESP32-Thermo Device',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    displayStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ),

                const SizedBox(height: 32),

                if (_isConnecting || bluetoothProvider.isConnecting)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _connectToESP32,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
