
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  // Replace with your actual OpenWeatherMap API Key
  static const String _apiKey = '50cd382fe18a19ba417eb3e7d9f16fe0';
  static const double _lat = 7.957;
  static const double _lon = 80.760;
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  Future<WeatherData?> fetchWeather() async {
    try {
      final url = Uri.parse('$_baseUrl?lat=$_lat&lon=$_lon&appid=$_apiKey&units=metric');
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

  WeatherData({
    required this.weatherId,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.temperature,
    required this.cloudiness,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      weatherId: (json['weather'] as List).first['id'],
      visibility: (json['visibility'] as num).toDouble(),
      sunrise: DateTime.fromMillisecondsSinceEpoch(json['sys']['sunrise'] * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch(json['sys']['sunset'] * 1000),
      temperature: (json['main']['temp'] as num).toDouble(),
      cloudiness: (json['clouds']['all'] as num).toInt(),
    );
  }
}
