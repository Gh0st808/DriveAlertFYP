import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class JourneysScreen extends StatefulWidget {
  const JourneysScreen({super.key});
  @override
  State<JourneysScreen> createState() => _JourneysScreenState();
}

class _JourneysScreenState extends State<JourneysScreen> {
  List<dynamic> sessions = [];
  List<dynamic> events = [];
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await Future.wait([
        ApiService.getSessions(),
        ApiService.getEvents(),
      ]);
      if (result.any((r) => r.statusCode != 200)) {
        throw Exception('Unable to load journeys');
      }
      if (mounted) {
        setState(() {
          sessions = jsonDecode(result[0].body);
          events = jsonDecode(result[1].body);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to load journeys. Retry when connected.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String report(dynamic session) {
    final start = DateTime.parse(session['start_time']).toLocal();
    final end = DateTime.tryParse(
      session['end_time']?.toString() ?? '',
    )?.toLocal();
    final minutes =
        ((end ?? DateTime.now())
                    .difference(start)
                    .inSeconds
                    .clamp(0, 99999999) /
                60)
            .toStringAsFixed(1);
    final records = events.where((e) => e['session'] == session['id']).toList();
    final microsleeps = records
        .where((e) => e['event_type'] == 'microsleep')
        .length;
    final drowsiness = records
        .where((e) => e['event_type'] == 'drowsiness')
        .length;
    final longClosures = records
        .where((e) => e['event_type'] == 'long_closure')
        .length;
    return 'Journey ${session['id']}\nStarted: $start\nEnded: ${end ?? 'Monitoring active'}\n'
        'Driving duration: $minutes minutes\nMicrosleeps: $microsleeps\nDrowsiness warnings: $drowsiness\n'
        'Long closures: $longClosures\nMicrosleeps per hour: ${double.parse(minutes) > 0 ? (microsleeps * 60 / double.parse(minutes)).toStringAsFixed(1) : '0'}\n\n'
        '${microsleeps > 0 || drowsiness > 0 ? 'Fatigue warnings were recorded. Stop at a safe place and rest before continuing.' : 'No fatigue warnings were recorded. Continue planning regular rest breaks.'}\n'
        'Event durations represent elapsed closure time when each threshold was crossed. A sustained closure may produce multiple warning types.';
  }

  void open(dynamic session) {
    final text = report(session);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(text),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!sheetContext.mounted) return;
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('Journey report copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Journey reports'),
      actions: [
        IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: load, child: const Text('Retry')),
              ],
            ),
          )
        : sessions.isEmpty
        ? const Center(
            child: Text('No journeys recorded yet. Start monitoring to begin.'),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, i) {
                final session = sessions[i];
                final start = DateTime.parse(session['start_time']).toLocal();
                return ListTile(
                  leading: const Icon(
                    Icons.route_rounded,
                    color: Color(0xFF2161F5),
                  ),
                  title: Text('Journey ${session['id']}'),
                  subtitle: Text(start.toString().substring(0, 19)),
                  trailing: Text(
                    session['end_time'] == null ? 'Active' : 'Completed',
                  ),
                  onTap: () => open(session),
                );
              },
            ),
          ),
  );
}
