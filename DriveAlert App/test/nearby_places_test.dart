import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivealert/services/nearby_places_service.dart';

Map<String, dynamic> node(
  int id,
  String amenity,
  double lat, {
  String name = '',
  Map<String, String> extra = const {},
}) => {
  'id': id,
  'type': 'node',
  'lat': lat,
  'lon': 101.0,
  'tags': {'amenity': amenity, 'name': name, ...extra},
};

void main() {
  test(
    'parses actual map categories, centres and facilities; skips private/malformed duplicates',
    () {
      final places = NearbyPlacesService.parse([
        node(
          1,
          'cafe',
          3.001,
          name: 'Example Cafe',
          extra: {'opening_hours': '24/7', 'toilets': 'yes'},
        ),
        {
          'id': 2,
          'type': 'way',
          'center': {'lat': 3.002, 'lon': 101.0},
          'tags': {'highway': 'rest_area', 'name': 'Example Rest Area'},
        },
        node(3, 'fuel', 3.003, name: 'Example Fuel'),
        node(4, 'restaurant', 3.004, name: 'Example Food'),
        node(5, 'parking', 3.005, extra: {'access': 'private'}),
        node(6, 'parking', 3.006, extra: {'access': 'customers'}),
        node(7, 'parking', 3.007),
        node(8, 'cafe', 3.00101, name: 'Example Cafe'),
        node(9, 'cafe', 999, name: 'Bad coordinates'),
        node(10, 'cafe', 3.008, extra: {'disused': 'yes'}),
        {
          'tags': {'amenity': 'fuel'},
        },
        null,
      ]);
      expect(places.length, 5);
      expect(places[0].listed24Hours, isTrue);
      expect(places[0].toilets, isTrue);
      expect(places[1].category, StopCategory.rest);
      expect(places.last.name, 'Mapped parking area');
      expect(places[0].directions.host, 'www.google.com');
      expect(
        places[0].directions.queryParameters['destination'],
        '3.001,101.0',
      );
    },
  );

  test(
    'sorts by distance, filters radius, caches results and sends only approximate location',
    () async {
      var calls = 0;
      final service = NearbyPlacesService(
        client: MockClient((request) async {
          calls++;
          expect(
            request.url.toString(),
            'https://overpass-api.de/api/interpreter',
          );
          final query = request.bodyFields['data']!;
          expect(query, contains('3.000,101.000'));
          expect(query, isNot(contains('3.000123')));
          expect(
            request.headers.keys.any(
              (key) => key.toLowerCase() == 'authorization',
            ),
            isFalse,
          );
          return http.Response(
            jsonEncode({
              'elements': [
                node(1, 'fuel', 3.03),
                node(2, 'cafe', 3.001),
                node(3, 'cafe', 4.0),
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      const origin = RestStopLocation(3.000123, 101.000123);
      final results = await service.find(origin);
      expect(results.length, 2);
      expect(results.first.category, StopCategory.cafe);
      await service.find(origin);
      expect(calls, 1);
    },
  );

  test('coalesces simultaneous searches for the same area', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final service = NearbyPlacesService(
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    addTearDown(service.close);
    final first = service.find(const RestStopLocation(3, 101));
    final second = service.find(const RestStopLocation(3, 101));
    await Future<void>.delayed(Duration.zero);
    pending.complete(http.Response('{"elements":[]}', 200));
    expect(await first, isEmpty);
    expect(await second, isEmpty);
    expect(calls, 1);
  });

  test(
    'rate limit has a cooldown and errors never become made-up recommendations',
    () async {
      var time = DateTime(2026, 10, 16);
      var calls = 0;
      final service = NearbyPlacesService(
        clock: () => time,
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response('busy', 429)
              : http.Response('{"elements":[]}', 200);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.find(const RestStopLocation(3, 101)),
        throwsA(isA<NearbyPlacesException>()),
      );
      await expectLater(
        service.find(const RestStopLocation(3, 101)),
        throwsA(isA<NearbyPlacesException>()),
      );
      expect(calls, 1);
      time = time.add(const Duration(seconds: 31));
      expect(await service.find(const RestStopLocation(3, 101)), isEmpty);
      expect(calls, 2);
    },
  );

  test(
    'rejects partial, invalid, oversized and failed provider responses',
    () async {
      for (final response in [
        http.Response('not-json', 200),
        http.Response('{"remark":"timed out","elements":[]}', 200),
        http.Response('unavailable', 503),
        http.Response('x' * (1024 * 1024 + 1), 200),
      ]) {
        final service = NearbyPlacesService(
          client: MockClient((_) async => response),
        );
        await expectLater(
          service.find(const RestStopLocation(3, 101)),
          throwsA(isA<NearbyPlacesException>()),
        );
        service.close();
      }
    },
  );
}
