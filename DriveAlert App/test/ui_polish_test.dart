import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivealert/screens/dashboard_screen.dart';
import 'package:drivealert/screens/login_screen.dart';
import 'package:drivealert/services/api_service.dart';
import 'package:drivealert/services/user_message.dart';
import 'package:drivealert/ui/app_theme.dart';
import 'package:drivealert/ui/app_bottom_nav.dart';
import 'package:drivealert/ui/assistant_bubble.dart';

void main() {
  test(
    'technical messages are hidden while useful validation stays readable',
    () {
      for (final error in [
        'SocketException: 10.13.1.97:8000',
        'http://192.168.1.2/api/status',
        'ILMU HTTP 401',
        'Firebase credential missing',
      ]) {
        final message = UserMessage.from(error);
        expect(message, isNot(contains('10.13.1.97')));
        expect(message, isNot(contains('192.168')));
        expect(message, isNot(contains('http')));
        expect(message, isNot(contains('401')));
        expect(message, isNot(contains('credential')));
      }
      expect(
        UserMessage.from('Passwords do not match.'),
        'Passwords do not match.',
      );
      expect(
        UserMessage.from('Enable notifications in Android app settings.'),
        contains('Android app settings'),
      );
    },
  );

  testWidgets('login does not expose server editing or addresses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    );
    expect(find.text('Server connection'), findsNothing);
    expect(find.text('Backend address'), findsNothing);
    expect(find.textContaining('http://'), findsNothing);
  });

  for (final width in [320.0, 412.0]) {
    testWidgets('dashboard and chat bubble fit at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ApiService.client = MockClient((request) async {
        final data = request.url.path.endsWith('/chat/')
            ? {'reply': 'Take regular rest breaks.', 'provider': 'ilmu'}
            : request.url.path.endsWith('/auth/me/')
            ? {'username': 'Preetika'}
            : request.url.path.contains('/monitor/')
            ? {'monitoring': false, 'camera': false, 'status': 'Stopped'}
            : {
                'total_sessions': 3,
                'total_microsleeps': 2,
                'total_driving_duration_seconds': 3600,
              };
        return http.Response(jsonEncode(data), 200);
      });
      addTearDown(ApiService.client.close);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const DashboardScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.byType(AssistantBubble), findsOneWidget);
      expect(find.textContaining('http://'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Ask DriveAlert'));
      await tester.pumpAndSettle();
      expect(find.text('DriveAlert assistant'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byType(TextField),
        'Help me plan a rest break',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Take regular rest breaks.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.tap(find.byTooltip('Close assistant'));
      await tester.pumpAndSettle();
      expect(find.text('DriveAlert assistant'), findsNothing);
    });
  }
}
