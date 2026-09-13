import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../layouts/admin_layout.dart';
import '../auth/login_page.dart';
import 'dashboard_page.dart';

import 'students_page.dart';
import 'student_attendance_page.dart';
import 'live_attendance_page.dart';
import 'add_attendance_page.dart';
import '../../services/api_client.dart';

class MainAdminPage extends StatefulWidget {
  const MainAdminPage({super.key});

  @override
  State<MainAdminPage> createState() => _MainAdminPageState();
}

class _MainAdminPageState extends State<MainAdminPage> {
  int _currentIndex = 0;
  String? _role;
  bool _isLoading = true;
  List<dynamic> _dynamicSessions = [];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString('role');
    if (_role != 'LEADER') {
      try {
        final res = await ApiClient().dio.get('/admin/sessions');
        if (res.data['success']) {
          _dynamicSessions = res.data['data'];
        }
      } catch (e) {
        debugPrint('Error loading sessions: $e');
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'moon': return LucideIcons.moon;
      case 'sun': return LucideIcons.sun;
      case 'users': return LucideIcons.users;
      case 'code': return LucideIcons.code;
      case 'book': return LucideIcons.book;
      case 'coffee': return LucideIcons.coffee;
      case 'activity': return LucideIcons.activity;
      default: return LucideIcons.calendar;
    }
  }

  List<Widget> get _pages {
    if (_role == 'LEADER') {
      return [
        const StudentsPage(),
        const Center(child: Text('Notifications Page (Coming Soon)')),
      ];
    }
    List<Widget> p = [
      const DashboardPage(),
      const StudentsPage(),
      const StudentAttendancePage(),
    ];
    for (var s in _dynamicSessions) {
      p.add(LiveAttendancePage(sessionType: s['session_key'].toUpperCase()));
    }
    p.addAll([
      AddAttendancePage(onAdded: () {
        setState(() => _isLoading = true);
        _loadRole();
      }),
      const Center(child: Text('Notifications Page (Coming Soon)')),
    ]);
    return p;
  }

  List<String> get _titles {
    if (_role == 'LEADER') {
      return [
        'Student Management',
        'Notifications',
      ];
    }
    List<String> t = [
      'Dashboard',
      'Student Management',
      'Student Attendance',
    ];
    for (var s in _dynamicSessions) {
      t.add(s['session_name']);
    }
    t.addAll([
      '+ Add Attendance',
      'Notifications',
    ]);
    return t;
  }

  List<IconData> get _icons {
    if (_role == 'LEADER') {
      return [
        LucideIcons.users,
        LucideIcons.bell,
      ];
    }
    List<IconData> i = [
      LucideIcons.layoutDashboard,
      LucideIcons.users,
      LucideIcons.barChart,
    ];
    for (var s in _dynamicSessions) {
      i.add(_getIcon(s['icon_name']));
    }
    i.addAll([
      LucideIcons.plusCircle,
      LucideIcons.bell,
    ]);
    return i;
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
