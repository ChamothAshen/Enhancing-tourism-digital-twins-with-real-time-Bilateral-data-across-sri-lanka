import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sigiriya_tour_guide/services/weather_service.dart';

class RiskPrediction {
  final bool fogRisk;
  final bool slipRisk;
  final bool heatStress;

  const RiskPrediction({
    required this.fogRisk,
    required this.slipRisk,
    required this.heatStress,
  });

  factory RiskPrediction.fromJson(Map<String, dynamic> json) {
    return RiskPrediction(
      fogRisk: json['fog_risk'] == 1,
      slipRisk: json['slip_risk'] == 1,
      heatStress: json['heat_stress'] == 1,
    );
  }

  @override
  String toString() =>
      'RiskPrediction(fog=$fogRisk, slip=$slipRisk, heat=$heatStress)';
}

class RiskPredictionService {
  static const String _predictUrl =
      'https://visualizationbackend-production.up.railway.app/predict';

  /// Build the prediction payload from real weather data.
  /// Uses OpenWeatherMap values for both API and local fields.
  /// visitor_count defaults to 50 until a real counting system is connected.
  static Map<String, dynamic> _buildPayload(WeatherData weather) {
    final hour = DateTime.now().hour;
    return {
      'temp_api': weather.temperature,
      'hum_api': weather.humidity,
      'wind_api': weather.windSpeed,
      'rain_api': weather.rainVolume,
      'cloud_api': weather.cloudiness.toDouble(),
      'temp_local': weather.temperature,
      'hum_local': weather.humidity,
      'wind_local': weather.windSpeed,
      'rain_local': weather.rainVolume,
      'visitor_count': 50,
      'hour': hour,
    };
  }

  /// Fetch risk predictions from the hosted ML model backend.
  Future<RiskPrediction?> predict(WeatherData weather) async {
    try {
      final payload = _buildPayload(weather);
      debugPrint('Risk Prediction Payload: $payload');

      final response = await http.post(
        Uri.parse(_predictUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final prediction = RiskPrediction.fromJson(data);
        debugPrint('Risk Prediction Result: $prediction');
        return prediction;
      } else {
        debugPrint(
          'Failed to fetch risk prediction: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching risk prediction: $e');
      return null;
    }
  }
}
