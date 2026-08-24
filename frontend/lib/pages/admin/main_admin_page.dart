import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../layouts/admin_layout.dart';
import '../auth/login_page.dart';
import 'dashboard_page.dart';

import 'students_page.dart';
import 'live_attendance_page.dart';

class MainAdminPage extends StatefulWidget {
  const MainAdminPage({super.key});

  @override
  State<MainAdminPage> createState() => _MainAdminPageState();
}

class _MainAdminPageState extends State<MainAdminPage> {
  int _currentIndex = 0;
  String? _role;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _role = prefs.getString('role');
        _isLoading = false;
      });
    }
  }

  List<Widget> get _pages {
    if (_role == 'LEADER') {
      return [
        const StudentsPage(),
        const Center(child: Text('Notifications Page (Coming Soon)')),
      ];
    }
    return [
      const DashboardPage(),
      const StudentsPage(),
      const LiveAttendancePage(),
      const Center(child: Text('Notifications Page (Coming Soon)')),
    ];
  }

  List<String> get _titles {
    if (_role == 'LEADER') {
      return [
        'Student Management',
        'Notifications',
      ];
    }
    return [
      'Dashboard',
      'Student Management',
      'Live Attendance',
      'Notifications',
    ];
  }

  List<IconData> get _icons {
    if (_role == 'LEADER') {
      return [
        LucideIcons.users,
        LucideIcons.bell,
      ];
    }
    return [
      LucideIcons.layoutDashboard,
      LucideIcons.users,
      LucideIcons.clipboardCheck,
      LucideIcons.bell,
    ];
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentIndex >= _pages.length) {
      _currentIndex = 0;
    }

    return AdminLayout(
      title: _titles[_currentIndex],
      currentIndex: _currentIndex,
      menuLabels: _titles,
      menuIcons: _icons,
      hideSidebar: _role == 'LEADER',
      onNavigate: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      onLogout: _handleLogout,
      child: _pages[_currentIndex],
    );
  }
}
