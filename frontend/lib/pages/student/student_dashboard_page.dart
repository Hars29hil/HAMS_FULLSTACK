import 'dart:convert';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../../components/hams_button.dart';

import '../../theme/app_colors.dart';
import '../../components/hams_card.dart';
import '../../components/radar_animation.dart';
import '../../services/api_client.dart';
import '../auth/login_page.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage>
    with SingleTickerProviderStateMixin {
  String _name = '';
  String _room = '';
  String _phone = '';
  String _email = '';
  bool _isMarking = false;

  // Attendance state
  bool _alreadyMarked = false;
  bool _attendanceActive = false;
  String _startTime = '';
  String _endTime = '';
  bool _isLoadingStatus = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _loadStudentDetails();
    _checkAttendanceStatus();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('student_name') ?? 'Unknown Student';
      _room = prefs.getString('student_room') ?? 'Not Assigned';
      _phone = prefs.getString('student_phone') ?? 'N/A';
      _email = prefs.getString('student_email') ?? 'N/A';
    });
  }

  Future<void> _checkAttendanceStatus() async {
    try {
      final response = await ApiClient().dio.get('/attendance/my-status');
      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (mounted) {
          setState(() {
            _alreadyMarked = data['already_marked'] ?? false;
            _attendanceActive = data['attendance_active'] ?? false;
            _startTime = data['start_time'] ?? '';
            _endTime = data['end_time'] ?? '';
            _isLoadingStatus = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStatus = false);
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        // Auto logout if the backend invalidates the session
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final markedDate = prefs.getString('last_attendance_date');
      if (mounted) {
        setState(() {
          _alreadyMarked = markedDate == today;
          _isLoadingStatus = false;
        });
      }
    }
  }

  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('already_marked') ||
        msg.contains('already marked') ||
        msg.contains('student_already_marked')) {
      return 'Your attendance is already marked for today. Come back tomorrow!';
    }
    if (msg.contains('device_already_used')) {
      return 'This device has already been used to mark attendance today.';
    }
    if (msg.contains('no_active_session') ||
        msg.contains('no active') ||
        msg.contains('attendance is closed') ||
        msg.contains('session has ended')) {
      return 'Attendance is not open right now. Please check the schedule and try again during the allowed time.';
    }
    if (msg.contains('session has not started')) {
      return 'Attendance has not started yet. Please wait for the scheduled time.';
    }
    if (msg.contains('bluetooth') ||
        msg.contains('ble') ||
        msg.contains('gatt')) {
      return 'Could not connect to the floor device. Make sure Bluetooth is turned on and you are on your assigned floor.';
    }
    if (msg.contains('permission')) {
      return 'Bluetooth and Location permissions are needed. Please allow them in your phone settings.';
    }
    if (msg.contains('turn on bluetooth') || msg.contains('adapter')) {
      return 'Please turn on Bluetooth to mark your attendance.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Connection timed out. Please move closer to the floor device and try again.';
    }
    if (msg.contains('could not find') || msg.contains('esp32')) {
      return 'Could not find the floor device. Make sure you are on your assigned floor and try again.';
    }
    if (msg.contains('floor')) {
      return 'You are not on your assigned floor. Please go to your floor and try again.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection refused')) {
      return 'Could not connect to the server. Please check your internet connection.';
    }
    if (msg.contains('platform') || msg.contains('platformexception')) {
      return 'Something went wrong with your device. Please restart the app and try again.';
    }

    String cleaned = e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('exception: ', '');
    if (cleaned.contains('(') ||
        cleaned.contains('/') ||
        cleaned.contains('.') && cleaned.length > 80) {
      return 'Something went wrong. Please try again or contact your floor leader for help.';
    }
    return cleaned;
  }

  Future<void> _markAttendance() async {
    if (_alreadyMarked) {
      _showResultDialog(
        title: 'Already Marked',
        message:
            'Your attendance is already marked for today. Come back tomorrow!',
        icon: Icons.info_outline,
        color: AppColors.accent,
      );
      return;
    }

    if (!_attendanceActive && _startTime.isNotEmpty && _endTime.isNotEmpty) {
      _showResultDialog(
        title: 'Not Available',
        message:
            'Attendance is available from $_startTime to $_endTime. Please come back during that time.',
        icon: Icons.schedule,
        color: AppColors.amber,
      );
      return;
    }

    setState(() => _isMarking = true);

    BluetoothDevice? targetDevice;

    try {
      // ── Step 1: Request Permissions ──
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses.values.any(
        (status) => status.isPermanentlyDenied || status.isDenied,
      )) {
        throw Exception(
          'Bluetooth and Location permissions are needed to mark attendance. Please allow them in your phone settings.',
        );
      }

      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        throw Exception('Please turn on Bluetooth to mark your attendance.');
      }

      final targetServiceUuid = fbp.Guid(
        '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
      );
      final targetCharacteristicUuid = fbp.Guid(
        'beb5483e-36e1-4688-b7f5-ea07361b26a8',
      );

      // ── Step 2: Scan for ESP32 BLE Device ──
      int scanRssi = -50; // Default safe RSSI value

      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          final deviceName = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;

          final lowerName = deviceName.toLowerCase();

          // Check if the name matches OR if it's broadcasting our specific Service UUID
          bool nameMatches =
              lowerName.contains('hostel') ||
              lowerName.contains('esp32') ||
              lowerName.contains('floor') ||
              lowerName.contains('attendance');

          bool uuidMatches = r.advertisementData.serviceUuids.contains(
            targetServiceUuid,
          );

          if (nameMatches || uuidMatches) {
            targetDevice = r.device;
            scanRssi =
                r.rssi; // Capture RSSI from scan (more reliable than readRssi)
            FlutterBluePlus.stopScan();
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      await scanSubscription.cancel();

      if (targetDevice == null) {
        throw Exception(
          'Could not find the floor device. Make sure you are on your assigned floor and try again.',
        );
      }

      // ── Step 3: Connect to ESP32 (with Android 133 fix) ──
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 600));
        try {
          await targetDevice!.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 300));
      }

      try {
        await targetDevice!.connect(
          timeout: const Duration(seconds: 10),
          autoConnect: false,
          mtu: null,
          license: fbp.License.nonprofit,
        );
      } catch (e) {
        // Retry once on Android Error 133
        try {
          await targetDevice!.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 1));
        await targetDevice!.connect(
          timeout: const Duration(seconds: 12),
          autoConnect: false,
          mtu: null,
          license: fbp.License.nonprofit,
        );
      }

      // ── Step 4: Read the BLE Token ──
      String bleToken = "";

      try {
        // Give Android time to stabilize the GATT connection
        await Future.delayed(const Duration(milliseconds: 800));

        List<BluetoothService> services = await targetDevice!
            .discoverServices();
        BluetoothCharacteristic? targetCharacteristic;

        for (BluetoothService service in services) {
          if (service.uuid == targetServiceUuid) {
            for (BluetoothCharacteristic c in service.characteristics) {
              if (c.uuid == targetCharacteristicUuid) {
                targetCharacteristic = c;
                break;
              }
            }
          }
        }

        if (targetCharacteristic == null) {
          throw Exception(
            'Could not connect to the floor device properly. Please try again.',
          );
        }

        final tokenBytes = await targetCharacteristic.read();
        bleToken = utf8.decode(tokenBytes).trim();

        // ── Step 5: App-Bridged Architecture Logic ──
        if (bleToken == 'NONE') {
          // The ESP-32 has no token yet! We are the first student.
          // Let's ask the backend for a token and write it to the ESP-32.
          try {
            final reqRes = await ApiClient().dio.post(
              '/attendance/request-token',
              data: {"rssi": scanRssi},
            );

            if (reqRes.data['success'] == true) {
              String generatedToken = reqRes.data['token'];
              int durationMinutes = reqRes.data['duration_minutes'] ?? 120;

              // Tell the ESP-32 its new token and duration!
              String writeCommand = "SET:$generatedToken:$durationMinutes";
              await targetCharacteristic.write(utf8.encode(writeCommand));

              // The backend /request-token endpoint already marked our attendance!
              bleToken = generatedToken; // Update local variable just in case

              // Disconnect and jump to Success
              try {
                await targetDevice!.disconnect();
              } catch (_) {}

              if (mounted) {
                final prefs = await SharedPreferences.getInstance();
                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                await prefs.setString('last_attendance_date', today);

                setState(() {
                  _alreadyMarked = true;
                });

                _showResultDialog(
                  title: 'Success!',
                  message:
                      'Your attendance has been marked!Come tommory again to be consistent',
                  icon: Icons.star,
                  color: AppColors.green,
                );
              }
              return; // We are completely done!
            }
          } on DioException catch (dioErr) {
            final serverMsg = dioErr.response?.data?['message'];
            if (serverMsg != null && serverMsg.toString().isNotEmpty) {
              throw Exception(serverMsg);
            }
            rethrow;
          }
        }
      } finally {
        // Only disconnect here if we haven't already returned early
        try {
          if (targetDevice!.isConnected) {
            await targetDevice!.disconnect();
          }
        } catch (_) {}
      }

      // ── Step 6: Normal Attendance (Token already existed) ──
      try {
        final res = await ApiClient().dio.post(
          '/attendance/mark',
          data: {"ble_token": bleToken, "rssi": scanRssi},
        );

        if (res.data['success'] != true) {
          throw Exception(
            res.data['message'] ?? 'Failed to mark attendance on the server.',
          );
        }
      } on DioException catch (dioErr) {
        // Extract the server's actual error message from the response
        final serverMsg = dioErr.response?.data?['message'];
        if (serverMsg != null && serverMsg.toString().isNotEmpty) {
          throw Exception(serverMsg);
        }
        rethrow;
      }

      // ── Step 7: Success! ──
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await prefs.setString('last_attendance_date', today);

        setState(() {
          _alreadyMarked = true;
        });

        _showResultDialog(
          title: 'Success!',
          message:
              'Your attendance has been marked successfully. Have a great evening!',
          icon: Icons.check_circle_outline,
          color: AppColors.green,
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Make sure we disconnect if something went wrong mid-flow
      try {
        await targetDevice?.disconnect();
      } catch (_) {}
      _showResultDialog(
        title: 'Could Not Mark Attendance',
        message: _friendlyError(e),
        icon: Icons.error_outline,
        color: AppColors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isMarking = false);
      }
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.text,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.green.withValues(alpha: 0.15),
            AppColors.accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.green.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.green,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Attendance Marked!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your attendance has been recorded for today.\nSee you tomorrow!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.green.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleInfo() {
    if (_startTime.isEmpty || _endTime.isEmpty) return const SizedBox.shrink();

    final isOpen = _attendanceActive;
    final statusColor = isOpen ? AppColors.green : AppColors.amber;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOpen ? 'Attendance is OPEN' : 'Attendance is CLOSED',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today\'s window: $_startTime – $_endTime',
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: _checkAttendanceStatus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: null),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      // Profile Section
                      HamsCard(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          children: [
                            // Avatar with glow
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.accent, AppColors.accent],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: AppColors.bg,
                                child: Text(
                                  _name.isNotEmpty
                                      ? _name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome, $_name!',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            _buildInfoRow(
                              Icons.meeting_room_outlined,
                              'ROOM',
                              _room,
                            ),
                            Divider(height: 28, color: AppColors.border),
                            _buildInfoRow(
                              Icons.phone_outlined,
                              'PHONE',
                              _phone,
                            ),
                            Divider(height: 28, color: AppColors.border),
                            _buildInfoRow(
                              Icons.email_outlined,
                              'EMAIL',
                              _email,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Schedule Info
                      if (!_isLoadingStatus) _buildScheduleInfo(),
                      const SizedBox(height: 16),

                      // Attendance Action
                      HamsCard(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          children: [
                            if (_isLoadingStatus)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(
                                  color: AppColors.accent,
                                ),
                              )
                            else if (_alreadyMarked)
                              _buildSuccessBanner()
                            else ...[
                              RadarAnimation(
                                isScanning: _isMarking,
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          AppColors.accent,
                                          AppColors.accent,
                                        ],
                                      ).createShader(bounds),
                                  child: const Icon(
                                    Icons.bluetooth_searching,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Mark Attendance',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _attendanceActive
                                    ? 'Make sure you are on your floor. Bluetooth will connect to the floor device.'
                                    : 'Attendance opens from $_startTime to $_endTime.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: HamsButton(
                                  label: 'Mark My Attendance',
                                  icon: Icons.touch_app,
                                  onPressed: _markAttendance,
                                  isLoading: _isMarking,
                                ),
                              ),
                            ],
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
    );
  }
}
