import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../components/hams_card.dart';
import '../../components/hams_button.dart';
import 'package:intl/intl.dart';

class RebindRequestsPage extends StatefulWidget {
  const RebindRequestsPage({super.key});

  @override
  State<RebindRequestsPage> createState() => _RebindRequestsPageState();
}

class _RebindRequestsPageState extends State<RebindRequestsPage> {
  String _selectedFloor = 'ALL';
  bool _isLoading = false;
  List<dynamic> _requests = [];
  String? _leaderFloorId;

  final List<String> _floors = ['ALL', 'F00', 'F01', 'F02', 'F03', 'F04', 'F05', 'F06', 'F07', 'F08', 'F09'];

  @override
  void initState() {
    super.initState();
    _loadRoleAndFetch();
  }

  Future<void> _loadRoleAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (role == 'LEADER') {
      _leaderFloorId = prefs.getString('leader_floor_id');
      if (_leaderFloorId != null && _leaderFloorId!.isNotEmpty) {
        setState(() {
          _selectedFloor = _leaderFloorId!;
        });
      }
    }
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.get('/admin/rebind-requests', queryParameters: {
        'floor_id': _selectedFloor,
      });
      if (response.data['success']) {
        setState(() {
          _requests = response.data['data'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load requests')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateCode(int id) async {
    try {
      final response = await ApiClient().dio.post('/admin/rebind-requests/$id/generate-code');
      if (response.data['success']) {
        final code = response.data['data']['code'];
        _showCodeDialog(code);
        _fetchRequests();
      }
    } catch (e) {
      if (!mounted) return;
      final message = (e is DioException) ? e.response?.data['message'] ?? 'Failed to generate code' : 'Error generating code';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.bgElevated.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 40),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent]),
                    ),
                    child: const Icon(LucideIcons.key, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 24),
                  const Text('Rebind Code Generated', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
                  const SizedBox(height: 12),
                  const Text(
                    'Provide this code to the student.\nIt will expire in exactly 10 minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -5),
                      ],
                    ),
                    child: Text(
                      code.split('').join('  '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: HamsButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Filter
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Device Rebind Requests', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 8),
                    const Text('Approve device changes for students by generating temporary secure codes.', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.filter, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFloor,
                        dropdownColor: AppColors.bgElevated,
                        icon: const Icon(LucideIcons.chevronDown, color: AppColors.textMuted),
                        items: _floors.map((floor) {
                          return DropdownMenuItem(value: floor, child: Text(floor == 'ALL' ? 'All Floors' : floor));
                        }).toList(),
                        onChanged: _leaderFloorId != null ? null : (val) {
                          if (val != null) {
                            setState(() => _selectedFloor = val);
                            _fetchRequests();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              HamsButton(
                label: 'Refresh',
                icon: LucideIcons.refreshCw,
                onPressed: _fetchRequests,
                type: ButtonType.secondary,
              ),
            ],
          ),
        ),
        
        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCircle2, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('No pending requests found', style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRequests,
                      color: AppColors.accent,
                      backgroundColor: AppColors.surface,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final req = _requests[index];
                          final date = DateTime.parse(req['created_at']).toLocal();
                          final dateStr = DateFormat('MMM d, yyyy h:mm a').format(date);
                          final isPending = req['status'] == 'PENDING';
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: HamsCard(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: isPending ? AppColors.accentSoft : AppColors.amberSoft,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPending ? LucideIcons.smartphone : LucideIcons.key,
                                      color: isPending ? AppColors.accent : AppColors.amber,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(req['student_name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                                        const SizedBox(height: 4),
                                        Text('ID: ${req['student_id']}  •  Floor: ${req['floor_id']}  •  Requested on: $dateStr', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  if (isPending)
                                    ElevatedButton.icon(
                                      onPressed: () => _generateCode(req['id']),
                                      icon: const Icon(LucideIcons.key, size: 16),
                                      label: const Text('Generate Code'),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.amberSoft,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(LucideIcons.clock, size: 14, color: AppColors.amber),
                                          const SizedBox(width: 8),
                                          const Text('AWAITING STUDENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.amber)),
                                        ],
                                      ),
                                    )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        )
      ],
    );
  }
}
