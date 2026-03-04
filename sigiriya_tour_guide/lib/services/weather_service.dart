import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WeatherService {
  // Load API key from .env file
  static String get _apiKey => dotenv.env['OPENWEATHER_API_KEY'] ?? '';
  static const double _lat = 7.957;
  static const double _lon = 80.76;
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  Future<WeatherData?> fetchWeather() async {
    try {
      final url = Uri.parse(
        '$_baseUrl?lat=$_lat&lon=$_lon&appid=$_apiKey&units=metric',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        debugPrint('Failed to load weather: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      return null;
    }
  }
}

class WeatherData {
  final int weatherId; // Weather condition code
  final double visibility; // Visibility in meters
  final DateTime sunrise;
  final DateTime sunset;
  final double temperature; // Current temperature in Celsius
  final int cloudiness; // Cloudiness as a percentage
  final double humidity; // Humidity percentage
  final double windSpeed; // Wind speed in m/s
  final double rainVolume; // Rain volume last 1h in mm (0 if no rain)

  WeatherData({
    required this.weatherId,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.temperature,
    required this.cloudiness,
    required this.humidity,
    required this.windSpeed,
    required this.rainVolume,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    // Safely extract weather list
    final weatherList = json['weather'] as List?;
    final firstWeather = (weatherList != null && weatherList.isNotEmpty)
        ? weatherList[0]
        : null;

    return WeatherData(
      weatherId: (firstWeather?['id'] as num?)?.toInt() ?? 800,
      visibility: (json['visibility'] as num?)?.toDouble() ?? 10000.0,
      sunrise: DateTime.fromMillisecondsSinceEpoch(
        (json['sys']?['sunrise'] ?? 0) * 1000,
      ),
      sunset: DateTime.fromMillisecondsSinceEpoch(
        (json['sys']?['sunset'] ?? 0) * 1000,
      ),
      temperature: (json['main']?['temp'] as num?)?.toDouble() ?? 0.0,
      cloudiness: (json['clouds']?['all'] as num?)?.toInt() ?? 0,
      humidity: (json['main']?['humidity'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (json['wind']?['speed'] as num?)?.toDouble() ?? 0.0,
      rainVolume: (json['rain']?['1h'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
