import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/user_message.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<String, dynamic>? status;
  String? message;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final response = await ApiService.getPushStatus();
      if (!mounted) return;
      setState(() {
        status = response.statusCode == 200 ? jsonDecode(response.body) : null;
        if (response.statusCode != 200) {
          message = ApiService.errorText(response);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          message = 'Unable to load notification settings. Please try again.';
        });
      }
    }
  }

  Future<void> perform(Future<String> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await action();
      if (mounted) {
        setState(() {
          message = result;
        });
      }
      await refresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          message = UserMessage.from(
            error,
            fallback: 'Unable to update notifications. Please try again.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Receive recorded fatigue alerts',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Get recorded fatigue warnings on your phone. Notifications need internet. Your live monitoring alarm is managed separately in Monitor.',
        ),
        const SizedBox(height: 20),
        if (!NotificationService.supported)
          const Text('Notifications are available in the Android app.'),
        if (status != null) ...[
          ListTile(
            title: const Text('Account preference'),
            trailing: Text(status!['enabled'] == true ? 'Enabled' : 'Disabled'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded),
            title: const Text('Delivery service'),
            trailing: Text(
              status!['server_configured'] == true ? 'Ready' : 'Unavailable',
            ),
          ),
        ],
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SelectableText(message!),
          ),
        FilledButton(
          onPressed: busy || !NotificationService.supported
              ? null
              : () => perform(() => NotificationService.enable()),
          child: const Text('Enable on this phone'),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => perform(() async {
                  await NotificationService.disable();
                  return 'Push notifications disabled.';
                }),
          child: const Text('Disable notifications'),
        ),
        OutlinedButton(
          onPressed: busy || !NotificationService.supported
              ? null
              : () => perform(NotificationService.sendTest),
          child: const Text('Send test to this phone'),
        ),
        TextButton(
          onPressed: busy ? null : refresh,
          child: const Text('Refresh status'),
        ),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
