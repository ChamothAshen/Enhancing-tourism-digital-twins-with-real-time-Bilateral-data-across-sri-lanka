import 'package:flutter/material.dart';
import 'package:sigiriya_tour_guide/theme/app_theme.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final List<Map<String, dynamic>> _tourPlan = [
    {
      'name': 'Sigiriya Entrance',
      'duration': '10 min',
      'completed': false,
    },
    {
      'name': 'Bridge over Moat',
      'duration': '5 min',
      'completed': false,
    },
    {
      'name': 'Water Garden',
      'duration': '20 min',
      'completed': false,
    },
    {
      'name': 'Water Fountains',
      'duration': '15 min',
      'completed': false,
    },
    {
      'name': 'Summer Palace',
      'duration': '15 min',
      'completed': false,
    },
    {
      'name': 'Caves with Inscriptions',
      'duration': '20 min',
      'completed': false,
    },
    {
      'name': 'Lion\'s Paw',
      'duration': '25 min',
      'completed': false,
    },
    {
      'name': 'Main Palace',
      'duration': '30 min',
      'completed': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tour Planner'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryGreen, Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.route, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Sigiriya Tour Route',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_tourPlan.length} stops • ~2.5 hours',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Tour stops list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tourPlan.length,
              itemBuilder: (context, index) {
                final stop = _tourPlan[index];
                return _buildTourStopCard(stop, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTourStopCard(Map<String, dynamic> stop, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: stop['completed'] ? AppTheme.primaryGreen : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: stop['completed']
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (index < _tourPlan.length - 1)
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Card content
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  stop['completed'] = !stop['completed'];
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: stop['completed'] ? Colors.grey : Colors.black87,
                              decoration: stop['completed']
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                stop['duration'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      stop['completed']
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: stop['completed']
                          ? AppTheme.primaryGreen
                          : Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
