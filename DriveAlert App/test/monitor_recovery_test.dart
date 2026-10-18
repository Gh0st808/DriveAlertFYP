import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivealert/screens/live_monitor_screen.dart';
import 'package:drivealert/services/api_service.dart';
import 'package:drivealert/ui/app_theme.dart';

void main() {
  testWidgets('failed preview clears the last image and later frames recover', (tester) async {
    var frames = 0;
    final bytes = File('android/app/src/main/res/mipmap-mdpi/ic_launcher.png').readAsBytesSync();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('drivealert/phone_alarm'), (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('drivealert/phone_alarm'), null));
    ApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/frame')) {
        frames++;
        return frames == 2 ? http.Response('unavailable', 503)
            : http.Response.bytes(bytes, 200, headers: {'content-type': 'image/png'});
      }
      return http.Response(jsonEncode({
        'monitoring': true, 'driver_detected': false, 'calibrating': true,
        'visibility_warning': true, 'run_id': 'test-run', 'phone_alarm_token': 'test-token',
      }), 200);
    });
    addTearDown(ApiService.client.close);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const LiveMonitorScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Face not clearly visible. Check lighting and camera position.'), findsOneWidget);
    expect(find.text('Awake'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('connection failure keeps Stop available for an active session', (tester) async {
    var statusCalls = 0;
    ApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/status')) {
        statusCalls++;
        return statusCalls == 1
            ? http.Response('{"monitoring":true,"driver_detected":true}', 200)
            : http.Response('{}', 503);
      }
      return http.Response('{}', 503);
    });
    addTearDown(ApiService.client.close);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const LiveMonitorScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    final stop = find.widgetWithText(ElevatedButton, 'Stop Monitoring');
    expect(stop, findsOneWidget);
    expect(tester.widget<ElevatedButton>(stop).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
