import '../ui/app_theme.dart';
import '../ui/assistant_bubble.dart';
import '../ui/app_bottom_nav.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/phone_alarm_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ============================================================
  // DRIVEALERT COLOUR SCHEME
  // ============================================================

  // ============================================================
  // DASHBOARD DATA
  // ============================================================

  bool isLoading = true;
  String? errorMessage;

  String username = 'Driver';
  bool _deviceOnline = false;
  bool _cameraActive = false;
  String _driverStatus = 'Checking device';

  int totalSessions = 0;
  double totalDrivingDurationSeconds = 0;
  int totalMicrosleeps = 0;
  int totalDrowsinessEvents = 0;
  int totalLongClosures = 0;

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ============================================================
  // LOAD DASHBOARD DATA
  // ============================================================

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAnalytics(),
        ApiService.getCurrentUser(),
        ApiService.monitorStatus(),
      ]);
      if (mounted && results[2].statusCode == 200) {
        try {
          await PhoneAlarmService.watch(
            Map<String, dynamic>.from(jsonDecode(results[2].body)),
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Open Monitor to enable phone alarms for the active journey.',
                ),
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _deviceOnline = results[2].statusCode == 200;
          final state = _deviceOnline
              ? jsonDecode(results[2].body)
              : <String, dynamic>{};
          _cameraActive = state['camera'] == true;
          _driverStatus = !_deviceOnline
              ? 'Device unavailable'
              : state['status']?.toString() ?? 'Stopped';
        });
      }
      final analyticsResponse = results[0];
      final userResponse = results[1];

      if (analyticsResponse.statusCode == 401 ||
          userResponse.statusCode == 401) {
        final refreshed = await ApiService.refreshAccessToken();

        if (!refreshed) {
          throw Exception('Your session has expired. Please log in again.');
        }

        final refreshedResults = await Future.wait([
          ApiService.getAnalytics(),
          ApiService.getCurrentUser(),
        ]);

        _processResponses(refreshedResults[0], refreshedResults[1]);
        return;
      }

      _processResponses(analyticsResponse, userResponse);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load dashboard data.';
      });
    }
  }

  // ============================================================
  // PROCESS API RESPONSES
  // ============================================================

  void _processResponses(dynamic analyticsResponse, dynamic userResponse) {
    if (!mounted) return;

    if (analyticsResponse.statusCode != 200) {
      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load dashboard data.';
      });
      return;
    }

    final analyticsData = jsonDecode(analyticsResponse.body);

    setState(() {
      totalSessions = analyticsData['total_sessions'] ?? 0;

      totalDrivingDurationSeconds =
          (analyticsData['total_driving_duration_seconds'] ?? 0).toDouble();

      totalMicrosleeps = analyticsData['total_microsleeps'] ?? 0;

      totalDrowsinessEvents = analyticsData['total_drowsiness_events'] ?? 0;

      totalLongClosures = analyticsData['total_long_closures'] ?? 0;

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);

        username = userData['username'] ?? 'Driver';
      }

      isLoading = false;
      errorMessage = null;
    });
  }

  // ============================================================
  // FORMAT DRIVING TIME
  // ============================================================

  String _formatDrivingTime() {
    final totalMinutes = (totalDrivingDurationSeconds / 60).round();

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '${minutes}m';
    }

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final ready = _deviceOnline && !isLoading;
    final statusColor = !ready
        ? AppTheme.muted
        : _driverStatus.toLowerCase().contains('drows') ||
              _driverStatus.toLowerCase().contains('microsleep')
        ? const Color(0xFFE53935)
        : AppTheme.blue;
    return Scaffold(
      floatingActionButton: const AssistantBubble(),
      bottomNavigationBar: const AppBottomNav(index: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 90),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DRIVEALERT',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2.4,
                            color: AppTheme.blue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Hello, $username',
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'A clearer view of every journey.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Your profile',
                    onPressed: () => Navigator.pushNamed(context, '/profile'),
                    icon: const Icon(Icons.person_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF123EAB), AppTheme.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'YOUR DRIVING COMPANION',
                            maxLines: 2,
                            style: TextStyle(
                              color: Colors.white70,
                              letterSpacing: 1,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Stay aware.\nArrive safely.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Check your camera and phone alarm before you begin.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.blue,
                      ),
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/monitor'),
                      icon: const Icon(Icons.visibility_rounded, size: 20),
                      label: const Text('Open monitor'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              ready
                                  ? Icons.wifi_rounded
                                  : Icons.wifi_off_rounded,
                              color: statusColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isLoading
                                      ? 'Checking your device'
                                      : ready
                                      ? 'Device connected'
                                      : 'Device not connected',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isLoading
                                      ? 'Just a moment…'
                                      : ready
                                      ? 'Open Monitor for live status'
                                      : 'Power on your device and check the connection.',
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.videocam_rounded,
                            size: 18,
                            color: AppTheme.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isLoading
                                  ? 'Camera · Checking'
                                  : _cameraActive && ready
                                  ? 'Camera · Active'
                                  : 'Camera · Off',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your driving overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/analytics'),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (errorMessage != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(height: 10),
                        Text(errorMessage!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _loadDashboardData,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _metric(
                        Icons.route_rounded,
                        'Journeys',
                        '$totalSessions',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metric(
                        Icons.schedule_rounded,
                        'Driving time',
                        _formatDrivingTime(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _metric(
                        Icons.bedtime_rounded,
                        'Microsleeps',
                        '$totalMicrosleeps',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metric(
                        Icons.warning_rounded,
                        'Fatigue warnings',
                        '${totalDrowsinessEvents + totalLongClosures}',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 26),
              const Text(
                'Explore',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _action(
                      Icons.route_rounded,
                      'Journey reports',
                      'Review your time on the road',
                      '/journeys',
                    ),
                    const Divider(indent: 58),
                    _action(
                      Icons.history_rounded,
                      'Alert history',
                      'Understand recorded warnings',
                      '/history',
                    ),
                    const Divider(indent: 58),
                    _action(
                      Icons.local_cafe_rounded,
                      'Find a rest stop',
                      'Plan a safe place to pause',
                      '/rest-stop',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.blue, size: 22),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    ),
  );

  Widget _action(IconData icon, String title, String subtitle, String route) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        leading: Icon(icon, color: AppTheme.blue),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () => Navigator.pushNamed(context, route),
      );
}
