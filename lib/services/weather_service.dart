import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;
}

class WeatherService {
  Future<Weather> fetchWeather(String city) {
    return _withWeatherErrors(() async {
      final query = city.trim();
      if (query.length < 2) {
        throw const WeatherException(
          'Enter a city name with at least two letters.',
        );
      }

      final search = await _getJson(
        Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
          'name': query,
          'count': '1',
          'language': 'en',
        }),
      );

      final results = search['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        throw const WeatherException(
          'City not found. Check the spelling and try again.',
        );
      }

      final location = results.first as Map<String, dynamic>;
      final name = location['name'] as String;
      final country = location['country'] as String?;

      return _fetchForecast(
        latitude: (location['latitude'] as num).toDouble(),
        longitude: (location['longitude'] as num).toDouble(),
        label: country == null ? name : '$name, $country',
      );
    });
  }

  Future<Weather> fetchWeatherByCoordinates({
    required double latitude,
    required double longitude,
  }) {
    return _withWeatherErrors(
      () => _fetchForecast(
        latitude: latitude,
        longitude: longitude,
        label: 'Current location',
      ),
    );
  }

  Future<Weather> _fetchForecast({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    final forecast = await _getJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,apparent_temperature,'
            'relative_humidity_2m,wind_speed_10m,weather_code',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'forecast_days': '5',
        'timezone': 'auto',
      }),
    );

    final daily = forecast['daily'] as Map<String, dynamic>;
    final dates = daily['time'] as List<dynamic>;
    final highs = daily['temperature_2m_max'] as List<dynamic>;
    final lows = daily['temperature_2m_min'] as List<dynamic>;

    final forecastDays = List<ForecastDay>.generate(dates.length, (index) {
      return ForecastDay(
        date: DateTime.parse(dates[index] as String),
        high: (highs[index] as num).toDouble(),
        low: (lows[index] as num).toDouble(),
      );
    }, growable: false);

    return Weather.fromJson(
      city: label,
      current: forecast['current'] as Map<String, dynamic>,
      forecast: forecastDays,
    );
  }

  Future<Weather> _withWeatherErrors(
    Future<Weather> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException {
      throw const WeatherException('The request timed out. Try again.');
    } on http.ClientException {
      throw const WeatherException(
        'Check your internet connection and try again.',
      );
    } on FormatException {
      throw const WeatherException(
        'Weather data could not be read. Try again.',
      );
    } on TypeError {
      throw const WeatherException(
        'The weather service returned incomplete data.',
      );
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const WeatherException(
        'The weather service is unavailable. Try again.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}