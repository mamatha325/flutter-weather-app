class Weather {
  const Weather({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    this.forecast = const [],
  });

  final String city;
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final int weatherCode;
  final List<ForecastDay> forecast;
  factory Weather.fromJson({
    required String city,
    required Map<String, dynamic> current,
    List<ForecastDay> forecast = const [],
  }) {
    return Weather(
      forecast: forecast,
      city: city,
      temperature: (current['temperature_2m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
    );
  }
}
class ForecastDay {
  const ForecastDay({
    required this.date,
    required this.high,
    required this.low,
  });

  final DateTime date;
  final double high;
  final double low;
}