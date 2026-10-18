import 'dart:convert';
import '../services/api_service.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // ============================================================
  // DRIVEALERT COLOUR SCHEME
  // ============================================================

  static const Color primaryBlue = Color(0xFF2161F5);
  static const Color orange = Color(0xFFFF9F1C);
  static const Color red = Color(0xFFE53935);
  static const Color green = Color(0xFF00B956);
  static const Color darkNavy = Color(0xFF0B2545);
  static const Color lightBackground = Color(0xFFF8FAFC);

  // ============================================================
  // FILTER
  // ============================================================

  String selectedFilter = 'All';

  // ============================================================
  // RECORDED HISTORY DATA
  //
  // Records are loaded from the authenticated backend.
  // ============================================================

  List<Map<String, dynamic>> historyData = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await ApiService.getEvents();
      if (response.statusCode != 200) {
        throw Exception(ApiService.errorText(response));
      }
      final List<dynamic> events = jsonDecode(response.body);
      final data = events.map((event) {
        final time = DateTime.parse(event['timestamp']).toLocal();
        final type = event['event_type'] == 'microsleep'
            ? 'Microsleep'
            : event['event_type'] == 'long_closure'
            ? 'Long Eye Closure'
            : 'Drowsiness';
        return <String, dynamic>{
          'type': type,
          'date': time.toString().substring(0, 10),
          'time': time.toString().substring(11, 19),
          'duration': event['duration'] == null
              ? 'Not recorded'
              : '${(event['duration'] as num).toStringAsFixed(2)} seconds',
          'description': 'Recorded during journey ${event['session']}',
          'severity': type == 'Drowsiness' ? 'Medium' : 'High',
        };
      }).toList();
      if (mounted) {
        setState(() {
          historyData = data;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load history. Tap refresh to retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // FILTERED DATA
  // ============================================================

  List<Map<String, dynamic>> get filteredHistory {
    if (selectedFilter == 'All') {
      return historyData;
    }

    return historyData.where((item) => item['type'] == selectedFilter).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 22),

              _buildSummary(),

              const SizedBox(height: 22),

              _buildFilter(),

              const SizedBox(height: 20),

              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(_error!)
              else
                _buildHistoryList(),
              TextButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh history'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: darkNavy,
              size: 18,
            ),
          ),
        ),

        const SizedBox(width: 13),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'History',
                style: TextStyle(
                  color: darkNavy,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 4),

              Text(
                'Your previous driving events',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),

        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFFE1EBFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.history_rounded,
            color: primaryBlue,
            size: 23,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    final int microsleepCount = historyData
        .where((item) => item['type'] == 'Microsleep')
        .length;

    final int drowsinessCount = historyData
        .where((item) => item['type'] == 'Drowsiness')
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.warning_amber_rounded,
            value: '$microsleepCount',
            label: 'Microsleep',
            color: red,
            background: const Color(0xFFFFE1E1),
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: _buildSummaryCard(
            icon: Icons.visibility_rounded,
            value: '$drowsinessCount',
            label: 'Drowsiness',
            color: orange,
            background: const Color(0xFFFFF6BD),
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: _buildSummaryCard(
            icon: Icons.event_available_rounded,
            value: '${historyData.length}',
            label: 'Total Events',
            color: primaryBlue,
            background: const Color(0xFFDCE9FF),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(
              color: darkNavy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 1),

          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER
  // ============================================================

  Widget _buildFilter() {
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
          _buildFilterButton('All'),
          _buildFilterButton('Microsleep'),
          _buildFilterButton('Drowsiness'),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String text) {
    final bool selected = selectedFilter == text;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: () {
          setState(() {
            selectedFilter = text;
          });
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
              fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HISTORY LIST
  // ============================================================

  Widget _buildHistoryList() {
    if (filteredHistory.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedFilter == 'All' ? 'All Events' : '$selectedFilter Events',
          style: const TextStyle(
            color: darkNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        ...filteredHistory.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildHistoryCard(item),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HISTORY CARD
  // ============================================================

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final bool isMicrosleep = item['type'] == 'Microsleep';

    final Color eventColor = isMicrosleep ? red : orange;

    final Color eventBackground = isMicrosleep
        ? const Color(0xFFFFE1E1)
        : const Color(0xFFFFF6BD);

    final IconData eventIcon = isMicrosleep
        ? Icons.warning_amber_rounded
        : Icons.visibility_rounded;

    Color severityColor;

    switch (item['severity']) {
      case 'High':
        severityColor = red;
        break;

      case 'Medium':
        severityColor = orange;
        break;

      default:
        severityColor = green;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: eventBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(eventIcon, color: eventColor, size: 22),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item['type']} Detected',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: darkNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(width: 5),

                        Text(
                          item['time'],
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    Text(
                      item['date'],
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 9,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      item['description'],
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(height: 1, color: const Color(0xFFF1F5F9)),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(
                Icons.timer_rounded,
                color: Color(0xFF64748B),
                size: 15,
              ),

              const SizedBox(width: 5),

              const Text(
                'Duration',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 9),
              ),

              const SizedBox(width: 5),

              Text(
                item['duration'],
                style: const TextStyle(
                  color: darkNavy,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item['severity']} Severity',
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: green,
              size: 32,
            ),
          ),

          const SizedBox(height: 15),

          const Text(
            'No Events Found',
            style: TextStyle(
              color: darkNavy,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'There are no events in this category.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
