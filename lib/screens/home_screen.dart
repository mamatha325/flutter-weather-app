import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _cityController = TextEditingController();
  final _weatherService = WeatherService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
static const _recentCitiesKey = 'recent_cities';
List<String> _recentCities = [];
static const _savedCitiesKey = 'saved_cities';
List<String> _savedCities = [];

@override
void initState() {
  super.initState();
  _loadRecentCities();
}

Future<void> _loadRecentCities() async {
  final preferences = await SharedPreferences.getInstance();
  if (!mounted) return;

  setState(() {
    _recentCities = preferences.getStringList(_recentCitiesKey) ?? [];
    _savedCities = preferences.getStringList(_savedCitiesKey) ?? [];
  });
}
bool _updatingSavedCities = false;

bool _isCitySaved(String city) {
  return _savedCities.any((saved) => saved.toLowerCase() == city.toLowerCase());
}

Future<void> _toggleSavedCity(String city) async {
  if (_updatingSavedCities) return;
  _updatingSavedCities = true;

  try {
    final updatedCities = _isCitySaved(city)
        ? _savedCities
            .where((saved) => saved.toLowerCase() != city.toLowerCase())
            .toList()
        : [..._savedCities, city];

    final preferences = await SharedPreferences.getInstance();
    final stored = await preferences.setStringList(_savedCitiesKey, updatedCities);
    if (!stored) throw StateError('Could not update saved cities');

    if (!mounted) return;
    setState(() => _savedCities = updatedCities);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not update saved cities. Try again.')),
    );
  } finally {
    _updatingSavedCities = false;
  }
}
Future<void> _rememberCity(String city) async {
  final preferences = await SharedPreferences.getInstance();
  final savedCities = preferences.getStringList(_recentCitiesKey) ?? [];
  final updatedCities = [
    city,
    ...savedCities.where((saved) => saved.toLowerCase() != city.toLowerCase()),
  ].take(5).toList();

  await preferences.setStringList(_recentCitiesKey, updatedCities);
  if (!mounted) return;

  setState(() => _recentCities = updatedCities);
}
Future<Weather> _fetchCurrentLocationWeather() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const WeatherException('Turn on device location and try again.');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    throw const WeatherException(
      'Enable location permission in Android app settings, or search by city.',
    );
  }

  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    throw const WeatherException(
      'Allow location access to use this feature, or search by city.',
    );
  }

  final Position position;
  try {
    position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  } on Exception catch (error) {
  debugPrint('Location lookup failed: ${error.runtimeType}: $error');
    throw const WeatherException(
      'Could not get your location. Try again or search by city.',
    );
  }

  return _weatherService.fetchWeatherByCoordinates(
    latitude: position.latitude,
    longitude: position.longitude,
  );
}
  Future<void> _search({bool useLocation = false}) async {
    if (_loading) return;

    final city = _cityController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
     final weather = useLocation
    ? await _fetchCurrentLocationWeather()
    : await _weatherService.fetchWeather(city);

if (!useLocation) {
  await _rememberCity(city);
}
      if (!mounted) return;
      setState(() => _loading = false);

      Navigator.of(context).push(
                PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, _, _) => WeatherScreen(weather: weather),
          transitionsBuilder: (context, animation, _, child) {
            if (MediaQuery.of(context).disableAnimations) return child;

            final entrance = animation.drive(
              CurveTween(curve: Curves.easeOutCubic),
            );

            return FadeTransition(
              opacity: entrance,
              child: SlideTransition(
                position: entrance.drive(
                  Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ),
                ),
                child: child,
              ),
            );
          },
        ),
      );
    } on WeatherException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather App')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Find your city',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  labelText: 'City name',
                  hintText: 'e.g. Hyderabad',
                  prefixIcon: Icon(Icons.location_city),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _search,
                child: const Text('Search'),
              ),if (_recentCities.isNotEmpty) ...[
  const SizedBox(height: 16),
  const Text('Recent searches'),
  Wrap(
    spacing: 8,
    children: [
      for (final city in _recentCities)
        ActionChip(
          label: Text(city),
          onPressed: _loading
              ? null
              : () {
                  _cityController.text = city;
                  _search();
                },
        ),
    ],
  ),
],
if (_recentCities.any((city) => !_isCitySaved(city)))
  Wrap(
    spacing: 8,
    children: [
      for (final city in _recentCities.where((city) => !_isCitySaved(city)))
        TextButton.icon(
          onPressed: () => _toggleSavedCity(city),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text('Save $city'),
        ),
    ],
  ),
if (_savedCities.isNotEmpty) ...[
  const SizedBox(height: 16),
  const Text('Saved cities'),
  Wrap(
    spacing: 8,
    children: [
      for (final city in _savedCities)
        InputChip(
          label: Text(city),
          onPressed: _loading
              ? null
              : () {
                  _cityController.text = city;
                  _search();
                },
          onDeleted: () => _toggleSavedCity(city),
          deleteButtonTooltipMessage: 'Remove $city',
        ),
    ],
  ),
],
OutlinedButton.icon(
  onPressed: _loading ? null : () => _search(useLocation: true),
  icon: const Icon(Icons.my_location),
  label: const Text('Use my location'),
),
              if (_loading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key, required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final (condition, icon) = switch (weather.weatherCode) {
      0 => ('Clear sky', Icons.wb_sunny_outlined),
      1 || 2 => ('Partly cloudy', Icons.wb_cloudy_outlined),
      3 => ('Overcast', Icons.cloud_outlined),
      45 || 48 => ('Fog', Icons.blur_on),
      51 || 53 || 55 || 56 || 57 => ('Drizzle', Icons.grain),
      61 ||
      63 ||
      65 ||
      66 ||
      67 ||
      80 ||
      81 ||
      82 => ('Rain', Icons.water_drop),
      71 || 73 || 75 || 77 || 85 || 86 => ('Snow', Icons.ac_unit),
      95 || 96 || 99 => ('Thunderstorm', Icons.flash_on),
      _ => ('Unknown conditions', Icons.help_outline),
    };

    return Scaffold(
      backgroundColor: Color.alphaBlend(
        (switch (weather.weatherCode) {
          0 => Colors.amber,
          1 || 2 || 3 => Colors.blueGrey,
          45 || 48 => Colors.grey,
          71 || 73 || 75 || 77 || 85 || 86 => Colors.lightBlue,
          _ => Colors.indigo,
        }).withValues(alpha: 0.16),
        Theme.of(context).colorScheme.surface,
      ),
      appBar: AppBar(title: const Text('Current Weather')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                icon,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              Text(
                weather.city,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${weather.temperature.toStringAsFixed(1)} °C',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Text(condition, textAlign: TextAlign.center),
                            const SizedBox(height: 24),
              Text(
                '5-day forecast',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final day in weather.forecast)
                Card(
                  child: ListTile(
                    title: Text(
                      MaterialLocalizations.of(context).formatMediumDate(day.date),
                    ),
                    subtitle: Text('Low ${day.low.toStringAsFixed(0)} °C'),
                    trailing: Text('High ${day.high.toStringAsFixed(0)} °C'),
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Feels like'),
                      trailing: Text(
                        '${weather.feelsLike.toStringAsFixed(1)} °C',
                      ),
                    ),
                    ListTile(
                      title: const Text('Humidity'),
                      trailing: Text('${weather.humidity.toStringAsFixed(0)}%'),
                    ),
                    ListTile(
                      title: const Text('Wind speed'),
                      trailing: Text(
                        '${weather.windSpeed.toStringAsFixed(1)} km/h',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
