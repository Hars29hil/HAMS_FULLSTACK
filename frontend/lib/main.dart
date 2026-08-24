import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';
import 'theme/app_theme.dart';
import 'pages/auth/login_page.dart';
import 'pages/student/student_dashboard_page.dart';
import 'pages/admin/main_admin_page.dart';

import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
    } else {
      debugPrint("Firebase initialization skipped for Web (options not configured).");
    }
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(const HamsApp());
}

class HamsApp extends StatelessWidget {
  const HamsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAMS - Hostel Attendance',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

/// Checks for an existing login session and routes accordingly.
/// Shows a brief loading indicator while checking SharedPreferences.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    if (!mounted) return;

    Widget destination;

    if (token != null && token.isNotEmpty && role != null) {
      // User has a saved session — go directly to the correct dashboard
      if (role == 'STUDENT') {
        FcmService().init();
        destination = const StudentDashboardPage();
      } else {
        // ADMIN, WARDEN, LEADER all go to MainAdminPage
        destination = const MainAdminPage();
      }
    } else {
      // No saved session — show login
      destination = const LoginPage();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
