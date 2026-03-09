import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sigiriya_tour_guide/screens/map_screen.dart';
import 'package:sigiriya_tour_guide/theme/app_theme.dart';
import 'package:sigiriya_tour_guide/providers/chat_provider.dart';
import 'model_viewer_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/manager_portal_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sigiriya Tour Guide',
        theme: AppTheme.lightTheme,
        home: const MainNavigationScreen(),
        routes: {
          '/manager': (context) => const ManagerPortalScreen(),
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MapScreen(),
    const ModelViewerScreen(),
    const ChatScreen(),
  ];

  final List<String> _titles = [
    'Sigiriya Map Guide',
    '3D Model Viewer',
    'Tour Planner',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/manager');
        },
        icon: const Icon(Icons.manage_accounts),
        label: const Text('Manager'),
        backgroundColor: AppTheme.primaryGreen,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          elevation: 0,
          backgroundColor: Colors.white,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.view_in_ar_outlined),
              activeIcon: Icon(Icons.view_in_ar),
              label: '3D Model',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Guide',
              tooltip: 'Chat with AI guide',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}
