import '../ui/assistant_bubble.dart';
import '../ui/app_bottom_nav.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // ============================================================
  // DRIVEALERT COLOUR SCHEME
  // ============================================================

  static const Color primaryBlue = Color(0xFF2161F5);
  static const Color green = Color(0xFF00B956);
  static const Color orange = Color(0xFFFF9F1C);
  static const Color red = Color(0xFFE53935);
  static const Color darkNavy = Color(0xFF0B2545);
  static const Color lightBackground = Color(0xFFF8FAFC);

  // ============================================================
  // SELECTED PERIOD
  // ============================================================

  String selectedPeriod = 'Today';

  // ============================================================
  // LOADING / ERROR
  // ============================================================

  bool isLoading = true;
  String? errorMessage;
  String recommendation = '';
  String? syncWarning;

  // ============================================================
  // ANALYTICS DATA FROM DJANGO
  // ============================================================

  int totalSessions = 0;
  int totalMicrosleeps = 0;
  int totalDrowsinessEvents = 0;
  int totalLongClosures = 0;

  double totalDrivingDurationSeconds = 0;
  double averageMicrosleepsPerSession = 0;

  // ============================================================
  // RECENT EVENTS
  // ============================================================

  List<Map<String, dynamic>> recentEvents = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  // ============================================================
  // LOAD ANALYTICS
  // ============================================================

  Future<void> _loadAnalytics() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      http.Response analyticsResponse = await ApiService.getAnalytics(
        period: selectedPeriod,
      );

      // ----------------------------------------------------------
      // Refresh token if required
      // ----------------------------------------------------------

      if (analyticsResponse.statusCode == 401) {
        final refreshed = await ApiService.refreshAccessToken();

        if (refreshed) {
          analyticsResponse = await ApiService.getAnalytics(
            period: selectedPeriod,
          );
        }
      }

      // ----------------------------------------------------------
      // Check analytics response
      // ----------------------------------------------------------

      if (analyticsResponse.statusCode != 200) {
        throw Exception('Failed to load analytics.');
      }

      final analyticsData = jsonDecode(analyticsResponse.body);

      // ----------------------------------------------------------
      // Load recent events
      // ----------------------------------------------------------

      http.Response eventsResponse = await ApiService.getEvents();

      if (eventsResponse.statusCode == 401) {
        final refreshed = await ApiService.refreshAccessToken();

        if (refreshed) {
          eventsResponse = await ApiService.getEvents();
        }
      }

      List<Map<String, dynamic>> events = [];

      if (eventsResponse.statusCode == 200) {
        final decoded = jsonDecode(eventsResponse.body);

        dynamic eventData;

        if (decoded is List) {
          eventData = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          eventData = decoded['results'];
        }

        if (eventData is List) {
          events = eventData
              .map((event) => Map<String, dynamic>.from(event))
              .toList();

          // ------------------------------------------------------
          // Sort newest first
          // ------------------------------------------------------

          events.sort((a, b) {
            final aTime =
                DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final bTime =
                DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return bTime.compareTo(aTime);
          });
        }
      }

      if (!mounted) return;

      setState(() {
        recommendation = analyticsData['recommendation']?.toString() ?? '';
        syncWarning = analyticsData['sync_error']?.toString();
        totalSessions = (analyticsData['total_sessions'] ?? 0) as int;

        totalMicrosleeps = (analyticsData['total_microsleeps'] ?? 0) as int;

        totalDrowsinessEvents =
            (analyticsData['total_drowsiness_events'] ?? 0) as int;

        totalLongClosures = (analyticsData['total_long_closures'] ?? 0) as int;

        totalDrivingDurationSeconds =
            (analyticsData['total_driving_duration_seconds'] ?? 0).toDouble();

        averageMicrosleepsPerSession =
            (analyticsData['average_microsleeps_per_session'] ?? 0).toDouble();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final since = selectedPeriod == 'Week'
            ? today.subtract(Duration(days: now.weekday - 1))
            : selectedPeriod == 'Month'
            ? DateTime(now.year, now.month)
            : today;
        recentEvents = events
            .where(
              (e) =>
                  !(DateTime.tryParse(
                            e['timestamp']?.toString() ?? '',
                          )?.toLocal() ??
                          DateTime.fromMillisecondsSinceEpoch(0))
                      .isBefore(since),
            )
            .toList();

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load analytics data.';
      });
    }
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String get drivingTime {
    final totalMinutes = (totalDrivingDurationSeconds / 60).round();

    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }

  String get totalAlerts {
    return '${totalMicrosleeps + totalDrowsinessEvents + totalLongClosures} Alerts';
  }

  String get overviewTitle {
    switch (selectedPeriod) {
      case 'Week':
        return 'This Week\'s Overview';

      case 'Month':
        return 'This Month\'s Overview';

      default:
        return "Today's Overview";
    }
  }

  String get chartSubtitle {
    switch (selectedPeriod) {
      case 'Week':
        return 'Recorded alerts';

      case 'Month':
        return 'Recorded alerts';

      default:
        return 'Recorded alerts';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAnalytics,

          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),

            padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ==================================================
                // HEADER
                // ==================================================
                _buildHeader(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/journeys'),
                    icon: const Icon(Icons.route_rounded),
                    label: const Text('Journey reports'),
                  ),
                ),

                const SizedBox(height: 22),

                // ==================================================
                // PERIOD SELECTOR
                // ==================================================
                _buildPeriodSelector(),

                const SizedBox(height: 20),

                // ==================================================
                // CONTENT
                // ==================================================
                if (isLoading)
                  _buildLoadingState()
                else if (errorMessage != null)
                  _buildErrorState()
                else ...[
                  // ==================================================
                  // ALERT ACTIVITY FIRST
                  // ==================================================
                  if (syncWarning != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Some recent warnings are still syncing. Pull down to refresh.',
                      ),
                    ),
                  if (recommendation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(recommendation),
                    ),
                  _buildChartSection(),

                  const SizedBox(height: 24),

                  // ==================================================
                  // OVERVIEW
                  // ==================================================
                  _buildOverview(),

                  const SizedBox(height: 24),

                  // ==================================================
                  // SAFETY SUMMARY
                  // ==================================================
                  _buildSafetyScore(),

                  const SizedBox(height: 24),

                  // ==================================================
                  // RECENT ALERTS
                  // ==================================================
                  _buildRecentAlerts(),
                ],
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: const AssistantBubble(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ============================================================
  // LOADING STATE
  // ============================================================

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),

      child: const Column(
        children: [
          CircularProgressIndicator(color: primaryBlue),

          SizedBox(height: 15),

          Text(
            'Loading analytics...',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: red, size: 35),

          const SizedBox(height: 10),

          const Text(
            'Unable to load analytics',
            style: TextStyle(
              color: darkNavy,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            errorMessage ?? '',
            textAlign: TextAlign.center,

            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
          ),

          const SizedBox(height: 13),

          ElevatedButton(
            onPressed: _loadAnalytics,

            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            child: const Text(
              'Try Again',

              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Analytics',

                style: TextStyle(
                  color: darkNavy,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 4),

              Text(
                'Your driving performance',

                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),

        GestureDetector(
          onTap: _loadAnalytics,

          child: Container(
            width: 43,
            height: 43,

            decoration: BoxDecoration(
              color: const Color(0xFFE1EBFF),

              borderRadius: BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.insights_rounded,
              color: primaryBlue,
              size: 23,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PERIOD SELECTOR
  // ============================================================

  Widget _buildPeriodSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Row(
        children: [
          _buildPeriodButton('Today'),
          _buildPeriodButton('Week'),
          _buildPeriodButton('Month'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String text) {
    final bool selected = selectedPeriod == text;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: () {
          setState(() {
            selectedPeriod = text;
          });
          _loadAnalytics();
        },

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),

          height: double.infinity,

          decoration: BoxDecoration(
            color: selected ? primaryBlue : Colors.transparent,

            borderRadius: BorderRadius.circular(11),
          ),

          alignment: Alignment.center,

          child: Text(
            text,

            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF64748B),

              fontSize: 11,

              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ALERT ACTIVITY
  // ============================================================

  Widget _buildChartSection() {
    final int alertTotal =
        totalMicrosleeps + totalDrowsinessEvents + totalLongClosures;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(21),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Alert Activity',

                      style: TextStyle(
                        color: darkNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      chartSubtitle,

                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),

                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1E1),

                  borderRadius: BorderRadius.circular(10),
                ),

                child: Text(
                  '$alertTotal Alerts',

                  style: const TextStyle(
                    color: red,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          SizedBox(height: 150, child: _buildSimpleChart()),

          const SizedBox(height: 10),

          _buildChartLabels(),
        ],
      ),
    );
  }

  // ============================================================
  // CHART LABELS
  // ============================================================

  Widget _buildChartLabels() {
    const labels = ['Drowsy', 'Microsleep', 'Long Closure'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,

      children: labels
          .map(
            (label) => Text(
              label,

              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSimpleChart() {
    return CustomPaint(
      painter: _AlertChartPainter(
        drowsiness: totalDrowsinessEvents,

        microsleeps: totalMicrosleeps,

        longClosures: totalLongClosures,
      ),

      child: Container(),
    );
  }

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          overviewTitle,

          style: const TextStyle(
            color: darkNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 13),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.access_time_rounded,

                value: drivingTime,

                label: 'Driving Time',

                iconColor: primaryBlue,

                iconBackground: const Color(0xFFDCE9FF),
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _buildStatCard(
                icon: Icons.route_rounded,

                value: '$totalSessions',

                label: 'Sessions',

                iconColor: green,

                iconBackground: const Color(0xFFE8F8EF),
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.visibility_rounded,

                value: '$totalDrowsinessEvents',

                label: 'Drowsy Events',

                iconColor: orange,

                iconBackground: const Color(0xFFFFF6BD),
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _buildStatCard(
                icon: Icons.warning_amber_rounded,

                value: '$totalMicrosleeps',

                label: 'Microsleep',

                iconColor: red,

                iconBackground: const Color(0xFFFFE1E1),
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.remove_red_eye_rounded,

                value: '$totalLongClosures',

                label: 'Long Closures',

                iconColor: orange,

                iconBackground: const Color(0xFFFFF6BD),
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _buildStatCard(
                icon: Icons.analytics_rounded,

                value: averageMicrosleepsPerSession.toStringAsFixed(1),

                label: 'Avg. Microsleep / Session',

                iconColor: primaryBlue,

                iconBackground: const Color(0xFFDCE9FF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      height: 122,
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(17),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 36,
            height: 36,

            decoration: BoxDecoration(
              color: iconBackground,

              borderRadius: BorderRadius.circular(10),
            ),

            child: Icon(icon, color: iconColor, size: 19),
          ),

          const SizedBox(height: 9),

          Text(
            value,

            style: const TextStyle(
              color: darkNavy,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 1),

          Text(
            label,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAFETY SUMMARY
  // ============================================================

  Widget _buildSafetyScore() {
    final int totalAlerts =
        totalMicrosleeps + totalDrowsinessEvents + totalLongClosures;

    String message;

    if (totalSessions == 0) {
      message = 'No driving sessions have been recorded yet.';
    } else if (totalAlerts == 0) {
      message = 'No drowsiness-related events have been recorded.';
    } else {
      message =
          '$totalAlerts drowsiness-related event${totalAlerts == 1 ? '' : 's'} recorded across $totalSessions session${totalSessions == 1 ? '' : 's'}.';
    }

    // ----------------------------------------------------------
    // Simple calculated indicator.
    // This is not an AI-generated score.
    // ----------------------------------------------------------

    double score = 1.0;

    if (totalSessions > 0) {
      final double alertsPerSession = totalAlerts / totalSessions;

      score = (1.0 - (alertsPerSession * 0.1)).clamp(0.0, 1.0);
    }

    final int scoreNumber = (score * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(21),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Row(
        children: [
          SizedBox(
            width: 82,
            height: 82,

            child: Stack(
              alignment: Alignment.center,

              children: [
                SizedBox(
                  width: 78,
                  height: 78,

                  child: CircularProgressIndicator(
                    value: score,

                    strokeWidth: 8,

                    backgroundColor: const Color(0xFFE8F8EF),

                    valueColor: const AlwaysStoppedAnimation<Color>(green),
                  ),
                ),

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Text(
                      '$scoreNumber',

                      style: const TextStyle(
                        color: darkNavy,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Text(
                      '/100',

                      style: TextStyle(color: Color(0xFF64748B), fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 17),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Safety Summary',

                  style: TextStyle(
                    color: darkNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  message,

                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,

                      color: primaryBlue,

                      size: 15,
                    ),

                    const SizedBox(width: 4),

                    Flexible(
                      child: Text(
                        '$totalSessions session${totalSessions == 1 ? '' : 's'} recorded',

                        style: const TextStyle(
                          color: primaryBlue,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECENT ALERTS
  // ============================================================

  Widget _buildRecentAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Recent Alerts',

          style: TextStyle(
            color: darkNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (recentEvents.isEmpty)
          _buildNoAlerts()
        else
          ...recentEvents.take(5).map((event) {
            final eventType = event['event_type']?.toString() ?? '';

            final eventInfo = _getEventInfo(eventType);

            return Padding(
              padding: const EdgeInsets.only(bottom: 9),

              child: _buildAlertItem(
                icon: eventInfo['icon'] as IconData,

                iconColor: eventInfo['color'] as Color,

                iconBackground: eventInfo['background'] as Color,

                title: eventInfo['title'] as String,

                time: _formatEventTime(event['timestamp']?.toString()),

                description: _getEventDescription(event),
              ),
            );
          }),
      ],
    );
  }

  // ============================================================
  // NO ALERTS
  // ============================================================

  Widget _buildNoAlerts() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: const Column(
        children: [
          Icon(Icons.check_circle_rounded, color: green, size: 32),

          SizedBox(height: 8),

          Text(
            'No alerts recorded',

            style: TextStyle(
              color: darkNavy,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 3),

          Text(
            'Your recorded alerts will appear here.',

            textAlign: TextAlign.center,

            style: TextStyle(color: Color(0xFF64748B), fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EVENT INFO
  // ============================================================

  Map<String, dynamic> _getEventInfo(String eventType) {
    switch (eventType) {
      case 'microsleep':
        return {
          'icon': Icons.warning_amber_rounded,

          'color': red,

          'background': const Color(0xFFFFE1E1),

          'title': 'Microsleep detected',
        };

      case 'long_closure':
        return {
          'icon': Icons.visibility_rounded,

          'color': orange,

          'background': const Color(0xFFFFF6BD),

          'title': 'Long eye closure',
        };

      case 'drowsiness':
      default:
        return {
          'icon': Icons.visibility_rounded,

          'color': orange,

          'background': const Color(0xFFFFF6BD),

          'title': 'Drowsiness detected',
        };
    }
  }

  // ============================================================
  // EVENT DESCRIPTION
  // ============================================================

  String _getEventDescription(Map<String, dynamic> event) {
    final eventType = event['event_type']?.toString();

    final duration = event['duration'];

    if (eventType == 'microsleep') {
      if (duration != null) {
        return 'Eyes closed for ${_formatDurationValue(duration)} seconds';
      }

      return 'Microsleep event recorded';
    }

    if (eventType == 'long_closure') {
      if (duration != null) {
        return 'Long eye closure for ${_formatDurationValue(duration)} seconds';
      }

      return 'Long eye closure recorded';
    }

    if (eventType == 'drowsiness') {
      return 'Drowsiness event recorded';
    }

    return 'Drowsiness-related event recorded';
  }

  // ============================================================
  // FORMAT EVENT TIME
  // ============================================================

  String _formatEventTime(String? timestamp) {
    if (timestamp == null) {
      return '--';
    }

    final date = DateTime.tryParse(timestamp);

    if (date == null) {
      return '--';
    }

    final localDate = date.toLocal();

    final hour = localDate.hour;

    final minute = localDate.minute.toString().padLeft(2, '0');

    final suffix = hour >= 12 ? 'PM' : 'AM';

    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:$minute $suffix';
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  String _formatDurationValue(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;

    return number.toStringAsFixed(number == number.roundToDouble() ? 0 : 1);
  }

  // ============================================================
  // FORMAT EAR
  // ============================================================

  // ============================================================
  // ALERT ITEM
  // ============================================================

  Widget _buildAlertItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String time,
    required String description,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: iconBackground,

              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(icon, color: iconColor, size: 21),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          color: darkNavy,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      time,

                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                Text(
                  description,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FLOATING BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return const AppBottomNav(index: 2);
  }

  // ============================================================
  // NAVIGATION ITEM
  // ============================================================
}

// ============================================================
// ALERT CHART PAINTER
// ============================================================

class _AlertChartPainter extends CustomPainter {
  final int drowsiness;
  final int microsleeps;
  final int longClosures;

  _AlertChartPainter({
    required this.drowsiness,
    required this.microsleeps,
    required this.longClosures,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    final Paint barPaint = Paint()
      ..color = const Color(0xFF2161F5)
      ..style = PaintingStyle.fill;

    // ==========================================================
    // GRID
    // ==========================================================

    for (int i = 0; i < 4; i++) {
      final double y = size.height * i / 3;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ==========================================================
    // REAL DATA
    // ==========================================================

    final values = [drowsiness, microsleeps, longClosures];

    final int maxValue = values.fold(
      0,
      (max, value) => value > max ? value : max,
    );

    // ==========================================================
    // NO DATA
    // ==========================================================

    if (maxValue == 0) {
      final Paint emptyPaint = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..strokeWidth = 2;

      canvas.drawLine(
        Offset(0, size.height / 2),

        Offset(size.width, size.height / 2),

        emptyPaint,
      );

      return;
    }

    // ==========================================================
    // BARS
    // ==========================================================

    final double sectionWidth = size.width / 3;

    for (int i = 0; i < values.length; i++) {
      final double barWidth = sectionWidth * 0.35;

      final double barHeight = (values[i] / maxValue) * (size.height - 10);

      final double x = sectionWidth * i + (sectionWidth - barWidth) / 2;

      final double y = size.height - barHeight;

      final Rect rect = Rect.fromLTWH(x, y, barWidth, barHeight);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),

        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AlertChartPainter oldDelegate) {
    return oldDelegate.drowsiness != drowsiness ||
        oldDelegate.microsleeps != microsleeps ||
        oldDelegate.longClosures != longClosures;
  }
}
