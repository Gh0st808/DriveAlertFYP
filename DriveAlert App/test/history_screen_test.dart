import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivealert/screens/history_screen.dart';
import 'package:drivealert/services/api_service.dart';

void main() {
  testWidgets(
    'history renders backend events instead of predefined sample records',
    (tester) async {
      ApiService.client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'event_type': 'microsleep',
              'timestamp': '2026-10-15T10:00:00Z',
              'duration': 0.8,
              'ear_value': 0.12,
              'session': 7,
            },
          ]),
          200,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('0.80 seconds'), findsOneWidget);
      expect(find.textContaining('journey 7'), findsOneWidget);
      expect(find.text('3.8 seconds'), findsNothing);
      ApiService.client.close();
    },
  );

  testWidgets('history offers a retry when loading fails', (tester) async {
    ApiService.client = MockClient((_) async => http.Response('{}', 503));
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to load history'), findsOneWidget);
    expect(find.text('Refresh history'), findsOneWidget);
    ApiService.client.close();
  });
}
