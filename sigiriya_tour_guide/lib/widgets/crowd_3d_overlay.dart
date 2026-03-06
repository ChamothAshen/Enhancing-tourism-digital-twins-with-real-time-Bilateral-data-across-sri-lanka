import 'dart:math';
import 'package:flutter/material.dart';

class Crowd3DOverlay extends StatelessWidget {
  final Map<String, int> crowdData = {
    "lions_paw": 10,
    "water_gardens": 6,
    "mirror_wall": 4,
  };

  Crowd3DOverlay({super.key});

  final Map<String, Offset> zonePositions = {
    "lions_paw": const Offset(0.55, 0.45),
    "water_gardens": const Offset(0.45, 0.65),
    "mirror_wall": const Offset(0.60, 0.55),
  };

  // Distinct colors per zone so you can tell which is which while tuning
  final Map<String, Color> zoneColors = {
    "lions_paw": Colors.red,
    "water_gardens": Colors.cyan,
    "mirror_wall": Colors.amber,
  };

  // Friendly display names for zone labels
  final Map<String, String> zoneLabels = {
    "lions_paw": "Lion's Paw",
    "water_gardens": "Water Gardens",
    "mirror_wall": "Mirror Wall",
  };

  List<Widget> generateDots(Size screenSize) {
    List<Widget> dots = [];
    Random random = Random(42); // Fixed seed so dots don't jump on rebuild

    crowdData.forEach((zone, count) {
      Offset base = zonePositions[zone]!;
      Color color = zoneColors[zone] ?? Colors.red;

      double centerX = base.dx * screenSize.width;
      double centerY = base.dy * screenSize.height;

      // Zone label at the center of each cluster
      dots.add(
        Positioned(
          left: centerX - 40,
          top: centerY - 22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${zoneLabels[zone] ?? zone} ($count)',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );

      // Crosshair at exact centre (helps with position tuning)
      dots.add(
        Positioned(
          left: centerX - 6,
          top: centerY - 6,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
        ),
      );

      // Scatter dots around centre
      for (int i = 0; i < count; i++) {
        double dx = centerX + random.nextDouble() * 30 - 15;
        double dy = centerY + random.nextDouble() * 30 - 15;

        dots.add(
          Positioned(
            left: dx,
            top: dy,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 4),
                ],
              ),
            ),
          ),
        );
      }
    });

    return dots;
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return IgnorePointer(
      child: Stack(
        children: generateDots(screenSize),
      ),
    );
  }
}