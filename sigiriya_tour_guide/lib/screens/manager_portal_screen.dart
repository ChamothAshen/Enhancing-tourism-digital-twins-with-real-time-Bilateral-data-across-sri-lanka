import 'package:flutter/material.dart';
import 'unified_manager_dashboard_screen.dart';
import 'admin_login_screen.dart';

/// Manager Portal Screen
/// Displays unified dashboard combining past analytics and future predictions
/// for manager convenience
class ManagerPortalScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAdminData;
  
  const ManagerPortalScreen({super.key, this.initialAdminData});

  @override
  State<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends State<ManagerPortalScreen> {
  Map<String, dynamic>? _adminData;
  bool _isAdminLoggedIn = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialAdminData != null) {
      _adminData = widget.initialAdminData;
      _isAdminLoggedIn = true;
    }
  }

  Widget _buildLoginPrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Portal'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
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
                  'Manager Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Login required to access manager analytics and predictions',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
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
                  label: const Text('Manager Login'),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If not logged in, show login prompt
    if (!_isAdminLoggedIn) {
      return _buildLoginPrompt();
    }

    // If logged in, show unified dashboard with logout button
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Portal'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              setState(() {
                _adminData = null;
                _isAdminLoggedIn = false;
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
      body: UnifiedManagerDashboard(adminData: _adminData),
    );
  }
}
