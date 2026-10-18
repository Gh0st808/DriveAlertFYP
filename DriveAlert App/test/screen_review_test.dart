import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivealert/screens/analytics_screen.dart';
import 'package:drivealert/screens/settings_screen.dart';
import 'package:drivealert/screens/live_monitor_screen.dart';
import 'package:drivealert/screens/sos_screen.dart';
import 'package:drivealert/screens/profile_screen.dart';
import 'package:drivealert/screens/edit_profile_screen.dart';
import 'package:drivealert/screens/journeys_screen.dart';
import 'package:drivealert/screens/notification_settings_screen.dart';
import 'package:drivealert/screens/signup_screen.dart';
import 'package:drivealert/screens/forgot_password_screen.dart';
import 'package:drivealert/screens/change_password_screen.dart';
import 'package:drivealert/screens/rest_stop_screen.dart';
import 'package:drivealert/services/api_service.dart';
import 'package:drivealert/ui/app_theme.dart';

void main() {
  final screens = <String, Widget>{
    'Analytics': const AnalyticsScreen(),
    'Settings': const SettingsScreen(),
    'Monitor': const LiveMonitorScreen(),
    'SOS': const SosScreen(),
    'Profile': const ProfileScreen(),
    'Edit profile': const EditProfileScreen(),
    'Journeys': const JourneysScreen(),
    'Notifications': const NotificationSettingsScreen(),
    'Sign up': const SignupScreen(),
    'Reset password': const ForgotPasswordScreen(),
    'Change password': const ChangePasswordScreen(),
    'Rest stops': const RestStopScreen(),
  };
  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders without layout errors on a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final name in [
        'flutter.baseflow.com/geolocator',
        'flutter.baseflow.com/geolocator_windows',
      ]) {
        final channel = MethodChannel(name);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async => false,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
      }
      ApiService.client = MockClient((r) async {
        final path = r.url.path;
        final Object data =
            path.endsWith('/devices/') ||
                path.endsWith('/events/') ||
                path.endsWith('/sessions/')
            ? []
            : path.endsWith('/auth/me/')
            ? {
                'username': 'Driver',
                'email': 'driver@example.com',
                'profile': {},
              }
            : path.contains('/monitor/')
            ? {'monitoring': false, 'camera': false}
            : path.endsWith('/profile/')
            ? {'full_name': 'Driver', 'email': 'driver@example.com'}
            : path.contains('/notifications/')
            ? {'enabled': false, 'server_configured': true}
            : {};
        return http.Response(jsonEncode(data), 200);
      });
      addTearDown(ApiService.client.close);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: entry.value),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('http://'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
