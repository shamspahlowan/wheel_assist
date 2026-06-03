import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/toast_service.dart';
import 'package:toastification/toastification.dart';

class BleService {
  final CarState carState;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;

  StreamSubscription? _scanSub;
  StreamSubscription? _feedbackSub;
  Timer? _scanTimeoutTimer;

  BleService(this.carState);

  //////////////////////////////////////////////////
  // SCAN AND CONNECT
  //////////////////////////////////////////////////

  bool _isConnecting = false;
  Future<bool> startScan(BuildContext context) async {
    if (carState.isScanning || carState.isConnecting) {
      return false;
    }

    _isConnecting = false;
    carState.setScanning(true);
    carState.setConnecting(false);

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      carState.setScanning(false);
      ToastService.show(
        context,
        title: 'Bluetooth is off',
        description: 'Turn on Bluetooth before connecting to Wheel Assist.',
        type: ToastificationType.warning,
      );
      return false;
    }

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!carState.isConnected && carState.isScanning) {
          carState.setScanning(false);
          if (context.mounted) {
            ToastService.show(
              context,
              title: 'No vehicle found',
              description: 'Make sure the vehicle is on and nearby.',
              type: ToastificationType.warning,
            );
          }
        }
      });

      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (r.device.platformName == BleConstants.deviceName &&
              !_isConnecting) {
            _isConnecting = true;
            carState.setScanning(false);
            carState.setConnecting(true);
            _scanTimeoutTimer?.cancel();
            await FlutterBluePlus.stopScan();
            await _scanSub?.cancel();
            await _connect(context, r.device);
            break;
          }
        }
      });

      return true;
    } catch (e) {
      carState.setScanning(false);
      carState.setConnecting(false);
      _scanTimeoutTimer?.cancel();
      ToastService.show(
        context,
        title: 'Bluetooth scan failed',
        description: e.toString(),
        type: ToastificationType.error,
      );
      return false;
    }
  }

  //////////////////////////////////////////////////
  // CONNECT
  //////////////////////////////////////////////////

  Future<void> _connect(BuildContext context, BluetoothDevice device) async {
    try {
      _device = device;

      await device.connect(autoConnect: false, license: License.free);

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          carState.setConnected(false);
          carState.setMode(0);
        }
      });

      await Future.delayed(const Duration(seconds: 1));

      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService s in services) {
        for (BluetoothCharacteristic c in s.characteristics) {
          if (c.uuid.toString() == BleConstants.rxCharUuid) {
            _rxChar = c;
          }
          if (c.uuid.toString() == BleConstants.txCharUuid) {
            _txChar = c;
            await c.setNotifyValue(true);
            _feedbackSub = c.onValueReceived.listen(_onFeedback);
          }
        }
      }

      if (_rxChar != null && _txChar != null) {
        carState.setConnected(true);
        carState.setConnecting(false);
        carState.setScanning(false);
        if (context.mounted) {
          ToastService.show(
            context,
            title: 'Connected',
            description: 'Wheel Assist is ready.',
            type: ToastificationType.success,
          );
        }
      } else {
        carState.setConnecting(false);
        carState.setScanning(false);
        if (context.mounted) {
          ToastService.show(
            context,
            title: 'Connection incomplete',
            description: 'Required Bluetooth characteristics were not found.',
            type: ToastificationType.error,
          );
        }
      }
    } catch (e) {
      carState.setConnecting(false);
      carState.setScanning(false);
      if (context.mounted) {
        ToastService.show(
          context,
          title: 'Connection failed',
          description: e.toString(),
          type: ToastificationType.error,
        );
      }
    } finally {
      _isConnecting = false;
      _scanTimeoutTimer?.cancel();
    }
  }

  //////////////////////////////////////////////////
  // FEEDBACK FROM ESP32
  //////////////////////////////////////////////////

  void _onFeedback(List<int> data) {
    try {
      final json = jsonDecode(utf8.decode(data));
      carState.updateFeedback(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        cmd: json['cmd'] as int,
        mode: json['mode'] as int,
      );
    } catch (_) {}
  }

  //////////////////////////////////////////////////
  // SEND COMMAND
  //////////////////////////////////////////////////

  Future<void> sendCommand({
    required int mode,
    required int cmd,
    required int speed,
    int? turnSlow,
    int? speedL,
    int? speedR,
  }) async {
    if (_rxChar == null) return;

    final Map<String, dynamic> payload = {
      'mode': mode,
      'cmd': cmd,
      'speed': speed,
    };

    if (turnSlow != null) payload['turn_slow'] = turnSlow;
    if (speedL != null) payload['speed_l'] = speedL;
    if (speedR != null) payload['speed_r'] = speedR;

    final bytes = utf8.encode(jsonEncode(payload));

    await _rxChar!.write(bytes, withoutResponse: true);
  }

  //////////////////////////////////////////////////
  // DISCONNECT
  //////////////////////////////////////////////////

  Future<void> disconnect() async {
    await _feedbackSub?.cancel();
    await _scanSub?.cancel();
    _scanTimeoutTimer?.cancel();
    await _device?.disconnect();
    _rxChar = null;
    _txChar = null;
    _device = null;
    carState.setScanning(false);
    carState.setConnecting(false);
    carState.setConnected(false);
    carState.setMode(0);
  }
}
