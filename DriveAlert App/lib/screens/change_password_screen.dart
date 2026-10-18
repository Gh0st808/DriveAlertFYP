import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (next.text != confirm.text) {
      setState(() {
        error = 'Passwords do not match.';
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final response = await ApiService.changePassword(current.text, next.text);
      if (!mounted) return;
      if (response.statusCode == 200) {
        await NotificationService.beforeLogout();
        if (!mounted) return;
        ApiService.accessToken = null;
        ApiService.refreshToken = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed. Please sign in again.'),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        setState(() {
          error = ApiService.errorText(response);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to reach the server.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change password')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        TextField(
          controller: next,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        TextField(
          controller: confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Savingâ€¦' : 'Change password'),
        ),
      ],
    ),
  );
}
