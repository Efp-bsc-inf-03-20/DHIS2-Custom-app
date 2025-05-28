import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';

// Simple wrapper for Bluetooth device
class BluetoothDeviceWrapper {
  final BluetoothDevice device;
  int rssi;
  String? _cachedName;
  bool _isConnectable = true;

  BluetoothDeviceWrapper({
    required this.device,
    required this.rssi,
    String? name,
  }) {
    if (name != null && name.isNotEmpty) {
      _cachedName = name;
    }
  }

  String get id => device.remoteId.str;

  String get name {
    if (_cachedName != null && _cachedName!.isNotEmpty) {
      return _cachedName!;
    }

    if (device.platformName.isNotEmpty) {
      _cachedName = device.platformName;
      return device.platformName;
    }

    final shortId = device.remoteId.str.substring(
      max(0, device.remoteId.str.length - 5),
    );
    return 'Device $shortId';
  }

  set name(String newName) {
    if (newName.isNotEmpty) {
      _cachedName = newName;
    }
  }

  bool get isESP32Thermo {
    if (name.toLowerCase().contains('esp32') ||
        name.toLowerCase().contains('thermo')) {
      return true;
    }

    return false;
  }

  bool get isConnectable => _isConnectable;
  set isConnectable(bool value) => _isConnectable = value;

  @override
  String toString() => 'Device: $name (${device.remoteId.str}), RSSI: $rssi';
}

class BluetoothProvider with ChangeNotifier {
  BluetoothDeviceWrapper? selectedDevice;
  StreamSubscription? _connectionSubscription;
  bool isConnected = false;
  String temperatureValue = "No reading";
  bool _isReading = false;
  bool get isReading => _isReading;
  bool _isConnecting = false;

  static const String esp32DeviceName = BluetoothConstants.deviceName;
  static const String temperatureServiceUuid = BluetoothConstants.serviceUuid;
  static const String temperatureCharacteristicUuid =
      BluetoothConstants.characteristicUuid;
  bool _isProcessingBluetoothAction = false;
  String _bluetoothActionStatus = "";
  Timer? _stateResetTimer;
  Timer? _updateTimer;

  bool get isProcessingBluetoothAction => _isProcessingBluetoothAction;
  String get bluetoothActionStatus => _bluetoothActionStatus;
  bool get isConnecting => _isConnecting;

  void resetConnectionState() {
    if (kDebugMode) {
      print("Resetting Bluetooth connection state flags");
    }
    _isProcessingBluetoothAction = false;
    _bluetoothActionStatus = "";
    _isConnecting = false;
    _stateResetTimer?.cancel();
    _stateResetTimer = null;

    Future.microtask(() => notifyListeners());
  }

