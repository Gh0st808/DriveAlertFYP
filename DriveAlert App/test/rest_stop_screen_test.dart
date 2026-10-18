import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivealert/screens/rest_stop_screen.dart';
import 'package:drivealert/services/nearby_places_service.dart';
import 'package:drivealert/ui/app_theme.dart';

void main() {
  for (final width in [320.0, 412.0]) {
    testWidgets('nearby cards and category filtering work at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final service = NearbyPlacesService(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 1,
                  'lat': 3.001,
                  'lon': 101,
                  'tags': {
                    'name': 'Example Cafe',
                    'amenity': 'cafe',
                    'opening_hours': '24/7',
                  },
                },
                {
                  'type': 'node',
                  'id': 2,
                  'lat': 3.002,
                  'lon': 101,
                  'tags': {'name': 'Example Fuel', 'amenity': 'fuel'},
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RestStopScreen(
            placesService: service,
            locationLoader: () async => const RestStopLocation(3, 101),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nearby recommendations'), findsOneWidget);
      expect(find.text('Find nearby in Maps'), findsOneWidget);
      expect(find.text('Search distance'), findsNothing);
      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(find.text('Example Cafe'), findsOneWidget);
      expect(find.textContaining('http://'), findsNothing);
      expect(tester.takeException(), isNull);
      final fuel = find.widgetWithText(ChoiceChip, 'Fuel');
      await tester.scrollUntilVisible(
        fuel,
        160,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('stop-categories')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(fuel);
      await tester.pumpAndSettle();
      expect(find.text('Example Cafe'), findsNothing);
      expect(find.text('Example Fuel'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty places show an honest empty state and Maps fallback', (
    tester,
  ) async {
    final service = NearbyPlacesService(
      client: MockClient((_) async => http.Response('{"elements":[]}', 200)),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RestStopScreen(
          placesService: service,
          locationLoader: () async => const RestStopLocation(3, 101),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching places listed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Explore more in Maps'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('stop-results')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Explore more in Maps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location failures offer recovery without provider details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RestStopScreen(
          locationLoader: () async => throw const NearbyPlacesException(
            'Allow location access to find nearby rest stops.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Allow location access to find nearby rest stops.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Explore more in Maps'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('stop-results')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Explore more in Maps'), findsOneWidget);
  });
}
