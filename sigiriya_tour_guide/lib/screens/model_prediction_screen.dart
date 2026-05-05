import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sigiriya_tour_guide/services/weather_service.dart';

class ModelPredictionScreen extends StatefulWidget {
  const ModelPredictionScreen({super.key});

  @override
  State<ModelPredictionScreen> createState() => _ModelPredictionScreenState();
}

class _ModelPredictionScreenState extends State<ModelPredictionScreen> {
  final WeatherService _weatherService = WeatherService();
  Timer? _refreshTimer;

  WeatherData? _weather;
  _RiskAssessment? _assessment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLiveWeather();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _loadLiveWeather();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLiveWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final weather = await _weatherService.fetchWeather();
    if (!mounted) return;

    if (weather == null) {
      setState(() {
        _loading = false;
        _error =
            'Live weather data is temporarily unavailable. Showing the last available guidance.';
      });
      return;
    }

    setState(() {
      _weather = weather;
      _assessment = _RiskAssessment.fromWeather(weather);
      _loading = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    final assessment = _assessment;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Tourist Risk Guide'),
        backgroundColor: const Color(0xFF0D1A2B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadLiveWeather,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh live weather',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LiveHeroCard(
            weather: weather,
            assessment: assessment,
            loading: _loading,
          ),
          const SizedBox(height: 16),
          if (_error != null) _ErrorBanner(message: _error!),
          if (_error != null) const SizedBox(height: 16),
          if (weather != null) _WeatherDetailsCard(weather: weather),
          if (weather != null) const SizedBox(height: 16),
          _SectionCard(
            title: 'Current visitor guidance',
            subtitle:
                'Separate advice for each risk so tourists can act quickly.',
            child: assessment == null
                ? const _EmptyState()
                : _CurrentGuidanceCard(assessment: assessment),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Risk breakdown',
            subtitle:
                'Fog, slip, and heat are shown as separate user-friendly cards.',
            child: assessment == null
                ? const _EmptyState()
                : Column(
                    children: [
                      _RiskProgressCard(data: assessment.fog),
                      const SizedBox(height: 12),
                      _RiskProgressCard(data: assessment.slip),
                      const SizedBox(height: 12),
                      _RiskProgressCard(data: assessment.heat),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Suggested actions',
            subtitle: 'Simple advice the user can follow right away.',
            child: assessment == null
                ? const _EmptyState()
                : Column(
                    children: [
                      _AdviceCard(
                        title: 'Fog advice',
                        icon: Icons.cloud_outlined,
                        color: assessment.fog.color,
                        advice: assessment.fogAdvice,
                      ),
                      const SizedBox(height: 12),
                      _AdviceCard(
                        title: 'Slip advice',
                        icon: Icons.warning_amber_outlined,
                        color: assessment.slip.color,
                        advice: assessment.slipAdvice,
                      ),
                      const SizedBox(height: 12),
                      _AdviceCard(
                        title: 'Heat advice',
                        icon: Icons.thermostat_outlined,
                        color: assessment.heat.color,
                        advice: assessment.heatAdvice,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Why the model reacts this way',
            subtitle:
                'The trained model uses live weather and visitor-related inputs.',
            child: const Column(
              children: [
                _FeatureSummary(
                  title: 'Weather data',
                  value: 'Live API inputs',
                  description: 'Temperature, humidity, wind, rain, cloud cover',
                ),
                SizedBox(height: 12),
                _FeatureSummary(
                  title: 'Site conditions',
                  value: 'Microclimate effect',
                  description:
                      'Rock area conditions are slightly different from the wider area',
                ),
                SizedBox(height: 12),
                _FeatureSummary(
                  title: 'Visitor load',
                  value: 'Crowd and time',
                  description:
                      'Busy periods and time of day influence comfort and safety',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Best visit window',
            subtitle: 'Use this when deciding when to go up.',
            child: Text(
              assessment?.bestWindow ?? 'Loading live weather data...',
              style: const TextStyle(
                color: Color(0xFFA9B5C7),
                height: 1.6,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveHeroCard extends StatelessWidget {
  final WeatherData? weather;
  final _RiskAssessment? assessment;
  final bool loading;

  const _LiveHeroCard({
    required this.weather,
    required this.assessment,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final overallLabel = assessment?.overallLabel ?? 'Loading';
    final overallScore = assessment?.overallScore ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: overallLabel == 'Low'
              ? [const Color(0xFF112D2A), const Color(0xFF0D1A2B)]
              : overallLabel == 'Moderate'
              ? [const Color(0xFF2D2411), const Color(0xFF0D1A2B)]
              : [const Color(0xFF321818), const Color(0xFF0D1A2B)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sigiriya visitor safety',
            style: TextStyle(
              color: Color(0xFF6EA8FE),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            loading
                ? 'Loading live weather data...'
                : assessment?.summary ?? 'Live weather unavailable',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            assessment?.description ??
                'The dashboard will update automatically once live weather is available.',
            style: const TextStyle(
              color: Color(0xFFA9B5C7),
              height: 1.55,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(label: overallLabel, color: _riskColor(overallLabel)),
              _Chip(
                label: 'Score $overallScore%',
                color: const Color(0xFF6EA8FE),
              ),
              const _Chip(
                label: 'Location: Sigiriya',
                color: Color(0xFF3DDC97),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A2B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFA9B5C7), height: 1.5),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CurrentGuidanceCard extends StatelessWidget {
  final _RiskAssessment assessment;

  const _CurrentGuidanceCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _riskColor(
                assessment.overallLabel,
              ).withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: Text(
              '${assessment.overallScore}%',
              style: TextStyle(
                color: _riskColor(assessment.overallLabel),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  assessment.description,
                  style: const TextStyle(
                    color: Color(0xFFA9B5C7),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskProgressCard extends StatelessWidget {
  final _RiskCardData data;

  const _RiskProgressCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111D2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _Chip(label: data.level, color: data.color),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: data.score / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(data.color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.description,
            style: const TextStyle(color: Color(0xFFA9B5C7), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _WeatherDetailsCard extends StatelessWidget {
  final WeatherData weather;

  const _WeatherDetailsCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Live weather data',
      subtitle: 'Pulled directly from OpenWeatherMap for Sigiriya.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Chip(
            label: '${weather.temperature.toStringAsFixed(1)}°C',
            color: const Color(0xFF6EA8FE),
          ),
          _Chip(
            label: '${weather.humidity.toStringAsFixed(0)}% humidity',
            color: const Color(0xFF3DDC97),
          ),
          _Chip(
            label: '${weather.windSpeed.toStringAsFixed(1)} m/s wind',
            color: const Color(0xFFF4B942),
          ),
          _Chip(
            label: '${weather.rainVolume.toStringAsFixed(1)} mm rain',
            color: const Color(0xFFFF6B6B),
          ),
          _Chip(
            label: '${weather.cloudiness}% cloud',
            color: const Color(0xFF6EA8FE),
          ),
          _Chip(
            label:
                'Visibility ${(weather.visibility / 1000).toStringAsFixed(1)} km',
            color: const Color(0xFF3DDC97),
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String advice;

  const _AdviceCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.advice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  advice,
                  style: const TextStyle(
                    color: Color(0xFFA9B5C7),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureSummary extends StatelessWidget {
  final String title;
  final String value;
  final String description;

  const _FeatureSummary({
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF6EA8FE),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: Color(0xFFA9B5C7), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RiskCardData {
  final String title;
  final String level;
  final int score;
  final Color color;
  final String description;

  const _RiskCardData({
    required this.title,
    required this.level,
    required this.score,
    required this.color,
    required this.description,
  });
}

class _RiskAssessment {
  final String summary;
  final String description;
  final String overallLabel;
  final int overallScore;
  final String bestWindow;
  final _RiskCardData fog;
  final _RiskCardData slip;
  final _RiskCardData heat;
  final String fogAdvice;
  final String slipAdvice;
  final String heatAdvice;

  const _RiskAssessment({
    required this.summary,
    required this.description,
    required this.overallLabel,
    required this.overallScore,
    required this.bestWindow,
    required this.fog,
    required this.slip,
    required this.heat,
    required this.fogAdvice,
    required this.slipAdvice,
    required this.heatAdvice,
  });

  factory _RiskAssessment.fromWeather(WeatherData weather) {
    final fogScore = _clamp(
      (weather.humidity * 0.45) +
          (weather.cloudiness * 0.22) +
          ((5 - weather.windSpeed) * 8) +
          (weather.visibility < 5000 ? 12 : 0) +
          (weather.weatherId == 741 ||
                  weather.weatherId == 701 ||
                  weather.weatherId == 721
              ? 20
              : 0),
    );

    final slipScore = _clamp(
      (weather.rainVolume * 11) +
          (weather.humidity * 0.22) +
          ((4 - weather.windSpeed) * 6) +
          (weather.cloudiness * 0.07),
    );

    final heatScore = _clamp(
      ((weather.temperature - 26) * 6.2) +
          ((weather.humidity - 55) * 0.18) -
          (weather.windSpeed * 3.5),
    );

    final overallScore = [
      fogScore,
      slipScore,
      heatScore,
    ].reduce((a, b) => a > b ? a : b).round();
    final overallLabel = overallScore >= 70
        ? 'High'
        : overallScore >= 40
        ? 'Moderate'
        : 'Low';

    final summary = overallLabel == 'High'
        ? 'High attention needed before continuing the climb'
        : overallLabel == 'Moderate'
        ? 'Some caution is needed for a comfortable visit'
        : 'Good conditions for most visitors';

    final description = overallLabel == 'High'
        ? 'Live weather suggests one or more risks are elevated. Visitors should slow down, rest more often, or choose a safer time.'
        : overallLabel == 'Moderate'
        ? 'The site is usable, but tourists should stay hydrated and watch their footing.'
        : 'The conditions are pleasant and suitable for a normal visit with standard precautions.';

    return _RiskAssessment(
      summary: summary,
      description: description,
      overallLabel: overallLabel,
      overallScore: overallScore,
      bestWindow:
          weather.temperature >= 31 ||
              weather.humidity >= 85 ||
              weather.rainVolume > 0.5
          ? 'Early morning is usually the safest and most comfortable time today.'
          : 'Current conditions are good. Morning or late afternoon will still feel more comfortable than midday.',
      fog: _cardFromScore(
        'Fog risk',
        fogScore,
        weather.humidity,
        weather.cloudiness.toDouble(),
      ),
      slip: _cardFromScore(
        'Slip risk',
        slipScore,
        weather.rainVolume * 10,
        weather.humidity,
      ),
      heat: _cardFromScore(
        'Heat stress',
        heatScore,
        weather.temperature,
        weather.humidity,
      ),
      fogAdvice: fogScore >= 70
          ? 'Fog is a real concern. Stay close to others and be careful on steps where visibility drops.'
          : fogScore >= 40
          ? 'Fog may appear in some sections. Move carefully and look ahead before each step.'
          : 'Fog is unlikely now. Keep going, but stay aware of changing conditions.',
      slipAdvice: slipScore >= 70
          ? 'Wet surfaces are likely. Use handrails, wear good shoes, and slow down on stone steps.'
          : slipScore >= 40
          ? 'A few slippery areas may exist. Walk carefully, especially on steep or shaded sections.'
          : 'Paths are fairly safe. Normal walking care is enough right now.',
      heatAdvice: heatScore >= 70
          ? 'Heat stress is high. Drink water, rest in shade, and avoid rushing the climb.'
          : heatScore >= 40
          ? 'Heat is starting to build. Keep water with you and take short breaks.'
          : 'Heat is comfortable at the moment. Basic hydration is enough.',
    );
  }

  static _RiskCardData _cardFromScore(
    String title,
    double score,
    double first,
    double second,
  ) {
    final normalized = score.round().clamp(0, 100);
    final level = normalized >= 70
        ? 'High'
        : normalized >= 40
        ? 'Medium'
        : 'Low';
    final color = level == 'High'
        ? const Color(0xFFFF6B6B)
        : level == 'Medium'
        ? const Color(0xFFF4B942)
        : const Color(0xFF3DDC97);

    return _RiskCardData(
      title: title,
      level: level,
      score: normalized,
      color: color,
      description:
          '$title is influenced by live weather values of ${first.toStringAsFixed(1)} and ${second.toStringAsFixed(0)}.',
    );
  }

  static double _clamp(double value) => value.clamp(0, 100).toDouble();
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF321818),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFFF6B6B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Loading live guidance...',
      style: TextStyle(color: Color(0xFFA9B5C7)),
    );
  }
}

Color _riskColor(String label) {
  switch (label.toLowerCase()) {
    case 'low':
      return const Color(0xFF3DDC97);
    case 'moderate':
      return const Color(0xFFF4B942);
    default:
      return const Color(0xFFFF6B6B);
  }
}
