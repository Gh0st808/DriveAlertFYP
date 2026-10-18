import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

enum StopCategory {
  all('All nearby', 'rest stops'),
  rest('Rest areas', 'rest areas'),
  fuel('Fuel', 'petrol stations'),
  cafe('Cafes', 'cafes'),
  food('Food', 'restaurants'),
  parking('Parking', 'public parking');

  const StopCategory(this.label, this.searchTerm);
  final String label;
  final String searchTerm;
}

class RestStopLocation {
  const RestStopLocation(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  double distanceTo(double lat, double lon) {
    const radians = math.pi / 180;
    final a =
        math.pow(math.sin((lat - latitude) * radians / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(lat * radians) *
            math.pow(math.sin((lon - longitude) * radians / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

class NearbyStop {
  const NearbyStop({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.listed24Hours = false,
    this.toilets = false,
    this.wheelchair = false,
  });
  final String id;
  final String name;
  final StopCategory category;
  final double latitude;
  final double longitude;
  final String address;
  final bool listed24Hours;
  final bool toilets;
  final bool wheelchair;

  Uri get directions => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'driving',
  });
}

class NearbyPlacesException implements Exception {
  const NearbyPlacesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _CachedStops {
  _CachedStops(this.time, this.stops);
  final DateTime time;
  final List<NearbyStop> stops;
}

/// No key, account data or driving history is sent. Cache is in memory only.
class NearbyPlacesService {
  NearbyPlacesService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;
  static final shared = NearbyPlacesService();
  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, _CachedStops> _cache = {};
  final Map<String, Future<List<NearbyStop>>> _pending = {};
  DateTime? _blockedUntil;

  void close() => _client.close();

  Future<List<NearbyStop>> find(
    RestStopLocation location, {
    int radiusKm = 5,
  }) async {
    if (!location.valid || ![3, 5, 10].contains(radiusKm)) {
      throw const NearbyPlacesException(
        'Choose a valid location and search distance.',
      );
    }
    // Approximate the search centre to about a neighbourhood, not precise GPS.
    final lat = location.latitude.toStringAsFixed(3);
    final lon = location.longitude.toStringAsFixed(3);
    final key = '$lat,$lon,$radiusKm';
    final cached = _cache[key];
    List<NearbyStop> result;
    if (cached != null &&
        _clock().difference(cached.time) < const Duration(minutes: 10)) {
      result = cached.stops;
    } else {
      if (_blockedUntil != null && _clock().isBefore(_blockedUntil!)) {
        throw const NearbyPlacesException(
          'Nearby search is busy. Wait a little before trying again, or search in Maps.',
        );
      }
      final existing = _pending[key];
      if (existing != null) {
        result = await existing;
      } else {
        final request = _fetch(lat, lon, radiusKm);
        _pending[key] = request;
        try {
          result = await request;
          if (_cache.length >= 4) _cache.remove(_cache.keys.first);
          _cache[key] = _CachedStops(_clock(), result);
        } finally {
          _pending.remove(key);
        }
      }
    }
    final filtered = result
        .where(
          (place) =>
              location.distanceTo(place.latitude, place.longitude) <=
              radiusKm * 1000,
        )
        .toList();
    filtered.sort(
      (a, b) => location
          .distanceTo(a.latitude, a.longitude)
          .compareTo(location.distanceTo(b.latitude, b.longitude)),
    );
    return filtered;
  }

  Future<List<NearbyStop>> _fetch(String lat, String lon, int radiusKm) async {
    final radius = radiusKm * 1000 + 100;
    final query =
        '[out:json][timeout:12];('
        'nwr["highway"~"^(rest_area|services)\u0024"](around:$radius,$lat,$lon);'
        'nwr["amenity"~"^(fuel|cafe|restaurant|fast_food|parking)\u0024"](around:$radius,$lat,$lon);'
        ');out body center 250;';
    try {
      final request =
          http.Request('POST', Uri.https('overpass-api.de', '/api/interpreter'))
            ..followRedirects = false
            ..headers['Accept'] = 'application/json'
            ..headers['User-Agent'] = 'DriveAlert/1.0 nearby-rest-stops'
            ..bodyFields = {'data': query};
      final result = await (() async {
        final response = await _client.send(request);
        if (response.statusCode == 429) {
          _blockedUntil = _clock().add(const Duration(seconds: 30));
          await response.stream.drain<void>();
          throw const NearbyPlacesException(
            'Nearby search is busy. Wait a little before trying again, or search in Maps.',
          );
        }
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw const NearbyPlacesException(
            'Nearby places are unavailable right now. You can still search in Maps.',
          );
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 1024 * 1024) {
            throw const NearbyPlacesException(
              'This area has too many results. Try a smaller search distance.',
            );
          }
          bytes.addAll(chunk);
        }
        return jsonDecode(utf8.decode(bytes));
      })().timeout(const Duration(seconds: 20));
      if (result is! Map ||
          result['elements'] is! List ||
          result['remark'] != null) {
        throw const NearbyPlacesException(
          'Nearby search could not finish. Try again later or open Maps.',
        );
      }
      return parse(result['elements'] as List);
    } on NearbyPlacesException {
      rethrow;
    } catch (_) {
      throw const NearbyPlacesException(
        'Unable to load nearby places. Check your internet connection or search in Maps.',
      );
    }
  }

  static List<NearbyStop> parse(List<dynamic> elements) {
    final places = <NearbyStop>[];
    final ids = <String>{};
    String clean(dynamic value) {
      if (value is! String) return '';
      final text = value.replaceAll(RegExp(r'[\x00-\x1f]'), ' ').trim();
      return text.substring(0, math.min(text.length, 140));
    }

    for (final element in elements) {
      if (element is! Map || element['tags'] is! Map) continue;
      final tags = element['tags'] as Map;
      if (['private', 'no'].contains(tags['access']) ||
          tags['disused'] == 'yes' ||
          tags['abandoned'] == 'yes') {
        continue;
      }
      final category = switch (tags['highway']) {
        'rest_area' || 'services' => StopCategory.rest,
        _ => switch (tags['amenity']) {
          'fuel' => StopCategory.fuel,
          'cafe' => StopCategory.cafe,
          'restaurant' || 'fast_food' => StopCategory.food,
          'parking' => StopCategory.parking,
          _ => null,
        },
      };
      if (category == null ||
          (category == StopCategory.parking && tags['access'] == 'customers')) {
        continue;
      }
      final centre = element['center'] is Map
          ? element['center'] as Map
          : element;
      final lat = centre['lat'];
      final lon = centre['lon'];
      if (lat is! num ||
          lon is! num ||
          !RestStopLocation(lat.toDouble(), lon.toDouble()).valid) {
        continue;
      }
      final id = '${element['type']}/${element['id']}';
      if (element['id'] == null || !ids.add(id)) continue;
      final name =
          [tags['name'], tags['name:en'], tags['brand'], tags['operator']]
              .map(clean)
              .firstWhere(
                (name) => name.isNotEmpty,
                orElse: () => switch (category) {
                  StopCategory.rest => 'Mapped rest area',
                  StopCategory.fuel => 'Petrol station',
                  StopCategory.cafe => 'Cafe',
                  StopCategory.food => 'Food stop',
                  _ => 'Mapped parking area',
                },
              );
      if (places.any(
        (place) =>
            place.category == category &&
            place.name.toLowerCase() == name.toLowerCase() &&
            RestStopLocation(
                  place.latitude,
                  place.longitude,
                ).distanceTo(lat.toDouble(), lon.toDouble()) <
                25,
      )) {
        continue;
      }
      final address = [
        tags['addr:street'],
        tags['addr:suburb'],
        tags['addr:city'],
      ].map(clean).where((part) => part.isNotEmpty).toSet().join(', ');
      places.add(
        NearbyStop(
          id: id,
          name: name,
          category: category,
          latitude: lat.toDouble(),
          longitude: lon.toDouble(),
          address: address,
          listed24Hours: tags['opening_hours'] == '24/7',
          toilets: tags['toilets'] == 'yes',
          wheelchair: tags['wheelchair'] == 'yes',
        ),
      );
    }
    return places;
  }
}
