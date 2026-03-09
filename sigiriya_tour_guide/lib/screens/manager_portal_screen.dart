import 'package:flutter/material.dart';
import 'feedback_dashboard_screen.dart';
import 'visitor_arrival_screen.dart';
import 'admin_dashboard.dart';
import 'admin_login_screen.dart';

class ManagerPortalScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAdminData;

  const ManagerPortalScreen({super.key, this.initialAdminData});

  @override
  State<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends State<ManagerPortalScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _adminData;
  bool _isAdminLoggedIn = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAdminData != null) {
      _adminData = widget.initialAdminData;
      _isAdminLoggedIn = true;
      _selectedIndex = 2; // Start on Admin Dashboard tab
    }
  }

  final List<String> _titles = [
    'Feedback Analytics',
    'Visitor Analytics',
    'Admin Dashboard',
  ];

  List<Widget> get _screens {
    return [
      const FeedbackDashboardScreen(),
      const VisitorArrivalScreen(),
      _isAdminLoggedIn && _adminData != null
          ? AdminDashboard(adminData: _adminData!)
          : _buildAdminLoginPlaceholder(),
    ];
  }

  Widget _buildAdminLoginPlaceholder() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Colors.deepOrange.shade300,
              ),
              const SizedBox(height: 24),
              const Text(
                'Admin Dashboard',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Login required to access admin features',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminLoginScreen(),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      _adminData = result;
                      _isAdminLoggedIn = true;
                    });
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text('Admin Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          if (_isAdminLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () {
                setState(() {
                  _adminData = null;
                  _isAdminLoggedIn = false;
                  if (_selectedIndex == 2) {
                    _selectedIndex = 0;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 8,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Feedback',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Visitors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
