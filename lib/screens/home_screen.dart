import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/screens/about_screen.dart';
import 'package:wheel_assist/screens/camera_screen.dart';
import 'package:wheel_assist/services/auto_stop_service.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/services/toast_service.dart';
import 'package:wheel_assist/services/voice_service.dart';
import 'package:wheel_assist/widgets/control_pad.dart';
import 'package:wheel_assist/widgets/mode_toggle.dart';
import 'package:wheel_assist/widgets/speed_slider.dart';
import 'package:wheel_assist/widgets/status_bar.dart';

enum _HomeMenuAction { about, disconnect }

class HomeScreen extends StatefulWidget {
  final BleService bleService;
  final VoiceService voiceService;
  final AutoStopService autoStopService;

  const HomeScreen({
    super.key,
    required this.bleService,
    required this.voiceService,
    required this.autoStopService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.read<CarState>();
    final isConnected = context.select((CarState s) => s.isConnected);
    final isScanning = context.select((CarState s) => s.isScanning);
    final isConnecting = context.select((CarState s) => s.isConnecting);
    final cameraIp = context.select((CarState s) => s.cameraIp);
    final isVoiceMode = context.select((CarState s) => s.isVoiceMode);
    final lastWord = context.select((CarState s) => s.lastWord);
    final mode = context.select((CarState s) => s.mode);
    final speed = context.select((CarState s) => s.speed);
    final turnSlow = context.select((CarState s) => s.turnSlow);
    final speedLeft = context.select((CarState s) => s.speedLeft);
    final speedRight = context.select((CarState s) => s.speedRight);
    final currentCommand = context.select((CarState s) => s.currentCommand);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Wheel Assist',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          PopupMenuButton<_HomeMenuAction>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem<_HomeMenuAction>(
                value: _HomeMenuAction.about,
                child: Text('About'),
              ),
              if (isConnected)
                const PopupMenuItem<_HomeMenuAction>(
                  value: _HomeMenuAction.disconnect,
                  child: Text('Disconnect'),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isConnected
              ? _buildConnectedContent(
                  state: state,
                  cameraIp: cameraIp,
                  isVoiceMode: isVoiceMode,
                  lastWord: lastWord,
                  mode: mode,
                  speed: speed,
                  turnSlow: turnSlow,
                  speedLeft: speedLeft,
                  speedRight: speedRight,
                  currentCommand: currentCommand,
                )
              : _buildDisconnectedContent(
                  isScanning: isScanning,
                  isConnecting: isConnecting,
                ),
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(_HomeMenuAction action) async {
    switch (action) {
      case _HomeMenuAction.about:
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        );
        break;
      case _HomeMenuAction.disconnect:
        await widget.bleService.disconnect();
        if (!mounted) return;
        ToastService.show(
          context,
          title: 'Disconnected',
          description: 'Bluetooth link closed.',
        );
        break;
    }
  }

  Future<void> _handleConnectPressed() async {
    final started = await widget.bleService.startScan(context);
    if (started && mounted) {
      ToastService.show(
        context,
        title: 'Scanning',
        description: 'Looking for the Wheel Assist vehicle.',
      );
    }
  }

  Widget _buildDisconnectedContent({
    required bool isScanning,
    required bool isConnecting,
  }) {
    final isBusy = isScanning || isConnecting;
    final label = isScanning
        ? 'Scanning...'
        : isConnecting
        ? 'Connecting...'
        : 'Connect Bluetooth';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8A00), Color(0xFFFF4D00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bluetooth,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Connect to your vehicle to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Once the Bluetooth link is established, the full control panel will appear automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : _handleConnectPressed,
                    icon: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(label),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (isBusy) ...[
                  const SizedBox(height: 14),
                  Text(
                    isScanning
                        ? 'Searching for the Wheel Assist device...'
                        : 'Preparing the Bluetooth connection...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedContent({
    required CarState state,
    required String cameraIp,
    required bool isVoiceMode,
    required String lastWord,
    required int mode,
    required int speed,
    required int turnSlow,
    required int speedLeft,
    required int speedRight,
    required int currentCommand,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (cameraIp.isEmpty) {
                      _showIpDialog(context, state);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CameraScreen(
                            autoStopService: widget.autoStopService,
                            cameraIp: cameraIp,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.videocam),
                  label: const Text('CAMERA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    const Text(
                      'AUTO STOP',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Switch(
                      value: context.select((CarState s) => s.isAutoStop),
                      activeColor: Colors.redAccent,
                      onChanged: (val) => state.setAutoStop(val),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const StatusBar(),
            const SizedBox(height: 24),
            ModeToggle(bleService: widget.bleService),
            const SizedBox(height: 24),
            if (mode == 1) ...[
              GestureDetector(
                onTap: () => widget.voiceService.toggleVoiceMode(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isVoiceMode ? Colors.redAccent : Colors.white10,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isVoiceMode ? Colors.redAccent : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVoiceMode ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVoiceMode ? 'VOICE ON' : 'VOICE OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (lastWord.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"$lastWord"',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
            if (!isVoiceMode) ...[
              ControlPad(bleService: widget.bleService),
              const SizedBox(height: 32),
            ],
            SpeedSlider(bleService: widget.bleService),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              'TUNING',
              style: TextStyle(
                color: Colors.white38,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TURN ARC',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '$turnSlow',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: turnSlow.toDouble(),
              min: 0,
              max: 180,
              divisions: 36,
              activeColor: Colors.deepOrange,
              inactiveColor: Colors.white12,
              onChangeEnd: (val) async {
                state.setTurnSlow(val.toInt());
                await widget.bleService.sendCommand(
                  mode: mode,
                  cmd: currentCommand,
                  speed: speed,
                  turnSlow: val.toInt(),
                );
              },
              onChanged: (val) => state.setTurnSlow(val.toInt()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DRIFT LEFT',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '$speedLeft',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: speedLeft.toDouble(),
              min: 150,
              max: 255,
              divisions: 21,
              activeColor: Colors.deepOrange,
              inactiveColor: Colors.white12,
              onChangeEnd: (val) async {
                state.setSpeedLeft(val.toInt());
                await widget.bleService.sendCommand(
                  mode: mode,
                  cmd: currentCommand,
                  speed: speed,
                  speedL: val.toInt(),
                );
              },
              onChanged: (val) => state.setSpeedLeft(val.toInt()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DRIFT RIGHT',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '$speedRight',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: speedRight.toDouble(),
              min: 150,
              max: 255,
              divisions: 21,
              activeColor: Colors.deepOrange,
              inactiveColor: Colors.white12,
              onChangeEnd: (val) async {
                state.setSpeedRight(val.toInt());
                await widget.bleService.sendCommand(
                  mode: mode,
                  cmd: currentCommand,
                  speed: speed,
                  speedR: val.toInt(),
                );
              },
              onChanged: (val) => state.setSpeedRight(val.toInt()),
            ),
          ],
        ),
      ),
    );
  }

  void _showIpDialog(BuildContext context, CarState state) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Camera IP', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '192.168.1.100',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final ip = controller.text.trim();
              state.setCameraIp(ip);
              Navigator.pop(context);
              await widget.autoStopService.start(ip);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraScreen(
                    autoStopService: widget.autoStopService,
                    cameraIp: ip,
                  ),
                ),
              );
            },
            child: const Text(
              'CONNECT',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}
