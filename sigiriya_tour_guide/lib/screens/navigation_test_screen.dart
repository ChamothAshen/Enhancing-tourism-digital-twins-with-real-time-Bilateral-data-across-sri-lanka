import 'package:flutter/material.dart';
import '../widgets/navigation_card.dart';
import '../services/navigation_service.dart';

/// A simple test screen to demonstrate the navigation card functionality
class NavigationTestScreen extends StatelessWidget {
  const NavigationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Test'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Navigation Card Examples:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Example 1: Walking to Water Fountains
            NavigationCard(
              message: 'WALKING TO Water Fountains\n\nHead northeast towards the path in 626 m\n\n311 m • ~4 min\nStep 1/6',
              destinationName: 'Water Fountains',
            ),
            
            const SizedBox(height: 16),
            
            // Example 2: Navigate to Lion's Paw  
            NavigationCard(
              message: 'Navigate to Lion\'s Paw to see the famous entrance gate. Walk along the ancient path for about 15 minutes. The lion paws are magnificent stone sculptures.',
              destinationName: 'Lion\'s Paw',
            ),
            
            const SizedBox(height: 16),
            
            // Example 3: Towards Water Garden
            NavigationCard(
              message: 'Head towards the Water Garden area. This beautiful ancient garden features symmetrical pools and fountains that showcase the hydraulic engineering skills of ancient Sri Lankan civilization.',
            ),
            
            const SizedBox(height: 24),
            
            // Test buttons
            const Text(
              'Direct Navigation Tests:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _testNavigation('Water Fountains', context),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Water Fountains'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _testNavigation('Lion\'s Paw', context),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Lion\'s Paw'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _testNavigation('Summit', context),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Summit'),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Test text parsing
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Text Parsing Test:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._getParsingTests().map((test) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            NavigationService.isNavigationMessage(test['text']!)
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: NavigationService.isNavigationMessage(test['text']!)
                                ? Colors.green
                                : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${test['text']!} → ${NavigationService.extractNavigationDestination(test['text']!) ?? 'None'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testNavigation(String destination, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Testing navigation to $destination...')),
    );
    
    final success = await NavigationService.openGoogleMapsNavigation(
      destinationName: destination,
    );
    
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open maps. Check if Google Maps is installed.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  List<Map<String, String>> _getParsingTests() {
    return [
      {'text': 'WALKING TO Water Fountains'},
      {'text': 'Head northeast towards the Water Garden'},
      {'text': 'Navigate to Lion\'s Paw'},
      {'text': 'Go to the Summit'},
      {'text': 'This is just a regular message about history'},
      {'text': 'Head to the ancient Mirror Wall'},
    ];
  }
}