  void _safeUpdateState(Function() updateFunction) {
    updateFunction();

    _updateTimer?.cancel();
    _updateTimer = Timer(Duration.zero, () {
      notifyListeners();
    });
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      if (kDebugMode) {
        print("Error checking Bluetooth state: $e");
      }
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
        if (kDebugMode) {
          print("$permission not granted. Status: $status");
        }
      }
    });
    return allGranted;
  }

  Future<bool> findAndConnectToESP32() async {
    _safeUpdateState(() {
      _isProcessingBluetoothAction = true;
      _bluetoothActionStatus = "Looking for ESP32-Thermo device...";
      _isConnecting = true;
    });

    try {
      bool isEnabled = await isBluetoothEnabled();
      if (!isEnabled) {
        _safeUpdateState(() {
          _bluetoothActionStatus =
              "Bluetooth is turned off. Please turn it on.";
          _isProcessingBluetoothAction = false;
          _isConnecting = false;
        });
        return false;
      }

      bool permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        _safeUpdateState(() {
          _bluetoothActionStatus = "Bluetooth permissions not granted.";
          _isProcessingBluetoothAction = false;
          _isConnecting = false;
        });
        return false;
      }

      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _safeUpdateState(() {
        _bluetoothActionStatus = "Scanning for ESP32-Thermo device...";
      });

      bool deviceFound = false;
      BluetoothDeviceWrapper? targetDevice;
      Completer<bool> deviceFoundCompleter = Completer<bool>();

      Timer timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!deviceFoundCompleter.isCompleted) {
          deviceFoundCompleter.complete(false);
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );

      StreamSubscription<List<ScanResult>>? scanSubscription;
      scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (var result in results) {
            String deviceName = result.device.platformName.toLowerCase();

            if (deviceName.contains(esp32DeviceName.toLowerCase()) ||
                (deviceName.contains('esp32') &&
                    deviceName.contains('thermo'))) {
              if (kDebugMode) {
                print(
                  "Found ESP32-Thermo device: ${result.device.platformName}, ID: ${result.device.remoteId.str}",
                );
              }

              targetDevice = BluetoothDeviceWrapper(
                device: result.device,
                rssi: result.rssi,
                name: result.device.platformName,
              );

              deviceFound = true;
              FlutterBluePlus.stopScan();

              if (!deviceFoundCompleter.isCompleted) {
                deviceFoundCompleter.complete(true);
              }
              break;
            }
          }
        },
        onError: (e) {
          if (kDebugMode) {
            print("Scan results stream error: $e");
          }
          _safeUpdateState(() {
            _bluetoothActionStatus = "Error during scan: $e";
            _isProcessingBluetoothAction = false;
            _isConnecting = false;
          });
          if (!deviceFoundCompleter.isCompleted) {
            deviceFoundCompleter.complete(false);
          }
        },
        onDone: () {
          scanSubscription?.cancel();

          if (!deviceFoundCompleter.isCompleted && !deviceFound) {
            deviceFoundCompleter.complete(false);
          }
        },
      );

      deviceFound = await deviceFoundCompleter.future;
      timeoutTimer.cancel();
      scanSubscription.cancel();

      if (!deviceFound || targetDevice == null) {
        _safeUpdateState(() {
          _bluetoothActionStatus =
              "ESP32-Thermo device not found. Please make sure it's powered on and nearby.";
          _isProcessingBluetoothAction = false;
          _isConnecting = false;
        });
        return false;
      }

      selectedDevice = targetDevice;
      _safeUpdateState(() {
        _bluetoothActionStatus = "Connecting to ESP32-Thermo...";
      });

      return await connectToDevice(selectedDevice!);
    } catch (e) {
      if (kDebugMode) {
        print("Error finding/connecting to ESP32-Thermo: $e");
      }
      _safeUpdateState(() {
        _bluetoothActionStatus = "Error: $e";
        _isProcessingBluetoothAction = false;
        _isConnecting = false;
      });
      return false;
    }
  }

  Future<bool> connectToDevice(BluetoothDeviceWrapper device) async {
    _safeUpdateState(() {
      _isConnecting = true;
      _isProcessingBluetoothAction = true;
      _bluetoothActionStatus = "Connecting to ${device.name}...";
    });

    try {
      _stateResetTimer = Timer(const Duration(seconds: 30), () {
        if (_isConnecting) {
          if (kDebugMode) {
            print("Connection attempt timed out after 30 seconds");
          }
          resetConnectionState();
        }
      });

      if (device.device.isConnected) {
        await device.device.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (kDebugMode) {
        print("Attempting to connect to ${device.name}");
      }

      await device.device.connect(autoConnect: false);
      await Future.delayed(const Duration(milliseconds: 500));

      final connectionState = device.device.connectionState.listen((
        state,
      ) async {
        if (state == BluetoothConnectionState.connected) {
          if (kDebugMode) {
            print("Connected to ${device.name}");
          }

          isConnected = true;
          selectedDevice = device;
          _safeUpdateState(() {
            _bluetoothActionStatus = "Connected to ${device.name}";
            _isConnecting = false;
            _isProcessingBluetoothAction = false;
          });

          await _startTemperatureMonitoring();
        } else if (state == BluetoothConnectionState.disconnected) {
          if (kDebugMode) {
            print("Disconnected from ${device.name}");
          }

          isConnected = false;
          _safeUpdateState(() {
            _bluetoothActionStatus = "Disconnected from ${device.name}";
            _isProcessingBluetoothAction = false;
            _isConnecting = false;
          });
        }
      });

      _connectionSubscription = connectionState;
      _stateResetTimer?.cancel();
      _stateResetTimer = null;

      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Error connecting to device: $e");
      }
      _safeUpdateState(() {
        _bluetoothActionStatus = "Connection failed: $e";
        _isProcessingBluetoothAction = false;
        _isConnecting = false;
      });
      return false;
    }
  }

  Future<void> _startTemperatureMonitoring() async {
    if (selectedDevice == null || !isConnected) {
      if (kDebugMode) {
        print("Cannot start monitoring - no connected device");
      }
      return;
    }

    try {
      _safeUpdateState(() {
        _isReading = true;
      });

      if (kDebugMode) {
        print("Discovering services for ${selectedDevice!.name}");
      }

      List<BluetoothService> services =
          await selectedDevice!.device.discoverServices();

      BluetoothService? tempService;
      for (var service in services) {
        if (service.uuid.toString() == temperatureServiceUuid) {
          tempService = service;
          break;
        }
      }

      if (tempService == null) {
        if (kDebugMode) {
          print("Temperature service not found");
        }
        _safeUpdateState(() {
          _isReading = false;
          temperatureValue = "Service not found";
        });
        return;
      }

      BluetoothCharacteristic? tempCharacteristic;
      for (var char in tempService.characteristics) {
        if (char.uuid.toString() == temperatureCharacteristicUuid) {
          tempCharacteristic = char;
          break;
        }
      }

      if (tempCharacteristic == null) {
        if (kDebugMode) {
          print("Temperature characteristic not found");
        }
        _safeUpdateState(() {
          _isReading = false;
          temperatureValue = "Characteristic not found";
        });
        return;
      }

      await tempCharacteristic.setNotifyValue(true);

      tempCharacteristic.onValueReceived.listen(
        (value) {
          _processTemperatureData(value);
        },
        onError: (error) {
          if (kDebugMode) {
            print("Error receiving temperature data: $error");
          }
          _safeUpdateState(() {
            temperatureValue = "Error reading data";
            _isReading = false;
          });
        },
      );

      await tempCharacteristic.read();
    } catch (e) {
      if (kDebugMode) {
        print("Error starting temperature monitoring: $e");
      }
      _safeUpdateState(() {
        temperatureValue = "Error: $e";
        _isReading = false;
      });
    }
  }

  void _processTemperatureData(List<int> data) {
    try {
      final tempString = utf8.decode(data);

      if (kDebugMode) {
        print("Received temperature data: $tempString");
      }

      _safeUpdateState(() {
        temperatureValue = tempString;
        _isReading = true;
      });
    } catch (e) {
      if (data.isNotEmpty) {
        try {
          final tempValue = data.toString();
          _safeUpdateState(() {
            temperatureValue = tempValue;
            _isReading = true;
          });
        } catch (e) {
          if (kDebugMode) {
            print("Error processing temperature data: $e");
          }
          _safeUpdateState(() {
            temperatureValue = "Invalid data";
            _isReading = false;
          });
        }
      }
    }
  }

  // Parse temp value
  double? getTemperatureAsDouble() {
    if (temperatureValue == "No reading" ||
        temperatureValue == "Error reading data" ||
        temperatureValue == "Service not found" ||
        temperatureValue == "Characteristic not found" ||
        temperatureValue == "Invalid data") {
      return null;
    }

    try {
      String sanitized = temperatureValue.replaceAll('°C', '').trim();
      return double.parse(sanitized);
    } catch (e) {
      if (kDebugMode) {
        print("Error parsing temperature value: $e");
      }
      return null;
    }
  }

  // Trigger temperature reading
  Future<void> startTemperatureReading() async {
    if (!isConnected || selectedDevice == null) {
      return;
    }

    _safeUpdateState(() {
      _isReading = true;
      _bluetoothActionStatus = "Reading temperature...";
    });

    try {
      await _startTemperatureMonitoring();
    } catch (e) {
      if (kDebugMode) {
        print("Error starting temperature reading: $e");
      }
      _safeUpdateState(() {
        _isReading = false;
        temperatureValue = "Error reading temperature";
      });
    }
  }

  Future<void> disconnect() async {
    _safeUpdateState(() {
      _isProcessingBluetoothAction = true;
      _bluetoothActionStatus = "Disconnecting...";
    });

    try {
      _connectionSubscription?.cancel();
      _connectionSubscription = null;

      if (selectedDevice != null && selectedDevice!.device.isConnected) {
        await selectedDevice!.device.disconnect();
      }

      _safeUpdateState(() {
        isConnected = false;
        _isReading = false;
        temperatureValue = "No reading";
        _bluetoothActionStatus = "Disconnected";
        _isProcessingBluetoothAction = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error disconnecting: $e");
      }
      _safeUpdateState(() {
        _bluetoothActionStatus = "Error disconnecting: $e";
        _isProcessingBluetoothAction = false;
      });
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _stateResetTimer?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }
}
