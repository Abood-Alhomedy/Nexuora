import 'package:nexuora/main.dart';
import 'package:nexuora/services/wifi_device_service.dart';
import 'package:nexuora/utils/AppColors.dart';
import 'package:nexuora/utils/AppConstant.dart';
import 'package:nexuora/utils/AppFunctions.dart';
import 'package:nexuora/utils/AppWidget.dart';
import 'package:nexuora/widgets/screen_json_parser_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:nb_utils/nb_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dialog الرئيسي — Wi-Fi ADB Run
// ─────────────────────────────────────────────────────────────────────────────

class WiFiRunDialog extends StatefulWidget {
  const WiFiRunDialog({Key? key}) : super(key: key);

  @override
  _WiFiRunDialogState createState() => _WiFiRunDialogState();
}

class _WiFiRunDialogState extends State<WiFiRunDialog>
    with SingleTickerProviderStateMixin {
  // ─── خطوات Dialog ───
  static const int _stepConnect  = 0;
  static const int _stepDevices  = 1;
  static const int _stepRunning  = 2;

  int  _step      = _stepConnect;
  bool _isLoading = false;

  // ─── Controllers ────
  final TextEditingController _ipCtrl   = TextEditingController();
  final TextEditingController _portCtrl = TextEditingController(text: '5555');

  // ─── State ──────────
  String?         _connectedDeviceId;
  List<WiFiDevice> _devices = [];
  WiFiDevice?     _selectedDevice;
  String          _statusText = '';
  bool            _isRunning  = false;
  int?            _runningPid;

  final WiFiDeviceService _svc = WiFiDeviceService();

  // ─── Animation ──────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _fetchDevices();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  // ─────────────── Actions ──────────────────────────────────────

  Future<void> _fetchDevices() async {
    setState(() { _isLoading = true; _statusText = 'Checking connected devices…'; });
    try {
      final list = await _svc.getDevices();
      setState(() {
        _devices = list;
        if (_devices.isNotEmpty) {
          _selectedDevice ??= _devices.first;
          if (_step == _stepConnect) {
            _step = _stepDevices;
          }
          _statusText = '✅ Found ${_devices.length} device(s)';
        } else {
          _statusText = '';
        }
      });
    } catch (e) {
      setState(() => _statusText = '❌ ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _detectViaUsb() async {
    setState(() { _isLoading = true; _statusText = 'Detecting device via USB…'; });
    try {
      final list = await _svc.detectFromUsb();
      setState(() {
        _devices = list;
        if (_devices.isNotEmpty) {
          _selectedDevice = _devices.first;
          _connectedDeviceId = _selectedDevice?.id;
          _step = _stepDevices;
          _statusText = '✅ Detected and connected via USB';
          getToast('✅ Device detected via USB');
        } else {
          _statusText = '⚠️ No USB devices detected';
          getToast('No device found via USB');
        }
      });
    } catch (e) {
      setState(() => _statusText = '❌ ${e.toString()}');
      getToast(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectByIp() async {
    final ip   = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 5555;

    if (ip.isEmpty) {
      getToast('Please enter device IP address');
      return;
    }

    setState(() { _isLoading = true; _statusText = 'Connecting to $ip:$port…'; });

    try {
      final device = await _svc.connect(ip: ip, port: port);
      setState(() {
        _connectedDeviceId = device.id;
        _devices.removeWhere((d) => d.id == device.id);
        _devices.insert(0, device);
        _selectedDevice = device;
        _step           = _stepDevices;
        _statusText     = '✅ Connected to ${device.id}';
      });
    } catch (e) {
      setState(() => _statusText = '❌ ${e.toString()}');
      getToast(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runProject() async {
    if (_selectedDevice == null) {
      getToast('Please select a device first');
      return;
    }

    setState(() {
      _isLoading  = true;
      _step       = _stepRunning;
      _statusText = 'Preparing project…';
    });

    try {
      // تجميع بيانات الشاشات
      final screens = appStore.screenList
          .where((s) => s.id != null && s.id! > 0)
          .map((s) => {
                'id':   s.id,
                'name': s.name ?? 'Screen',
                'data': s.screenJsonData,
              })
          .toList();

      setState(() => _statusText = 'Launching flutter run…');

      final result = await _svc.run(
        projectId:   appStore.projectId ?? 0,
        projectName: appStore.projectName ?? 'NexuoraApp',
        deviceId:    _selectedDevice!.id,
        screens:     screens,
      );

      if (result.success) {
        setState(() {
          _isRunning  = true;
          _runningPid = result.pid;
          _statusText = '✅ Running on ${_selectedDevice!.name}';
        });
        getToast('✅ App launched on ${_selectedDevice!.name}');
      } else {
        setState(() {
          _step       = _stepDevices;
          _statusText = '❌ ${result.message ?? 'Failed'}';
        });
        getToast(result.message ?? 'Failed to run');
      }
    } catch (e) {
      setState(() {
        _step       = _stepDevices;
        _statusText = '❌ $e';
      });
      getToast(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _hotReload() async {
    setState(() { _isLoading = true; _statusText = '🔄 Hot reloading…'; });
    try {
      final screens = appStore.screenList
          .where((s) => s.id != null && s.id! > 0)
          .map((s) => {'id': s.id, 'name': s.name ?? 'Screen', 'data': s.screenJsonData})
          .toList();

      final ok = await _svc.hotReload(
        projectId: appStore.projectId ?? 0,
        screens:   screens,
      );
      setState(() => _statusText = ok ? '✅ Hot reload done' : '⚠️ Hot reload failed');
    } catch (e) {
      setState(() => _statusText = '❌ $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _stopProject() async {
    setState(() { _isLoading = true; _statusText = 'Stopping…'; });
    try {
      await _svc.stop(appStore.projectId ?? 0);
      setState(() {
        _isRunning  = false;
        _runningPid = null;
        _step       = _stepDevices;
        _statusText = '⏹ Stopped';
      });
    } catch (e) {
      setState(() => _statusText = '❌ $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = appStore.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width:  480,
        decoration: BoxDecoration(
          color:        isDark ? darkModeSecondaryBackgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(isDark ? 0.5 : 0.15),
              blurRadius: 30,
              offset:     const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark),
            _buildStepIndicator(isDark),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStepContent(isDark),
            ),
            if (_statusText.isNotEmpty) _buildStatusBar(isDark),
            _buildActions(isDark),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [btnBackgroundColor, const Color(0xFF1a3ab8)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulse,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wifi, color: Colors.white, size: 22),
            ),
          ),
          12.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Run on Device',
                    style: boldTextStyle(color: Colors.white, size: 16)),
                Text('Wi-Fi ADB Connection',
                    style: secondaryTextStyle(color: Colors.white70, size: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => finish(context),
          ),
        ],
      ),
    );
  }

  // ─── Step Indicator ──────────────────────────────────────────

  Widget _buildStepIndicator(bool isDark) {
    final steps = ['Connect', 'Select', 'Running'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: (i ~/ 2) < _step
                    ? btnBackgroundColor
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
              ),
            );
          }
          final idx     = i ~/ 2;
          final active  = idx == _step;
          final done    = idx < _step;
          return _StepDot(index: idx + 1, label: steps[idx], active: active, done: done, isDark: isDark);
        }),
      ),
    );
  }

  // ─── Step Content ─────────────────────────────────────────────

  Widget _buildStepContent(bool isDark) {
    switch (_step) {
      case _stepConnect:
        return _buildConnectStep(isDark);
      case _stepDevices:
        return _buildDevicesStep(isDark);
      case _stepRunning:
        return _buildRunningStep(isDark);
      default:
        return const SizedBox();
    }
  }

  // Step 0: Connect
  Widget _buildConnectStep(bool isDark) {
    return Padding(
      key: const ValueKey('connect'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── زر الاكتشاف التلقائي (الأبرز) ──────────────────
          GestureDetector(
            onTap: _isLoading ? null : _detectViaUsb,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [btnBackgroundColor, Color(0xFF1a3ab8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: btnBackgroundColor.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.usb, color: Colors.white, size: 20),
                        8.width,
                        const Text(
                          '⚡ Auto-detect via USB',
                          style: TextStyle(
                            color:      Colors.white,
                            fontSize:   14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          12.height,
          // شرح الخطوات
          _InfoCard(
            isDark: isDark,
            icon:  Icons.usb,
            color: Colors.green,
            text:  '1. Connect device via USB cable\n'
                   '2. Enable USB Debugging (Developer Options)\n'
                   '3. Press button above — IP detected automatically!',
          ),
          20.height,
          // فاصل
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR enter manually',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
              ),
              Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey.shade300)),
            ],
          ),
          16.height,
          Text('Device IP Address', style: boldTextStyle(size: 13)),
          8.height,
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _styledTextField(
                  controller: _ipCtrl,
                  hint: '192.168.1.100',
                  icon: Icons.smartphone,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                ),
              ),
              12.width,
              Expanded(
                flex: 1,
                child: _styledTextField(
                  controller: _portCtrl,
                  hint: '5555',
                  icon: Icons.outlet,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          16.height,
          _InfoCard(
            isDark: isDark,
            icon:  Icons.terminal,
            color: Colors.green,
            text:  'Or enable via USB first:\nadb tcpip 5555\nadb connect <device-ip>:5555',
            isCode: true,
          ),
        ],
      ),
    );
  }

  // Step 1: Devices List
  Widget _buildDevicesStep(bool isDark) {
    return Padding(
      key: const ValueKey('devices'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Connected Devices', style: boldTextStyle(size: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: _isLoading ? null : _fetchDevices,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          8.height,
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_devices.isEmpty)
            _EmptyDevices(isDark: isDark, onAddManually: () => setState(() => _step = _stepConnect))
          else
            ..._devices.map((d) => _DeviceTile(
                  device:    d,
                  isSelected: _selectedDevice?.id == d.id,
                  isDark:    isDark,
                  onTap:     () => setState(() => _selectedDevice = d),
                )),
          12.height,
          // Quick-connect بعد رؤية الأجهزة
          OutlinedButton.icon(
            onPressed: () => setState(() => _step = _stepConnect),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Connect new device via IP'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: btnBackgroundColor),
              foregroundColor: btnBackgroundColor,
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Running
  Widget _buildRunningStep(bool isDark) {
    return Padding(
      key: const ValueKey('running'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        children: [
          if (_isLoading)
            Lottie.asset('images/loader.json', width: 80, height: 80)
          else if (_isRunning)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      12.width,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('App is running!', style: boldTextStyle(color: Colors.green, size: 14)),
                            Text(_selectedDevice?.name ?? '',
                                 style: secondaryTextStyle(size: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                16.height,
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _hotReload,
                        icon: const Icon(Icons.bolt, size: 18),
                        label: const Text('Hot Reload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    12.width,
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _stopProject,
                        icon: const Icon(Icons.stop, size: 18),
                        label: const Text('Stop'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side:            const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Status Bar ──────────────────────────────────────────────

  Widget _buildStatusBar(bool isDark) {
    final isError   = _statusText.contains('❌');
    final isSuccess = _statusText.contains('✅');
    final color     = isError ? Colors.red : isSuccess ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : isSuccess ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 16,
          ),
          8.width,
          Expanded(
            child: Text(_statusText,
                style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ─── Actions Bar ─────────────────────────────────────────────

  Widget _buildActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => finish(context),
            child: Text('Close',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
          ),
          12.width,
          if (_step == _stepConnect)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _connectByIp,
              icon: const Icon(Icons.wifi_find, size: 18),
              label: const Text('Connect'),
              style: _primaryStyle(),
            )
          else if (_step == _stepDevices && _selectedDevice != null)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runProject,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Run on Device'),
              style: _primaryStyle(),
            ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────

  ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
        backgroundColor: btnBackgroundColor,
        foregroundColor: Colors.white,
        padding:    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape:      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation:  4,
        shadowColor: btnBackgroundColor.withOpacity(0.4),
      );

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType?              keyboardType,
    List<TextInputFormatter>?   inputFormatters,
  }) {
    return TextField(
      controller:         controller,
      keyboardType:       keyboardType,
      inputFormatters:    inputFormatters,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
        prefixIcon: Icon(icon, size: 18, color: btnBackgroundColor),
        filled:      true,
        fillColor:   isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border:         OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: btnBackgroundColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final int    index;
  final String label;
  final bool   active;
  final bool   done;
  final bool   isDark;

  const _StepDot({
    required this.index, required this.label,
    required this.active, required this.done, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = active || done ? btnBackgroundColor : (isDark ? Colors.white24 : Colors.grey.shade300);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width:  28, height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text('$index', style: TextStyle(
                    color:      active ? Colors.white : (isDark ? Colors.white54 : Colors.grey),
                    fontSize:   12,
                    fontWeight: FontWeight.bold,
                  )),
          ),
        ),
        4.height,
        Text(label, style: TextStyle(
          fontSize:   10,
          color:      active ? btnBackgroundColor : (isDark ? Colors.white38 : Colors.grey),
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        )),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final WiFiDevice device;
  final bool       isSelected;
  final bool       isDark;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device, required this.isSelected,
    required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:  const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        isSelected
              ? btnBackgroundColor.withOpacity(0.1)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(
            color: isSelected ? btnBackgroundColor : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        (isSelected ? btnBackgroundColor : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                device.isEmulator ? Icons.computer : Icons.phone_android,
                color: isSelected ? btnBackgroundColor : Colors.grey,
                size:  20,
              ),
            ),
            12.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: boldTextStyle(size: 13)),
                  4.height,
                  Row(
                    children: [
                      Icon(Icons.wifi, size: 12,
                          color: device.isWifi ? Colors.green : Colors.orange),
                      4.width,
                      Text(device.id,
                          style: secondaryTextStyle(size: 11),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: btnBackgroundColor, size: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        (device.isReady ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                device.status,
                style: TextStyle(
                  color:    device.isReady ? Colors.green : Colors.orange,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool   isDark;
  final IconData icon;
  final Color  color;
  final String text;
  final bool   isCode;

  const _InfoCard({
    required this.isDark, required this.icon,
    required this.color,  required this.text,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        color.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          10.width,
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize:   12,
                color:      isDark ? Colors.white70 : Colors.black87,
                fontFamily: isCode ? 'monospace' : null,
                height:     1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAddManually;

  const _EmptyDevices({required this.isDark, required this.onAddManually});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.devices_other,
            size: 48,
            color: isDark ? Colors.white24 : Colors.grey.shade300),
        12.height,
        Text('No devices found',
            style: boldTextStyle(size: 14,
                color: isDark ? Colors.white54 : Colors.grey)),
        8.height,
        Text('Make sure Wi-Fi Debugging is enabled\nand device is on the same network',
            textAlign: TextAlign.center,
            style: secondaryTextStyle(size: 12)),
        16.height,
        ElevatedButton.icon(
          onPressed: onAddManually,
          icon:  const Icon(Icons.add, size: 16),
          label: const Text('Enter IP manually'),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnBackgroundColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
