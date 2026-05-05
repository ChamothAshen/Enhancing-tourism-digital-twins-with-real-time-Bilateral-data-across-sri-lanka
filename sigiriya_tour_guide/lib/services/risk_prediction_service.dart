import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sigiriya_tour_guide/services/weather_service.dart';

class RiskPrediction {
  final bool fogRisk;
  final bool slipRisk;
  final bool heatStress;
  final Map<String, dynamic> raw;

  const RiskPrediction({
    required this.fogRisk,
    required this.slipRisk,
    required this.heatStress,
    this.raw = const {},
  });

  factory RiskPrediction.fromJson(Map<String, dynamic> json) {
    return RiskPrediction(
      fogRisk: _asBool(json['fog_risk']),
      slipRisk: _asBool(json['slip_risk']),
      heatStress: _asBool(json['heat_stress']),
      raw: json,
    );
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  @override
  String toString() =>
      'RiskPrediction(fog=$fogRisk, slip=$slipRisk, heat=$heatStress)';
}

class RiskPredictionService {
  static const String defaultPredictUrl =
      'https://visualizationbackend-production.up.railway.app/predict';

  static String get predictUrl {
    final envUrl = dotenv.env['ML_RISK_PREDICT_URL']?.trim();
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    return defaultPredictUrl;
  }

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
    return predictWithPayload(_buildPayload(weather));
  }

  /// Fetch risk predictions using an explicit feature payload.
  Future<RiskPrediction?> predictWithPayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      debugPrint('Risk Prediction Payload: $payload');

      final response = await postPayload(payload);

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

  /// Low-level call used by the dedicated model screen so it can show
  /// backend status codes and error bodies.
  Future<http.Response> postPayload(
    Map<String, dynamic> payload, {
    String? endpoint,
  }) {
    return http
        .post(
          Uri.parse(endpoint ?? predictUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 20));
  }
}
