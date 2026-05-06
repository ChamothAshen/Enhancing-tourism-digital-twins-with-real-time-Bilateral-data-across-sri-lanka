import 'package:flutter/material.dart';
import 'admin_dashboard.dart';
import 'admin_login_screen.dart';
import 'reviews_dashboard_screen.dart';

class ManagerPortalScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAdminData;

  const ManagerPortalScreen({super.key, this.initialAdminData});

  @override
  State<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends State<ManagerPortalScreen> {
  Map<String, dynamic>? _adminData;
  bool _isAdminLoggedIn = false;
  String _currentView = 'overview';

  @override
  void initState() {
    super.initState();
    if (widget.initialAdminData != null) {
      _adminData = widget.initialAdminData;
      _isAdminLoggedIn = true;
      _currentView = 'forecasting';
    }
  }

  String get _currentTitle {
    switch (_currentView) {
      case 'forecasting':
        return 'Future Weather & Crowd Forecasting';
      case 'reviews':
        return 'Visitor Review Analysis';
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

      case 'reviews':
        // Admin login required — same as forecasting
        if (_isAdminLoggedIn && _adminData != null) {
          return const ReviewsDashboardScreen();
        }
        return _buildLoginRequired('Visitor Review Analysis');

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
            const Icon(Icons.dashboard_outlined,
                size: 100, color: Color(0xFF5E6E7C)),
            const SizedBox(height: 32),
            const Text(
              'Welcome to Manager Portal',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _isAdminLoggedIn
                  ? 'Select an option from the menu'
                  : 'Admin login required to access all features',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildMenuCard(
              icon: Icons.cloud_outlined,
              title: 'Future Weather & Crowd',
              subtitle: 'Forecasting and predictions',
              color: const Color(0xFF5B8A9F),
              locked: !_isAdminLoggedIn,
              onTap: () => setState(() => _currentView = 'forecasting'),
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              icon: Icons.analytics_outlined,
              title: 'Visitor Review Analysis',
              subtitle: 'AI-powered feedback & action plans',
              color: const Color(0xFF8B4513),
              locked: !_isAdminLoggedIn,
              onTap: () => setState(() => _currentView = 'reviews'),
            ),
            if (!_isAdminLoggedIn) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _doLogin,
                icon: const Icon(Icons.login),
                label: const Text('Admin Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A5F73),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
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
    required bool locked,
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
                  color: color.withOpacity(locked ? 0.05 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: locked ? Colors.grey[400] : color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: locked ? Colors.grey[500] : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 80, color: Color(0xFF7A8A99)),
              const SizedBox(height: 24),
              Text(feature,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Admin login required to access this feature',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _doLogin,
                icon: const Icon(Icons.login),
                label: const Text('Admin Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A5F73),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
    );
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _adminData = result;
        _isAdminLoggedIn = true;
      });
    }
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
            onPressed: () => Scaffold.of(context).openDrawer(),
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
                  colors: [Color(0xFF3D4E5C), Color(0xFF556B7D)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.dashboard, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text('Manager Portal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    _isAdminLoggedIn
                        ? 'Admin: ${_adminData?['name'] ?? 'Manager'}'
                        : '🔒 Login required',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined,
                  color: Color(0xFF5E6E7C)),
              title: const Text('Overview'),
              selected: _currentView == 'overview',
              onTap: () {
                setState(() => _currentView = 'overview');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.cloud_outlined,
                  color: _isAdminLoggedIn
                      ? const Color(0xFF5B8A9F)
                      : Colors.grey),
              title: const Text('Future Weather & Crowd Forecasting'),
              subtitle: !_isAdminLoggedIn
                  ? const Text('Admin login required',
                      style: TextStyle(fontSize: 12, color: Colors.red))
                  : null,
              trailing: !_isAdminLoggedIn
                  ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                  : null,
              selected: _currentView == 'forecasting',
              onTap: () {
                setState(() => _currentView = 'forecasting');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics_outlined,
                  color: _isAdminLoggedIn
                      ? const Color(0xFF8B4513)
                      : Colors.grey),
              title: const Text('Visitor Review Analysis'),
              subtitle: !_isAdminLoggedIn
                  ? const Text('Admin login required',
                      style: TextStyle(fontSize: 12, color: Colors.red))
                  : null,
              trailing: !_isAdminLoggedIn
                  ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                  : null,
              selected: _currentView == 'reviews',
              onTap: () {
                setState(() => _currentView = 'reviews');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            if (!_isAdminLoggedIn)
              ListTile(
                leading:
                    const Icon(Icons.login, color: Color(0xFF6B7C8A)),
                title: const Text('Admin Login'),
                onTap: () async {
                  Navigator.pop(context);
                  await _doLogin();
                },
              ),
          ],
        ),
      ),
      body: _buildCurrentView(),
    );
  }
}