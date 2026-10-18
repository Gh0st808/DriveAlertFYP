import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/nearby_places_service.dart';
import '../services/user_message.dart';
import '../ui/app_theme.dart';

class RestStopScreen extends StatefulWidget {
  const RestStopScreen({super.key, this.placesService, this.locationLoader});
  final NearbyPlacesService? placesService;
  final Future<RestStopLocation> Function()? locationLoader;
  @override
  State<RestStopScreen> createState() => _RestStopScreenState();
}

class _RestStopScreenState extends State<RestStopScreen> {
  NearbyPlacesService get _service =>
      widget.placesService ?? NearbyPlacesService.shared;
  RestStopLocation? _location;
  List<NearbyStop> _places = [];
  StopCategory _category = StopCategory.all;
  int _radius = 5;
  int _generation = 0;
  bool _busy = true;
  bool _locating = true;
  String? _error;
  String? _settingsAction;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<RestStopLocation> _getLocation() async {
    if (widget.locationLoader != null) return widget.locationLoader!();
    if (!await Geolocator.isLocationServiceEnabled()) {
      _settingsAction = 'location';
      throw const NearbyPlacesException(
        'Turn on location to find places around you.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _settingsAction = 'app';
      throw const NearbyPlacesException(
        'Allow location access to find nearby rest stops.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return RestStopLocation(position.latitude, position.longitude);
  }

  Future<void> _load({bool refreshLocation = true}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _locating = refreshLocation;
      _error = null;
      _settingsAction = null;
    });
    try {
      final location = refreshLocation || _location == null
          ? await _getLocation()
          : _location!;
      if (!mounted || generation != _generation) return;
      setState(() {
        _location = location;
        _locating = false;
      });
      final places = await _service.find(location, radiusKm: _radius);
      if (!mounted || generation != _generation) return;
      setState(() => _places = places);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _places = [];
        _error = UserMessage.from(
          error,
          fallback: 'Unable to load nearby places. Please try again.',
        );
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open Maps or your browser. Please try again.',
            ),
          ),
        );
      }
    }
  }

  void _searchMaps() {
    final location = _location;
    _open(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': location == null
            ? '${_category.searchTerm} near me'
            : '${_category.searchTerm} near ${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}',
      }),
    );
  }

  static IconData _icon(StopCategory category) => switch (category) {
    StopCategory.all => Icons.explore_rounded,
    StopCategory.rest => Icons.local_parking_rounded,
    StopCategory.fuel => Icons.local_gas_station_rounded,
    StopCategory.cafe => Icons.local_cafe_rounded,
    StopCategory.food => Icons.restaurant_rounded,
    StopCategory.parking => Icons.directions_car_rounded,
  };

  static Color _color(StopCategory category) => switch (category) {
    StopCategory.rest => const Color(0xFF218267),
    StopCategory.fuel => const Color(0xFF2161F5),
    StopCategory.cafe => const Color(0xFF996533),
    StopCategory.food => const Color(0xFFD87A26),
    _ => const Color(0xFF6861B8),
  };

  String _distance(NearbyStop place) {
    final metres = _location!.distanceTo(place.latitude, place.longitude);
    return metres < 1000
        ? '${(metres / 10).round() * 10} m away'
        : '${(metres / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _places
        .where(
          (place) =>
              _category == StopCategory.all || place.category == _category,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rest stops'),
        actions: [
          IconButton(
            tooltip: 'Refresh nearby places',
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: SizedBox(
            height: 66,
            child: ListView.separated(
              key: const ValueKey('stop-categories'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 14),
              itemCount: StopCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final category = StopCategory.values[i];
                final selected = _category == category;
                return ChoiceChip(
                  showCheckmark: false,
                  selected: selected,
                  selectedColor: AppTheme.blue,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? AppTheme.blue : AppTheme.line,
                  ),
                  avatar: Icon(
                    _icon(category),
                    size: 18,
                    color: selected ? Colors.white : AppTheme.muted,
                  ),
                  label: Text(
                    category.label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onSelected: (_) => setState(() => _category = category),
                );
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          key: const ValueKey('stop-results'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        color: AppTheme.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _location == null
                              ? 'Find your next break'
                              : 'Around your current location',
                          style: const TextStyle(
                            color: AppTheme.blue,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A good journey\nincludes a pause.',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Find a nearby place to park, take a break or get something to eat.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Search distance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _radius,
                            borderRadius: BorderRadius.circular(16),
                            items: [3, 5, 10]
                                .map(
                                  (radius) => DropdownMenuItem(
                                    value: radius,
                                    child: Text('$radius km'),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (radius) {
                                    if (radius == null || radius == _radius) {
                                      return;
                                    }
                                    setState(() {
                                      _radius = radius;
                                      _places = [];
                                    });
                                    _load(refreshLocation: _location == null);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Nearby recommendations',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                if (!_busy && _error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${visible.length} listed',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _category == StopCategory.all
                  ? 'Mapped places, sorted by approximate distance.'
                  : '${_category.label} within $_radius km, closest first.',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            if (_busy)
              _loadingCard()
            else if (_error != null)
              _messageCard(
                Icons.location_off_rounded,
                'Let’s find your next stop',
                _error!,
              )
            else if (visible.isEmpty)
              _messageCard(
                Icons.travel_explore_rounded,
                'No matching places listed',
                'Try another category, increase the search distance, or look in Maps for more options.',
              )
            else ...[
              for (var i = 0; i < visible.length && i < 24; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _placeCard(visible[i], nearest: i == 0),
                ),
              if (visible.length > 24)
                Text(
                  'Showing the nearest 24 of ${visible.length} listed places.',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _searchMaps,
              icon: const Icon(Icons.map_rounded),
              label: const Text('Explore more in Maps'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Distances are approximate, not driving routes. Map data may be incomplete. Check access and opening hours in Maps before choosing a stop.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nearby search shares your approximate location with the map data service. Maps opens only when you choose it.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                height: 1.5,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    _open(Uri.https('www.openstreetmap.org', '/copyright')),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _locating
                  ? 'Finding your location…'
                  : 'Looking for nearby places…',
              style: const TextStyle(color: AppTheme.muted),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _messageCard(IconData icon, String title, String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.blue, size: 36),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (_settingsAction != null)
            TextButton(
              onPressed: () async {
                try {
                  if (_settingsAction == 'location') {
                    await Geolocator.openLocationSettings();
                  } else {
                    await Geolocator.openAppSettings();
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Open your phone settings to enable location.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Open location settings'),
            ),
          TextButton.icon(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _placeCard(NearbyStop place, {required bool nearest}) {
    final color = _color(place.category);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: nearest ? AppTheme.blue.withValues(alpha: .35) : AppTheme.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nearest) ...[
            const Text(
              'NEAREST IN THIS LIST',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                color: AppTheme.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_icon(place.category), color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      place.category.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (place.address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                place.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(Icons.near_me_rounded, _distance(place)),
              if (place.listed24Hours)
                _badge(Icons.schedule_rounded, 'Listed as 24h'),
              if (place.toilets) _badge(Icons.wc_rounded, 'Toilets'),
              if (place.wheelchair)
                _badge(Icons.accessible_rounded, 'Accessible'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _open(place.directions),
              icon: const Icon(Icons.directions_rounded, size: 20),
              label: const Text('Directions'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.muted),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
      ],
    ),
  );
}
