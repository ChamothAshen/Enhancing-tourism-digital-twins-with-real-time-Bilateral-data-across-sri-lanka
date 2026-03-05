import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'dart:async';
import 'package:sigiriya_tour_guide/services/weather_service.dart';
import 'package:sigiriya_tour_guide/services/risk_prediction_service.dart';

enum TimePreset { day, evening, night }

enum RainIntensity { none, drizzle, heavy }

enum FogIntensity { none, low, medium, high }

enum SkyCondition { clear, partlyCloudy, overcast, rainy, storm, foggy }

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
  int _weatherCode = 800;
  double _humidity = 0;
  double _rainVolume = 0;
  DateTime? _lastWeatherSync;

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
      _weatherCode = code;
      _humidity = weather.humidity;
      _rainVolume = weather.rainVolume;
      _lastWeatherSync = DateTime.now();

      // Rain Intensity Mapping
      if (code >= 200 && code < 300 || weather.rainVolume >= 4.0) {
        rainIntensity = RainIntensity.heavy; // Thunderstorm
      } else if (code >= 502 && code <= 504 || weather.rainVolume >= 0.2) {
        rainIntensity = RainIntensity.heavy; // Heavy Rain
      } else if ((code >= 300 && code < 400) ||
          code == 500 ||
          code == 501 ||
          weather.rainVolume > 0) {
        rainIntensity = RainIntensity.drizzle; // Drizzle or Light Rain
      } else {
        rainIntensity = RainIntensity.none;
      }

      // Fog Intensity Mapping (Visibility + weather code + humidity)
      // Supports simultaneous rain + fog when both are present in real data.
      if (code == 741) {
        fogIntensity = FogIntensity.high; // Fog
      } else if (code == 701 || code == 721 || code == 743) {
        fogIntensity = FogIntensity.medium; // Mist / haze
      } else {
        final vis = weather.visibility;
        if (vis < 500) {
          fogIntensity = FogIntensity.high;
        } else if (vis < 2000) {
          fogIntensity = FogIntensity.medium;
        } else if (vis < 5000) {
          fogIntensity = FogIntensity.low;
        } else if (weather.humidity >= 92 && weather.cloudiness >= 75) {
          fogIntensity = FogIntensity.low;
        } else {
          fogIntensity = FogIntensity.none;
        }
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
      'Weather Updated: Code=$_weatherCode, Rain=$rainIntensity (${_rainVolume.toStringAsFixed(2)} mm), Fog=$fogIntensity, Clouds=$cloudiness%, Humidity=${_humidity.toStringAsFixed(0)}%, Preset=$preset, Temp=$currentTemp',
    );

    // 3. Fetch risk predictions from the hosted ML model using real weather data
    _fetchRiskPrediction(weather);
  }

  Future<void> _fetchRiskPrediction(WeatherData weather) async {
    final prediction = await _riskService.predict(weather);
    if (prediction == null || !mounted) return;

    setState(() {
      // Cross-validate ML predictions with actual weather conditions
      // to avoid misleading alerts when conditions clearly don't support them.
      _fogRisk =
          prediction.fogRisk &&
          (fogIntensity != FogIntensity.none ||
              _humidity >= 85 ||
              weather.visibility < 5000);
      _slipRisk =
          prediction.slipRisk &&
          (rainIntensity != RainIntensity.none ||
              _rainVolume > 0 ||
              _humidity >= 80);
      _heatStress =
          prediction.heatStress && (currentTemp != null && currentTemp! >= 28);
    });

    debugPrint(
      'Risk Alerts Updated (cross-validated): Fog=$_fogRisk, Slip=$_slipRisk, Heat=$_heatStress',
    );
  }

  @override
  void dispose() {
    _antigravityController.dispose();
    _weatherTimer?.cancel();
    super.dispose();
  }

  BoxDecoration _backgroundForPreset() {
    // Weather-first rendering: select base sky by weather condition, then apply time tint.
    List<Color> skyColors;
    List<double> stops;
    final skyCondition = _resolveSkyCondition();
    final now = DateTime.now();
    final isMorning = now.hour < 12;

    switch (skyCondition) {
      case SkyCondition.storm:
        skyColors = [
          const Color(0xFF263238),
          const Color(0xFF37474F),
          const Color(0xFF455A64),
          const Color(0xFF546E7A),
        ];
        stops = [0.0, 0.35, 0.7, 1.0];
        break;
      case SkyCondition.rainy:
        skyColors = [
          const Color(0xFF455A64),
          const Color(0xFF607D8B),
          const Color(0xFF78909C),
          const Color(0xFFA7B7C2),
        ];
        stops = [0.0, 0.35, 0.7, 1.0];
        break;
      case SkyCondition.foggy:
        skyColors = [
          const Color(0xFFB0BEC5),
          const Color(0xFFCFD8DC),
          const Color(0xFFECEFF1),
          const Color(0xFFF5F7F8),
        ];
        stops = [0.0, 0.35, 0.7, 1.0];
        break;
      case SkyCondition.overcast:
        skyColors = [
          const Color(0xFF78909C),
          const Color(0xFF90A4AE),
          const Color(0xFFB0BEC5),
          const Color(0xFFCFD8DC),
        ];
        stops = [0.0, 0.35, 0.7, 1.0];
        break;
      case SkyCondition.partlyCloudy:
        skyColors = [
          const Color(0xFF4A90D9),
          const Color(0xFF7DB2E8),
          const Color(0xFFB5D0E8),
          const Color(0xFFE5ECF2),
        ];
        stops = [0.0, 0.35, 0.7, 1.0];
        break;
      case SkyCondition.clear:
        skyColors = isMorning
            ? [
                const Color(0xFF1B5DBE),
                const Color(0xFF3B82D6),
                const Color(0xFF7BA9D4),
                const Color(0xFFD4E1F5),
                const Color(0xFFFFF5D9),
              ]
            : [
                const Color(0xFF1E88E5),
                const Color(0xFF42A5F5),
                const Color(0xFF90CAF9),
                const Color(0xFFE1F0FA),
                const Color(0xFFFFF8E1),
              ];
        stops = [0.0, 0.25, 0.5, 0.75, 1.0];
        break;
    }

    // Time tint on top of weather base.
    Color topTint;
    Color horizonTint;
    double tintStrength;
    switch (preset) {
      case TimePreset.day:
        topTint = const Color(0xFFFFFFFF);
        horizonTint = const Color(0xFFFFF3E0);
        tintStrength = 0.06;
        break;
      case TimePreset.evening:
        topTint = const Color(0xFF1A237E);
        horizonTint = const Color(0xFFFF8F00);
        tintStrength = 0.28;
        break;
      case TimePreset.night:
        topTint = const Color(0xFF071428);
        horizonTint = const Color(0xFF0D2240);
        tintStrength = 0.58;
        break;
    }

    skyColors = List<Color>.generate(skyColors.length, (index) {
      final target = index <= (skyColors.length / 2).floor()
          ? topTint
          : horizonTint;
      return Color.lerp(skyColors[index], target, tintStrength)!;
    });

    // Temperature micro-adjust: cooler temperatures shift palette slightly cooler.
    if (currentTemp != null && currentTemp! < 12) {
      final coolFactor = ((12 - currentTemp!) / 12).clamp(0.0, 1.0) * 0.18;
      skyColors = skyColors
          .map((c) => Color.lerp(c, const Color(0xFF90CAF9), coolFactor)!)
          .toList();
    }

    // Night cloudiness: cloudy nights reflect ambient light, creating a subtle glow.
    // Clear nights stay deep blue-black; overcast nights get a muted navy-grey uplift.
    if (preset == TimePreset.night && cloudiness > 20) {
      final cloudGlow = ((cloudiness - 20) / 80.0).clamp(0.0, 1.0) * 0.20;
      const glowColor = Color(0xFF1C2D4A); // Muted blue-grey cloud glow
      skyColors = skyColors
          .map((c) => Color.lerp(c, glowColor, cloudGlow)!)
          .toList();
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

  SkyCondition _resolveSkyCondition() {
    if (rainIntensity == RainIntensity.heavy &&
        (_weatherCode >= 200 && _weatherCode < 300)) {
      return SkyCondition.storm;
    }
    if (fogIntensity == FogIntensity.high ||
        fogIntensity == FogIntensity.medium) {
      return SkyCondition.foggy;
    }
    if (rainIntensity != RainIntensity.none) {
      return SkyCondition.rainy;
    }
    if (cloudiness >= 85) {
      return SkyCondition.overcast;
    }
    if (cloudiness >= 45) {
      return SkyCondition.partlyCloudy;
    }
    return SkyCondition.clear;
  }

  double _nightTintOpacity() {
    switch (preset) {
      case TimePreset.day:
        return 0.0;
      case TimePreset.evening:
        return 0.18;
      case TimePreset.night:
        return 0.30;
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
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF030B18), // Deep dark blue at zenith
                        Color(0xFF081530), // Deep navy mid-sky
                        Color(0xFF0C1E3D), // Rich midnight blue
                        Color(0xFF152D50), // Navy blue at horizon
                      ],
                      stops: [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),
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

            // Live API debug card for demonstrations
            Positioned(
              top: 172,
              left: 20,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE WEATHER CONDITION',
                        style: TextStyle(
                          color: Colors.lightGreenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _debugLine(
                        'Sky',
                        '${_resolveSkyCondition().name} | ${preset.name}',
                      ),
                      _debugLine('Weather code', '$_weatherCode'),
                      _debugLine('Cloudiness', '$cloudiness%'),
                      _debugLine(
                        'Rain (1h)',
                        '${_rainVolume.toStringAsFixed(2)} mm',
                      ),
                      _debugLine('Fog', fogIntensity.name),
                      _debugLine(
                        'Humidity',
                        '${_humidity.toStringAsFixed(0)}%',
                      ),
                      _debugLine(
                        'Updated',
                        _lastWeatherSync == null
                            ? '--'
                            : '${_lastWeatherSync!.hour.toString().padLeft(2, '0')}:${_lastWeatherSync!.minute.toString().padLeft(2, '0')}:${_lastWeatherSync!.second.toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),
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

  Widget _debugLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
        return 1.5; // Subtle blur
      case FogIntensity.medium:
        return 3.0; // Moderate blur
      case FogIntensity.high:
        return 5.0; // Noticeable but not extreme
    }
  }

  double _getOpacity() {
    switch (intensity) {
      case FogIntensity.none:
        return 0;
      case FogIntensity.low:
        return 0.03; // Very light haze
      case FogIntensity.medium:
        return 0.08; // Light haze
      case FogIntensity.high:
        return 0.15; // Visible haze, but model still clear
    }
  }

  @override
  Widget build(BuildContext context) {
    if (intensity == FogIntensity.none || !context.mounted) {
      return const SizedBox.shrink();
    }

    // Instead of BackdropFilter which blocks touches, use a simple opacity + blur effect
    // painted as a layer that doesn't intercept pointer events
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: 1.0,
      child: CustomPaint(
        painter: FogPainter(opacity: _getOpacity(), blurSigma: _getSigma()),
        size: Size.infinite,
      ),
    );
  }
}

/// Custom painter that creates fog effect without blocking touches
class FogPainter extends CustomPainter {
  final double opacity;
  final double blurSigma;

  FogPainter({required this.opacity, required this.blurSigma});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a semi-transparent white layer for fog haze
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(FogPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.blurSigma != blurSigma;
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
