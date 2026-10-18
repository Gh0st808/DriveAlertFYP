import 'services/notification_service.dart';
import 'screens/chat_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/journeys_screen.dart';
import 'screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'ui/app_theme.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/live_monitor_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/history_screen.dart';
import 'screens/rest_stop_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const DriveAlertApp());
}

class DriveAlertApp extends StatelessWidget {
  const DriveAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      scaffoldMessengerKey: NotificationService.messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'DriveAlert',
      theme: AppTheme.light,

      initialRoute: '/login',

      routes: {
        '/chat': (context) => const ChatScreen(),
        '/notification-settings': (context) =>
            const NotificationSettingsScreen(),
        '/journeys': (context) => const JourneysScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const DashboardScreen(),
        '/monitor': (context) => const LiveMonitorScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
        '/sos': (context) => const SosScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/rest-stop': (context) => const RestStopScreen(),
        '/history': (context) => const HistoryScreen(),
      },

      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const PlaceholderScreen(
            title: 'Page Not Found',
            icon: Icons.error_outline,
          ),
        );
      },
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1EBFF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: const Color(0xFF2161F5), size: 40),
              ),

              const SizedBox(height: 20),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B2545),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'This page could not be found.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
