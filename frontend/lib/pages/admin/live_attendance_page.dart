import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../components/hams_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveAttendancePage extends StatefulWidget {
  const LiveAttendancePage({super.key});

  @override
  State<LiveAttendancePage> createState() => _LiveAttendancePageState();
}

class _LiveAttendancePageState extends State<LiveAttendancePage> {
  TimeOfDay _startTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 30);
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().dio.get('/attendance/schedule');
      if (res.data['success']) {
        final stStr = res.data['data']['start_time'] as String;
        final etStr = res.data['data']['end_time'] as String;
        setState(() {
          _startTime = TimeOfDay(
            hour: int.parse(stStr.split(':')[0]),
            minute: int.parse(stStr.split(':')[1]),
          );
          _endTime = TimeOfDay(
            hour: int.parse(etStr.split(':')[0]),
            minute: int.parse(etStr.split(':')[1]),
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to load schedule: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    try {
      final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      final endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

      final res = await ApiClient().dio.put('/attendance/schedule', data: {
        'startTime': startStr,
        'endTime': endStr,
      });

      if (res.data['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule saved & activated successfully')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save schedule')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _stopAttendance() async {
    setState(() => _isSaving = true);
    try {
      final now = TimeOfDay.now();
      final nowStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final res = await ApiClient().dio.put('/attendance/schedule', data: {
        'startTime': nowStr,
        'endTime': nowStr, // Sets window to 0 minutes, effectively closing it
      });

      if (res.data['success']) {
        if (!mounted) return;
        setState(() {
          _startTime = now;
          _endTime = now;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance stopped immediately.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to stop attendance')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    
    // Hardcoded url for now, or you could use ApiClient.baseUrl
    final baseUrl = ApiClient().dio.options.baseUrl;
    final url = Uri.parse('$baseUrl/attendance/export?token=$token');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch export link')));
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              surface: AppColors.bgElevated,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  /// Returns true if the current time is within the start/end window.
  bool _isAttendanceCurrentlyOpen() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    // Handle case where start == end (attendance stopped)
    if (startMinutes == endMinutes) return false;

    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  Widget _buildStatusBadge() {
    final isOpen = _isAttendanceCurrentlyOpen();
    final color = isOpen ? AppColors.green : AppColors.red;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpen ? Icons.check_circle : Icons.cancel,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'Attendance is OPEN' : 'Attendance is CLOSED',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                if (isOpen) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Window: ${_formatTime(_startTime)} – ${_formatTime(_endTime)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Attendance Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 12),
          const Text(
            'Set the time window during which students are allowed to mark their attendance. The system will automatically open and close sessions based on this clock.',
            style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 32),
          
          // Live status badge
          _buildStatusBadge(),
          
          const SizedBox(height: 32),
          HamsCard(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.clock, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    const Text('Global Time Window', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePickerField(
                        label: 'Start Time',
                        time: _startTime,
                        onTap: () => _selectTime(context, true),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Icon(LucideIcons.arrowRight, color: AppColors.textMuted),
                    ),
                    Expanded(
                      child: _buildTimePickerField(
                        label: 'End Time',
                        time: _endTime,
                        onTap: () => _selectTime(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                if (_isSaving)
                  const Center(child: CircularProgressIndicator(color: AppColors.accent))
                else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 250, // Ensures it takes at least 250px or wraps
                      child: ElevatedButton.icon(
                        onPressed: _saveSchedule,
                        icon: const Icon(LucideIcons.play),
                        label: const Text('Start Attendance', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: ElevatedButton.icon(
                        onPressed: _stopAttendance,
                        icon: const Icon(LucideIcons.square),
                        label: const Text('Stop Immediately', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _exportAttendance,
                    icon: const Icon(LucideIcons.download),
                    label: const Text('Export Today\'s Attendance (CSV)', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerField({required String label, required TimeOfDay time, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatTime(time),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronDown, color: AppColors.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
