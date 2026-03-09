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
  Map<String, dynamic>? _adminData;
  bool _isAdminLoggedIn = false;
  String _currentView = 'overview'; // overview, forecasting, feedback, visitors

  @override
  void initState() {
    super.initState();
    if (widget.initialAdminData != null) {
      _adminData = widget.initialAdminData;
      _isAdminLoggedIn = true;
      _currentView = 'forecasting'; // Start with forecasting after login
    }
  }

  String get _currentTitle {
    switch (_currentView) {
      case 'forecasting':
        return 'Future Weather & Crowd Forecasting';
      case 'feedback':
        return 'Feedback Sentiment Analysis';
      case 'visitors':
        return 'Visitor Arrival Analysis';
      default:
        return 'Manager Portal';
    }
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'forecasting':
        if (_isAdminLoggedIn && _adminData != null) {
          return AdminDashboard(adminData: _adminData!);
        }
        return _buildLoginRequired('Future Weather & Crowd Forecasting');
      case 'feedback':
        return const FeedbackDashboardScreen();
      case 'visitors':
        return const VisitorArrivalScreen();
      default:
        return _buildOverviewScreen();
    }
  }

  Widget _buildOverviewScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 100,
              color: const Color(0xFF5E6E7C),
            ),
            const SizedBox(height: 32),
            const Text(
              'Welcome to Manager Portal',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Select an option from the menu to view analytics',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildMenuCard(
              icon: Icons.cloud_outlined,
              title: 'Future Weather & Crowd',
              subtitle: 'Forecasting and predictions',
              color: const Color(0xFF5B8A9F),
              onTap: () {
                setState(() => _currentView = 'forecasting');
              },
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              icon: Icons.analytics_outlined,
              title: 'Feedback Sentiment',
              subtitle: 'Review analysis and insights',
              color: const Color(0xFF8B956D),
              onTap: () {
                setState(() => _currentView = 'feedback');
              },
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              icon: Icons.bar_chart_outlined,
              title: 'Visitor Arrivals',
              subtitle: 'Tourist statistics and trends',
              color: const Color(0xFF7D6B91),
              onTap: () {
                setState(() => _currentView = 'visitors');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequired(String feature) {
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
                Icons.lock_outline,
                size: 80,
                color: const Color(0xFF7A8A99),
              ),
              const SizedBox(height: 24),
              Text(
                feature,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Admin login required to access this feature',
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
                  backgroundColor: const Color(0xFF4A5F73),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle),
        backgroundColor: const Color(0xFF3D4E5C),
        foregroundColor: Colors.white,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          if (_isAdminLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () {
                setState(() {
                  _adminData = null;
                  _isAdminLoggedIn = false;
                  _currentView = 'overview';
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3D4E5C),
                    Color(0xFF556B7D),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.dashboard,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Manager Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAdminLoggedIn
                        ? 'Admin: ${_adminData?['name'] ?? 'Manager'}'
                        : 'Analytics Dashboard',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: Color(0xFF5E6E7C)),
              title: const Text('Overview'),
              selected: _currentView == 'overview',
              onTap: () {
                setState(() => _currentView = 'overview');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.cloud_outlined,
                color: _isAdminLoggedIn ? const Color(0xFF5B8A9F) : Colors.grey,
              ),
              title: const Text('Future Weather & Crowd Forecasting'),
              subtitle: _isAdminLoggedIn
                  ? null
                  : const Text(
                      'Admin login required',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
              selected: _currentView == 'forecasting',
              onTap: () {
                setState(() => _currentView = 'forecasting');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: Color(0xFF8B956D)),
              title: const Text('Feedback Sentiment Analysis'),
              selected: _currentView == 'feedback',
              onTap: () {
                setState(() => _currentView = 'feedback');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined, color: Color(0xFF7D6B91)),
              title: const Text('Visitor Arrival Analysis'),
              selected: _currentView == 'visitors',
              onTap: () {
                setState(() => _currentView = 'visitors');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            if (!_isAdminLoggedIn)
              ListTile(
                leading: const Icon(Icons.login, color: Color(0xFF6B7C8A)),
                title: const Text('Admin Login'),
                onTap: () async {
                  Navigator.pop(context);
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
                      _currentView = 'forecasting';
                    });
                  }
                },
              ),
          ],
        ),
      ),
      body: _buildCurrentView(),
    );
  }
}
