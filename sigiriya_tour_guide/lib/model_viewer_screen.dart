import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'dart:async';
import 'package:sigiriya_tour_guide/services/weather_service.dart';
import 'package:sigiriya_tour_guide/services/risk_prediction_service.dart';

enum TimePreset { day, evening, night }

enum RainIntensity { none, drizzle, heavy }

enum FogIntensity { none, low, medium, high }

class ModelViewerScreen extends StatefulWidget {
  const ModelViewerScreen({super.key});

  @override
  State<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen>
    with TickerProviderStateMixin {
  final Flutter3DController controller = Flutter3DController();
  String srcGlb = 'assets/test.glb';

  RainIntensity rainIntensity = RainIntensity.none;
  FogIntensity fogIntensity = FogIntensity.none;
  int cloudiness = 0;
  TimePreset preset = TimePreset.day;

  double? currentTemp; // Store current temperature

  // Risk prediction state (driven by Railway backend API)
  bool _fogRisk = false;
  bool _slipRisk = false;
  bool _heatStress = false;

  // Antigravity & Weather
  late AnimationController _antigravityController;
  late Animation<double> _antigravityAnimation;
  Timer? _weatherTimer;
  final WeatherService _weatherService = WeatherService();
  final RiskPredictionService _riskService = RiskPredictionService();

  @override
  void initState() {
    super.initState();
    controller.onModelLoaded.addListener(() {
      debugPrint('model is loaded : ${controller.onModelLoaded.value}');
    });
    _setupAntigravity();
    _startWeatherUpdates();
  }

  void _setupAntigravity() {
    _antigravityController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _antigravityAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _antigravityController, curve: Curves.easeInOut),
    );
  }

  void _startWeatherUpdates() {
    _fetchWeather(); // Initial fetch
    _weatherTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _fetchWeather();
    });
  }

  Future<void> _fetchWeather() async {
    final weather = await _weatherService.fetchWeather();
    if (weather == null || !mounted) return;

    setState(() {
      // 1. Weather Logic
      final code = weather.weatherId;

      // Rain Intensity Mapping
      if (code >= 200 && code < 300) {
        rainIntensity = RainIntensity.heavy; // Thunderstorm
      } else if (code >= 502 && code <= 504) {
        rainIntensity = RainIntensity.heavy; // Heavy Rain
      } else if ((code >= 300 && code < 400) || code == 500 || code == 501) {
        rainIntensity = RainIntensity.drizzle; // Drizzle or Light Rain
      } else {
        rainIntensity = RainIntensity.none;
      }

      // Fog Intensity Mapping (Visibility)
      final vis = weather.visibility;
      if (vis < 500) {
        fogIntensity = FogIntensity.high;
      } else if (vis < 2000) {
        fogIntensity = FogIntensity.medium;
      } else if (vis < 5000) {
        fogIntensity = FogIntensity.low;
      } else {
        fogIntensity = FogIntensity.none;
      }

      // Cloudiness
      cloudiness = weather.cloudiness;

      // Update Temperature
      currentTemp = weather.temperature;

      // 2. Time Preset Logic (Sunrise/Sunset)
      final now = DateTime.now();
      final eveningStart = weather.sunset.subtract(const Duration(hours: 3));
      final eveningEnd = weather.sunset.add(const Duration(minutes: 45));

      if (now.isAfter(weather.sunrise) && now.isBefore(eveningStart)) {
        preset = TimePreset.day;
      } else if (now.isAfter(eveningStart) && now.isBefore(eveningEnd)) {
        preset = TimePreset.evening;
      } else {
        preset = TimePreset.night;
      }
    });

    debugPrint(
      'Weather Updated: Rain=$rainIntensity, Fog=$fogIntensity, Clouds=$cloudiness%, Preset=$preset, Temp=$currentTemp',
    );

    // 3. Fetch risk predictions from the hosted ML model using real weather data
    _fetchRiskPrediction(weather);
  }

  Future<void> _fetchRiskPrediction(WeatherData weather) async {
    final prediction = await _riskService.predict(weather);
    if (prediction == null || !mounted) return;

    setState(() {
      _fogRisk = prediction.fogRisk;
      _slipRisk = prediction.slipRisk;
      _heatStress = prediction.heatStress;
    });

    debugPrint(
      'Risk Alerts Updated: Fog=$_fogRisk, Slip=$_slipRisk, Heat=$_heatStress',
    );
  }

  @override
  void dispose() {
    _antigravityController.dispose();
    _weatherTimer?.cancel();
    super.dispose();
  }

  BoxDecoration _backgroundForPreset() {
    // Realistic sky colors — linear gradient from top to bottom like a real sky
    List<Color> skyColors;
    List<double> stops;

    switch (preset) {
      case TimePreset.day:
        // Bright tropical sky: deep sky blue at top → lighter blue → warm horizon glow
        skyColors = [
          const Color(0xFF1E88E5), // Deep sky blue (zenith)
          const Color(0xFF42A5F5), // Medium sky blue
          const Color(0xFF90CAF9), // Light sky blue
          const Color(0xFFE1F0FA), // Pale horizon blue
          const Color(0xFFFFF8E1), // Warm sunlit horizon
        ];
        stops = [0.0, 0.25, 0.5, 0.75, 1.0];
        break;
      case TimePreset.evening:
        // Golden hour sunset: deep blue → purple → warm orange → golden horizon
        skyColors = [
          const Color(0xFF1A237E), // Deep indigo (upper sky)
          const Color(0xFF5C3D8F), // Purple twilight
          const Color(0xFFE65100), // Deep orange
          const Color(0xFFFF8F00), // Amber glow
          const Color(0xFFFFCC02), // Golden horizon
        ];
        stops = [0.0, 0.3, 0.6, 0.8, 1.0];
        break;
      case TimePreset.night:
        // Night sky: very dark blue top → dark indigo → deep navy horizon
        skyColors = [
          const Color(0xFF050A14), // Near-black sky
          const Color(0xFF0D1B2A), // Very dark blue
          const Color(0xFF1B2838), // Dark navy
          const Color(0xFF1E3A5F), // Deep horizon blue
        ];
        stops = [0.0, 0.35, 0.7, 1.0];
        break;
    }

    // Adjust for cloudiness — subtle shift, NOT a harsh grey takeover
    // Only noticeably affects sky above 60% cloudiness
    if (cloudiness > 30 && preset == TimePreset.day) {
      final factor = ((cloudiness - 30) / 70.0).clamp(0.0, 1.0); // 0.0 to 1.0
      // Overcast sky: desaturate blues toward soft grey-blue, keep it bright
      final overcastTop = const Color(0xFF78909C); // Blue-grey (not dark!)
      final overcastMid = const Color(0xFF90A4AE); // Lighter blue-grey
      final overcastLow = const Color(0xFFB0BEC5); // Pale grey-blue
      final overcastHorizon = const Color(0xFFCFD8DC); // Very light grey

      skyColors = [
        Color.lerp(skyColors[0], overcastTop, factor * 0.6)!,
        Color.lerp(skyColors[1], overcastMid, factor * 0.5)!,
        Color.lerp(skyColors[2], overcastLow, factor * 0.45)!,
        Color.lerp(skyColors[3], overcastHorizon, factor * 0.4)!,
        Color.lerp(skyColors[4], const Color(0xFFE0E0E0), factor * 0.35)!,
      ];
    } else if (cloudiness > 50 && preset == TimePreset.evening) {
      final factor = ((cloudiness - 50) / 50.0).clamp(0.0, 1.0);
      // Muted sunset — less vibrant, more grey-purple
      skyColors = [
        Color.lerp(skyColors[0], const Color(0xFF263238), factor * 0.4)!,
        Color.lerp(skyColors[1], const Color(0xFF455A64), factor * 0.35)!,
        Color.lerp(skyColors[2], const Color(0xFF795548), factor * 0.3)!,
        Color.lerp(skyColors[3], const Color(0xFFBCAAA4), factor * 0.25)!,
        Color.lerp(skyColors[4], const Color(0xFFD7CCC8), factor * 0.2)!,
      ];
    }

    // If it's raining, darken the sky slightly for realism
    if (rainIntensity == RainIntensity.heavy) {
      skyColors = skyColors.map((c) {
        final hsl = HSLColor.fromColor(c);
        return hsl
            .withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0))
            .withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0))
            .toColor();
      }).toList();
    } else if (rainIntensity == RainIntensity.drizzle) {
      skyColors = skyColors.map((c) {
        final hsl = HSLColor.fromColor(c);
        return hsl
            .withLightness((hsl.lightness * 0.85).clamp(0.0, 1.0))
            .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
            .toColor();
      }).toList();
    }

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: skyColors,
        stops: stops,
      ),
    );
  }

  double _nightTintOpacity() {
    switch (preset) {
      case TimePreset.day:
        return 0.0;
      case TimePreset.evening:
        return 0.18;
      case TimePreset.night:
        return 0.35;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _backgroundForPreset(),
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // 3D Model with Antigravity (Bottom of stack, but gestures pass through effects)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _antigravityAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _antigravityAnimation.value),
                    child: Flutter3DViewer(
                      activeGestureInterceptor: true,
                      progressBarColor: Colors.orange,
                      enableTouch: true,
                      onProgress: (p) =>
                          debugPrint('model loading progress : $p'),
                      onLoad: (modelAddress) {
                        debugPrint('model loaded : $modelAddress');
                        controller.setCameraOrbit(-85, 50, 5);
                        controller.playAnimation();
                      },
                      onError: (e) => debugPrint('model failed to load : $e'),
                      controller: controller,
                      src: srcGlb,
                    ),
                  );
                },
              ),
            ),

            // Night/Evening tint overlay (Must be IgnorePointer)
            IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _nightTintOpacity(),
                child: Container(color: Colors.black),
              ),
            ),

            // Fog overlay (blur + haze)
            IgnorePointer(
              ignoring: true,
              child: FogOverlay(intensity: fogIntensity),
            ),

            // Cloudiness haze overlay — very subtle, only for very overcast skies
            if (cloudiness > 70)
              IgnorePointer(
                ignoring: true,
                child: Opacity(
                  opacity: ((cloudiness - 70) / 30.0 * 0.12).clamp(0.0, 0.12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blueGrey.withOpacity(0.15),
                          Colors.blueGrey.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Rain overlay (particles)
            IgnorePointer(
              ignoring: true,
              child: RainOverlay(intensity: rainIntensity),
            ),

            // Weather & Temperature Display (Top Left)
            Positioned(
              top: 60,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Temperature
                    Row(
                      children: [
                        const Icon(
                          Icons.thermostat,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentTemp != null
                              ? '${currentTemp!.toStringAsFixed(1)}°C'
                              : '--°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Weather Status
                    Row(
                      children: [
                        if (rainIntensity != RainIntensity.none) ...[
                          Icon(
                            Icons.water_drop,
                            color: rainIntensity == RainIntensity.heavy
                                ? Colors.blue[900]
                                : Colors.blueAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rainIntensity == RainIntensity.heavy
                                ? 'Heavy Rain'
                                : 'Drizzle',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (fogIntensity != FogIntensity.none) ...[
                          const Icon(Icons.cloud, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${fogIntensity.name.toUpperCase()} Fog',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (cloudiness > 10) ...[
                          const Icon(
                            Icons.wb_cloudy,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$cloudiness% Cloudy',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ] else if (rainIntensity == RainIntensity.none &&
                            fogIntensity == FogIntensity.none) ...[
                          const Text(
                            'Clear',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // === Risk Alert Cards (Top Right) ===
            // Driven by the hosted ML model predictions via Railway backend
            Positioned(
              top: 60,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_fogRisk)
                    _buildRiskAlertCard(
                      icon: '🌫️',
                      title: 'High Fog Risk',
                      message:
                          'Visibility may be significantly reduced. Proceed with caution.',
                      color: const Color(0xFF78909C),
                    ),
                  if (_slipRisk)
                    _buildRiskAlertCard(
                      icon: '⚠️',
                      title: 'High Slip Risk',
                      message:
                          'Paths may be slippery or wet. Watch your step carefully.',
                      color: const Color(0xFFFF9800),
                    ),
                  if (_heatStress)
                    _buildRiskAlertCard(
                      icon: '🥵',
                      title: 'High Heat Stress',
                      message:
                          'Dangerous heat levels detected. Stay hydrated and seek shade.',
                      color: const Color(0xFFF44336),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskAlertCard({
    required String icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 5)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FogOverlay extends StatelessWidget {
  final FogIntensity intensity;
  const FogOverlay({super.key, required this.intensity});

  double _getSigma() {
    switch (intensity) {
      case FogIntensity.none:
        return 0;
      case FogIntensity.low:
        return 2;
      case FogIntensity.medium:
        return 6;
      case FogIntensity.high:
        return 12;
    }
  }

  double _getOpacity() {
    switch (intensity) {
      case FogIntensity.none:
        return 0;
      case FogIntensity.low:
        return 0.05;
      case FogIntensity.medium:
        return 0.15;
      case FogIntensity.high:
        return 0.35;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (intensity == FogIntensity.none || !context.mounted)
      return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: 1.0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _getSigma(), sigmaY: _getSigma()),
        child: Container(
          color: Colors.white.withOpacity(_getOpacity()), // haze
        ),
      ),
    );
  }
}

class RainOverlay extends StatefulWidget {
  final RainIntensity intensity;
  const RainOverlay({super.key, required this.intensity});

  @override
  State<RainOverlay> createState() => _RainOverlayState();
}

class _RainOverlayState extends State<RainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  late List<_Drop> _drops;

  @override
  void initState() {
    super.initState();
    _createDrops();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Tick duration
    )..repeat();
  }

  void _createDrops() {
    int count = 0;
    double speedMin = 0.02;
    double speedAdd = 0.03;

    if (widget.intensity == RainIntensity.drizzle) {
      count = 100;
      speedMin = 0.015;
      speedAdd = 0.01;
    } else if (widget.intensity == RainIntensity.heavy) {
      count = 450;
      speedMin = 0.035;
      speedAdd = 0.04;
    }

    _drops = List.generate(count, (_) {
      return _Drop(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        len: _rng.nextDouble() * 0.04 + 0.02,
        speed: _rng.nextDouble() * speedAdd + speedMin,
      );
    });
  }

  @override
  void didUpdateWidget(covariant RainOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intensity != widget.intensity) {
      _createDrops();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity == RainIntensity.none) return const SizedBox.shrink();
    return CustomPaint(
      painter: _RainPainter(_drops, widget.intensity, _ctrl, _rng),
      size: Size.infinite,
    );
  }
}

class _Drop {
  double x;
  double y;
  final double len;
  final double speed;

  _Drop({
    required this.x,
    required this.y,
    required this.len,
    required this.speed,
  });
}

class _RainPainter extends CustomPainter {
  final List<_Drop> drops;
  final RainIntensity intensity;
  final Random rng;

  _RainPainter(this.drops, this.intensity, Listenable repaint, this.rng)
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = intensity == RainIntensity.heavy
          ? Colors.blueGrey.withOpacity(0.7)
          : Colors.lightBlueAccent.withOpacity(0.55)
      ..strokeWidth = intensity == RainIntensity.heavy ? 1.8 : 1.0
      ..strokeCap = StrokeCap.round;

    for (final d in drops) {
      // Update drop position directly in painter for efficiency
      d.y += d.speed;
      if (d.y > 1.2) {
        d.y = -0.2;
        d.x = rng.nextDouble();
      }

      final x = d.x * size.width;
      final y1 = d.y * size.height;
      final y2 = y1 + d.len * size.height;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}
