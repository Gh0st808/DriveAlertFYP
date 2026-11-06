import '../ui/app_bottom_nav.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/phone_alarm_service.dart';
import '../services/user_message.dart';
import 'package:flutter/services.dart';

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen>
    with WidgetsBindingObserver {
  bool _foreground = true;
  // ============================================================
  // DRIVEALERT DEVICE SERVER
  // ============================================================

  bool _controlBusy = false;
  int _controlEpoch = 0;
  bool _statusBusy = false;
  bool _frameBusy = false;

  Timer? _statusTimer;
  Timer? _frameTimer;

  // ============================================================
  // DEVICE STATUS
  // ============================================================

  String? _deviceMessage;
  bool _deviceConnected = false;
  bool _monitoring = false;
  bool _driverDetected = false;
  bool _eyeClosed = false;
  bool _drowsy = false;
  bool _calibrating = false;
  bool _visibilityWarning = false;
  DateTime? _faceMissingSince;
  DateTime? _lastFrameAt;

  // ============================================================
  // DETECTION DATA
  // ============================================================

  int _blinkCount = 0;
  int _drowsyEvents = 0;
  int _microsleepEvents = 0;
  int _elapsedSeconds = 0;

  Uint8List? _cameraFrame;

  // ============================================================
  // DJANGO DRIVING SESSION
  // ============================================================

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _checkDevice();

    // Check device status every second.
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkDevice();
    });

    // Keep preview traffic bounded; only one frame request can run at a time.
    _frameTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_monitoring || _calibrating) {
        _loadCameraFrame();
      }
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _foreground = false;
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _frameTimer?.cancel();
    _clearFrame();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _controlEpoch++;
      _clearFrame();
    }
    if (_foreground) unawaited(_checkDevice());
  }

  // ============================================================
  // CHECK DEVICE STATUS
  // ============================================================

  Future<void> _checkDevice() async {
    if (!_foreground || _statusBusy || _controlBusy) return;
    _statusBusy = true;
    final epoch = _controlEpoch;
    try {
      final response = await ApiService.monitorStatus();
      if (!mounted || !_foreground || _controlBusy || epoch != _controlEpoch) {
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          _deviceConnected = true;
          _deviceMessage = data['sync_error'] != null || data['error'] != null
              ? 'Recent records are still syncing. Keep your device connected.'
              : null;

          _monitoring = data['monitoring'] == true;
          if (!_monitoring) {
            _clearFrame();
          }

          _driverDetected = data['driver_detected'] == true;
          if (_monitoring && !_driverDetected) {
            _faceMissingSince ??= DateTime.now();
          } else {
            _faceMissingSince = null;
          }
          _visibilityWarning = _monitoring &&
              (data['visibility_warning'] == true ||
                  (_faceMissingSince != null &&
                      DateTime.now().difference(_faceMissingSince!).inSeconds >= 3));
          if (_lastFrameAt != null &&
              DateTime.now().difference(_lastFrameAt!).inSeconds >= 3) {
            _clearFrame();
          }

          _eyeClosed = data['eye_closed'] == true;

          _drowsy = data['drowsy'] == true;

          _calibrating = data['calibrating'] == true;

          _blinkCount = _toInt(data['blink_count']);

          _drowsyEvents = _toInt(data['drowsy_events']);

          _microsleepEvents = _toInt(data['microsleep_count']);

          _elapsedSeconds = _toInt(data['elapsed_seconds']);
        });
        data['visibility_warning'] = _visibilityWarning;
        try {
          await PhoneAlarmService.watch(Map<String, dynamic>.from(data));
          if (mounted && !PhoneAlarmService.supported && _monitoring) {
            setState(
              () => _deviceMessage = 'Phone alarms require the Android app.',
            );
          }
        } catch (error) {
          if (mounted) {
            setState(
              () => _deviceMessage =
                  'Phone alarm unavailable: ${_alarmError(error)}',
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _deviceMessage = ApiService.errorText(response);
          });
        }
        _setOffline();
      }
    } catch (e) {
      if (epoch == _controlEpoch && !_controlBusy) {
        _deviceMessage = null;
        _setOffline();
      }
    } finally {
      _statusBusy = false;
    }
  }

  // ============================================================
  // SET OFFLINE
  // ============================================================

  void _setOffline() {
    if (!mounted) return;

    setState(() {
      _deviceConnected = false;
      // Losing a connection does not prove that the Pi stopped monitoring.
      _driverDetected = false;
      _eyeClosed = false;
      _drowsy = false;
      _calibrating = false;
      _visibilityWarning = false;
      _faceMissingSince = null;
      _clearFrame();
    });
  }

  // ============================================================
  // START MONITORING
  // ============================================================

  Future<void> _startMonitoring() async => _controlMonitoring(true);
  Future<void> _stopMonitoring() async => _controlMonitoring(false);

  Future<void> _controlMonitoring(bool start) async {
    if (_controlBusy) return;
    _controlEpoch++;
    setState(() {
      _controlBusy = true;
    });
    try {
      if (start) await PhoneAlarmService.prepare();
      final response = await (start
          ? ApiService.startMonitoring()
          : ApiService.stopMonitoring());
      if (response.statusCode != 200) {
        _showMessage(ApiService.errorText(response));
      } else if (start) {
        try {
          if (!_foreground) {
            throw StateError('Keep DriveAlert open while starting monitoring.');
          }
          await PhoneAlarmService.watch(
            Map<String, dynamic>.from(jsonDecode(response.body)),
          );
          _showMessage(
            'Monitoring started. Phone alarms continue in the background and when locked.',
          );
        } catch (error) {
          await ApiService.stopMonitoring();
          await PhoneAlarmService.stop();
          _showMessage('Could not arm the phone alarm: ${_alarmError(error)}');
        }
      } else if (!start) {
        await PhoneAlarmService.stop();
        if (mounted) {
          setState(() {
            _monitoring = false;
            _calibrating = false;
            _clearFrame();
          });
        }
        _showMessage(
          'Monitoring stopped. Session and detection records saved.',
        );
      }
    } catch (error) {
      _showMessage(_alarmError(error));
    } finally {
      if (mounted) {
        setState(() {
          _controlBusy = false;
        });
      }
      await _checkDevice();
    }
  }

  // ============================================================
  // LOAD CAMERA FRAME
  // ============================================================

  Future<void> _loadCameraFrame() async {
    if (!_foreground || _frameBusy || _controlBusy || !_monitoring || !_deviceConnected) return;
    _frameBusy = true;
    final epoch = _controlEpoch;
    try {
      final response = await ApiService.monitorFrame();

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted ||
            !_foreground ||
            !_monitoring ||
            _controlBusy ||
            epoch != _controlEpoch) {
          return;
        }

        setState(() {
          _clearFrame();
          _cameraFrame = response.bodyBytes;
          _lastFrameAt = DateTime.now();
        });
      } else if (mounted && epoch == _controlEpoch) {
        setState(_clearFrame);
      }
    } catch (e) {
      if (mounted && epoch == _controlEpoch) setState(_clearFrame);
    } finally {
      _frameBusy = false;
    }
  }

  void _clearFrame() {
    final old = _cameraFrame;
    _cameraFrame = null;
    _lastFrameAt = null;
    if (old != null) unawaited(MemoryImage(old).evict());
  }

  // ============================================================
  // HELPER CONVERSION
  // ============================================================

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;

    final minutes = (seconds % 3600) ~/ 60;

    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // DISPLAY STATUS
  // ============================================================

  String _getDisplayStatus() {
    if (!_deviceConnected) {
      return 'Device Offline';
    }

    if (!_monitoring) {
      return 'Monitoring Stopped';
    }

    if (_visibilityWarning) return 'Face not clearly visible';

    if (_calibrating) {
      return 'Calibrating...';
    }

    if (!_driverDetected) {
      return 'Driver Not Detected';
    }

    if (_drowsy) {
      return 'DROWSINESS DETECTED';
    }

    if (_eyeClosed) {
      return 'Eyes Closed';
    }

    return 'Awake';
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _getStatusIcon() {
    if (!_deviceConnected) {
      return Icons.cloud_off_rounded;
    }

    if (!_monitoring) {
      return Icons.pause_circle_rounded;
    }

    if (_visibilityWarning) return Icons.visibility_off_rounded;

    if (_calibrating) {
      return Icons.tune_rounded;
    }

    if (!_driverDetected) {
      return Icons.person_off_rounded;
    }

    if (_drowsy) {
      return Icons.warning_amber_rounded;
    }

    if (_eyeClosed) {
      return Icons.visibility_off_rounded;
    }

    return Icons.check_circle_rounded;
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return const AppBottomNav(index: 1);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: _buildBottomNavigation(),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      children: [
                        _buildConnectionCard(),
                        const SizedBox(height: 16),
                        if (_visibilityWarning) ...[
                          Semantics(
                            liveRegion: true,
                            child: Card(
                              color: Color(0xFFFFF4DB),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Face not clearly visible. Check lighting and camera position.',
                                  style: TextStyle(color: Color(0xFF765000), fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildCameraCard(),
                        const SizedBox(height: 16),
                        _buildStatusCard(),
                        const SizedBox(height: 16),
                        _buildDetectionStats(),
                        const SizedBox(height: 16),
                        _buildSessionCard(),
                        const SizedBox(height: 20),
                        _buildMonitoringButton(),
                        if (_monitoring)
                          TextButton.icon(
                            onPressed: _controlBusy
                                ? null
                                : () async {
                                    try {
                                      await PhoneAlarmService.prepare();
                                      await _checkDevice();
                                    } catch (error) {
                                      _showMessage(_alarmError(error));
                                    }
                                  },
                            icon: const Icon(
                              Icons.notifications_active_rounded,
                            ),
                            label: const Text('Enable phone alarms'),
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            try {
                              await PhoneAlarmService.batterySettings();
                            } catch (error) {
                              _showMessage(_alarmError(error));
                            }
                          },
                          child: const Text('Background alarm settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _controlBusy || _monitoring
                              ? null
                              : () async {
                                  try {
                                    await PhoneAlarmService.test();
                                    _showMessage(
                                      'Playing the phone alarm for up to five seconds.',
                                    );
                                  } catch (error) {
                                    _showMessage(_alarmError(error));
                                  }
                                },
                          icon: const Icon(Icons.volume_up_rounded),
                          label: const Text('Test phone alarm'),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Phone alarms continue while locked. Keep the monitoring connection available and alarm volume audible.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFF2161F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.remove_red_eye_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Monitor',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Real-time driver monitoring',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _checkDevice,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2161F5)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONNECTION CARD
  // ============================================================

  Widget _buildConnectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _deviceConnected
                  ? const Color(0xFFE8F8EF)
                  : const Color(0xFFFFEEEE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _deviceConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: _deviceConnected
                  ? const Color(0xFF00B956)
                  : const Color(0xFFE53935),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deviceConnected
                      ? 'DriveAlert Device Connected'
                      : 'Device Offline',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0B2545),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _deviceMessage ??
                      (_deviceConnected
                          ? 'Ready for your journey'
                          : 'Power on your device and check the connection.'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _deviceConnected
                  ? const Color(0xFFE8F8EF)
                  : const Color(0xFFFFEEEE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _deviceConnected ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _deviceConnected
                    ? const Color(0xFF00B956)
                    : const Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CAMERA CARD
  // ============================================================

  Widget _buildCameraCard() {
    return Container(
      width: double.infinity,
      height: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF0B2545),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: _cameraFrame != null
                ? Image.memory(
                    _cameraFrame!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const Center(child: Text(
                      'Camera preview reconnecting...', style: TextStyle(color: Colors.white70))),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _monitoring
                              ? Icons.camera_alt_rounded
                              : Icons.videocam_off_rounded,
                          size: 55,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _monitoring
                              ? 'Camera preview reconnecting...'
                              : 'Camera Preview',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // LIVE LABEL
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _cameraFrame != null ? Colors.red : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _cameraFrame != null ? 'LIVE' : (_monitoring ? 'CONNECTING' : 'OFF'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CALIBRATION INFORMATION
          if (_calibrating)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2161F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calibrating Camera',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Look directly at the camera',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2161F5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // DRIVER POSITION GUIDE
          if (_calibrating && _cameraFrame != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 150,
                    height: 190,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.65),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(75),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget _buildStatusCard() {
    Color statusColor;

    if (!_deviceConnected) {
      statusColor = const Color(0xFFE53935);
    } else if (_visibilityWarning || _calibrating) {
      statusColor = const Color(0xFFFF9F1C);
    } else if (_drowsy) {
      statusColor = const Color(0xFFE53935);
    } else if (_eyeClosed) {
      statusColor = const Color(0xFFFF9F1C);
    } else if (_driverDetected) {
      statusColor = const Color(0xFF00B956);
    } else {
      statusColor = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_getStatusIcon(), color: statusColor, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Status',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDisplayStatus(),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (_drowsy)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ALERT',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // DETECTION STATS
  // ============================================================

  Widget _buildDetectionStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Detection Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B2545),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildStatistic(
                icon: Icons.remove_red_eye_rounded,
                title: 'Eyes',
                value: !_monitoring || !_driverDetected
                    ? '—'
                    : _eyeClosed
                    ? 'Closed'
                    : 'Open',
                subtitle: 'Current eye state',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatistic(
                icon: Icons.visibility_off_rounded,
                title: 'Blink Count',
                value: '$_blinkCount',
                subtitle: 'Detected blinks',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatistic(
                icon: Icons.warning_amber_rounded,
                title: 'Drowsiness',
                value: '$_drowsyEvents',
                subtitle: 'Drowsy events',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatistic(
                icon: Icons.bedtime_rounded,
                title: 'Microsleep',
                value: '$_microsleepEvents',
                subtitle: 'Microsleep events',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatistic(
                icon: Icons.speed_rounded,
                title: 'Camera',
                value: _monitoring && _deviceConnected ? 'Active' : 'Off',
                subtitle: 'Monitoring camera',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatistic(
                icon: Icons.visibility_rounded,
                title: 'Driver',
                value: _monitoring && _driverDetected ? 'Detected' : '—',
                subtitle: 'In camera view',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STATISTIC WIDGET
  // ============================================================

  Widget _buildStatistic({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF2161F5)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B2545),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SESSION CARD
  // ============================================================

  Widget _buildSessionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.timer_rounded, color: Color(0xFF2161F5)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoring Duration',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  'Current Session',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0B2545),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(_elapsedSeconds),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2161F5),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // START / STOP BUTTON
  // ============================================================

  Widget _buildMonitoringButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _controlBusy || (!_deviceConnected && !_monitoring)
            ? null
            : (_monitoring ? _stopMonitoring : _startMonitoring),
        style: ElevatedButton.styleFrom(
          backgroundColor: _monitoring
              ? const Color(0xFFE53935)
              : const Color(0xFF2161F5),
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _monitoring
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_rounded,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _monitoring ? 'Stop Monitoring' : 'Start Monitoring',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _alarmError(Object error) => UserMessage.from(
  error is PlatformException
      ? error.message
      : error is StateError
      ? error.message
      : error,
  fallback: 'Connection lost. Check monitoring status before retrying.',
);
