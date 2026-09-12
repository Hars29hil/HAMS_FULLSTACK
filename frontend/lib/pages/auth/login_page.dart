import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/fcm_service.dart';
import '../admin/main_admin_page.dart';
import '../student/student_dashboard_page.dart';
import '../../theme/app_colors.dart';
import '../../components/hams_button.dart';
import '../../components/hams_card.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_number/mobile_number.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _bankCodeController = TextEditingController();
  
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initApp();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _bankCodeController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    await _requestPermissions();
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return false; // Permissions like bluetooth and phone are unsupported on web

    try {
      await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.phone,
    ].request();
    } catch (e) {
      debugPrint("Standard permissions request failed: $e");
    }

    try {
      final hasPermission = await MobileNumber.hasPhonePermission;
      if (!hasPermission) {
        await MobileNumber.requestPhonePermission;
      }
      return await MobileNumber.hasPhonePermission;
    } catch (e) {
      debugPrint("Phone permission request failed.");
      return false;
    }
  }



  Future<void> _login() async {
    String bankCode = _bankCodeController.text.trim();
    if (bankCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Bank Code.')),
      );
      return;
    }
    
    try {
      bankCode = int.parse(bankCode).toString();
    } catch (e) {
      // In case it's not a pure number, leave it as is
    }

    setState(() => _isLoading = true);

    List<String> simNumbers = [];
    try {
      final sims = await MobileNumber.getSimCards;
      if (sims != null) {
        simNumbers = sims
            .where((s) => s.number != null && s.number!.isNotEmpty)
            .map((s) => s.number!)
            .toList();
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get mobile numbers: '${e.message}'.");
    } catch (e) {
      debugPrint("Failed to get mobile numbers: $e");
    }

    try {
      final response = await ApiClient().dio.post('/auth/login', data: {
        'username': bankCode,
        'sim_numbers': simNumbers,
      });

      if (response.data['success']) {
        final data = response.data['data'];
        final token = data['token'];
        final user = data['user'];
        final role = user['role'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('role', role);
        
        if (role == 'STUDENT') {
          await prefs.setString('student_name', user['name'] ?? '');
          await prefs.setInt('student_floor_id', user['floor_id'] ?? 0);
          await prefs.setString('student_room', user['room']?.toString() ?? '');
          await prefs.setString('student_phone', user['phone']?.toString() ?? '');
          await prefs.setString('student_email', user['email']?.toString() ?? '');
        } else if (role == 'LEADER') {
          await prefs.setInt('leader_floor_id', user['floor_id'] ?? 0);
        }

        if (!mounted) return;
        
        if (role == 'STUDENT') {
          FcmService().init();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainAdminPage()),
          );
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data['message'] ?? 'Login failed. Check credentials.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: null,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Glowing Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.accentGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.fingerprint, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        ShaderMask(
                          shaderCallback: (bounds) => AppColors.accentGradient.createShader(bounds),
                          child: const Text(
                            'HAMS',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hostel Attendance Management',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted, letterSpacing: 1),
                        ),
                        const SizedBox(height: 48),
                        
                        // Glass Login Card
                        HamsCard(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Secure SIM Login',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Your identity is automatically verified using your SIM card.',
                                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 28),
                              
                              // Bank Code Field
                              const Text('Bank Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _bankCodeController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.text),
                                decoration: const InputDecoration(
                                  hintText: 'Enter your Bank Code (e.g., 01723)',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              ),
                              const SizedBox(height: 36),
                              
                              // Sign In Button
                              SizedBox(
                                width: double.infinity,
                                child: HamsButton(
                                  label: 'Secure Login',
                                  onPressed: _login,
                                  isLoading: _isLoading,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
