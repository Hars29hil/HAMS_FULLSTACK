import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../components/hams_card.dart';
import '../../components/hams_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  bool _isLoading = true;
  List<dynamic> _students = [];
  List<dynamic> _floors = [];
  String _searchQuery = '';
  String? _selectedFloorFilter;
  String _assignmentFilter = 'All'; // 'All', 'Assigned', 'Unassigned'
  String _userRole = 'ADMIN';

  @override
  void initState() {
    super.initState();
    _fetchRole();
    _fetchData();
  }

  Future<void> _fetchRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('role') ?? 'ADMIN';
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final studentsRes = await ApiClient().dio.get('/students?_t=$timestamp');
      final floorsRes = await ApiClient().dio.get('/floors');
      
      if (mounted) {
        setState(() {
          _students = studentsRes.data['data'] ?? [];
          _floors = floorsRes.data['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncStudents() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.post('/students/sync');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.data['message'] ?? 'Synced successfully')),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sync: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignFloor(String studentId, String? floorId) async {
    try {
      await ApiClient().dio.put('/students/$studentId/room', data: {
        'floor_id': floorId,
        'room_id': null // Simplified for now
      });
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign floor: $e')),
      );
    }
  }

  Future<void> _assignMobile(String studentId, String mobile) async {
    try {
      final response = await ApiClient().dio.put('/students/$studentId/mobile', data: {
        'assigned_mobile': mobile.isEmpty ? null : mobile,
      });
      
      if (!mounted) return;
      
      final String msg = response.data['message'] ?? 'Mobile number saved successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.green,
        ),
      );
      
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Could not save mobile number.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _deleteStudent(String studentId) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().dio.delete('/students/$studentId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.data['message'] ?? 'Student deleted successfully')),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete student: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showDeleteConfirmation(dynamic student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.red)),
        content: Text('Are you sure you want to permanently delete ${student['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteStudent(student['student_id'].toString());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(dynamic student) {
    String? selectedFloorId = student['floor_id']?.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Floor', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${student['name']}', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: selectedFloorId,
              decoration: const InputDecoration(labelText: 'Select Floor'),
              dropdownColor: AppColors.bgElevated,
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ..._floors.map((f) => DropdownMenuItem(
                  value: f['floor_id'].toString(),
                  child: Text(f['name']),
                )),
              ],
              onChanged: (val) {
                selectedFloorId = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _assignFloor(student['student_id'], selectedFloorId);
            },
            child: const Text('Save Assignment'),
          ),
        ],
      ),
    );
  }

  void _showNewAssignMobileDialog(dynamic student) {
    final TextEditingController mobileController = TextEditingController(text: student['assigned_mobile']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Mobile', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${student['name']}', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 24),
            TextField(
              controller: mobileController,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'Enter 10 digit number',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final newMobile = mobileController.text.trim();
              Navigator.of(ctx).pop();
              _assignMobile(student['student_id'].toString(), newMobile);
            },
            child: const Text('Save Mobile'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _students.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    final filteredStudents = _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      
      final isAssigned = s['floor_id'] != null && s['floor_id'].toString().isNotEmpty;
      bool matchesAssignment = true;
      if (_assignmentFilter == 'Assigned') matchesAssignment = isAssigned;
      if (_assignmentFilter == 'Unassigned') matchesAssignment = !isAssigned;

      bool matchesFloor = true;
      if (_selectedFloorFilter != null && _selectedFloorFilter != 'All') {
        matchesFloor = s['floor_id']?.toString() == _selectedFloorFilter;
      }

      return matchesSearch && matchesAssignment && matchesFloor;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Student Directory', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 8),
                Text(
                  'Manage ${filteredStudents.length} students, assign floors, and sync from central database.',
                  style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
                ),
                const SizedBox(height: 32),
                
                // Filters Row
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search
                    SizedBox(
                      width: 320,
                      child: TextField(
                        style: const TextStyle(color: AppColors.text),
                        decoration: const InputDecoration(
                          hintText: 'Search students by name...',
                          prefixIcon: Icon(LucideIcons.search),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    
                    // Floor Filter
                    if (_userRole != 'LEADER')
                      Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFloorFilter,
                            hint: const Text('All Floors', style: TextStyle(color: AppColors.text)),
                            dropdownColor: AppColors.bgElevated,
                            icon: const Icon(LucideIcons.chevronDown, color: AppColors.textMuted),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Floors')),
                              ..._floors.map((f) => DropdownMenuItem(
                                value: f['floor_id'].toString(),
                                child: Text(f['name']),
                              )),
                            ],
                            onChanged: (val) => setState(() => _selectedFloorFilter = val),
                          ),
                        ),
                      ),
                    
                    // Assignment Filter
                    if (_userRole != 'LEADER')
                      Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _assignmentFilter,
                            dropdownColor: AppColors.bgElevated,
                            icon: const Icon(LucideIcons.chevronDown, color: AppColors.textMuted),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Students')),
                              DropdownMenuItem(value: 'Assigned', child: Text('Assigned Only')),
                              DropdownMenuItem(value: 'Unassigned', child: Text('Unassigned Only')),
                            ],
                            onChanged: (val) => setState(() => _assignmentFilter = val!),
                          ),
                        ),
                      ),
                    
                    const SizedBox(width: 16),
                    
                    // Sync Button
                    HamsButton(
                      label: 'Sync Database',
                      icon: LucideIcons.refreshCw,
                      onPressed: _syncStudents,
                      type: ButtonType.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                final isAssigned = student['floor_id'] != null;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: HamsCard(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 10)],
                          ),
                          child: Center(
                            child: Text(
                              (student['name'] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ),
                        
                        // Details
                        SizedBox(
                          width: 200,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                              const SizedBox(height: 4),
                              Text('Bank Code: ${student['student_code'] ?? 'Unknown'}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                              const SizedBox(height: 4),
                              Text('Mobile: ${student['assigned_mobile'] ?? 'Unassigned'}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAssigned ? AppColors.green.withValues(alpha: 0.1) : AppColors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isAssigned ? AppColors.green.withValues(alpha: 0.3) : AppColors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isAssigned ? LucideIcons.checkCircle2 : LucideIcons.alertCircle, size: 14, color: isAssigned ? AppColors.green : AppColors.amber),
                              const SizedBox(width: 6),
                              Text(
                                isAssigned ? 'Floor ${student['floor_id']}' : 'Unassigned',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isAssigned ? AppColors.green : AppColors.amber),
                              ),
                            ],
                          ),
                        ),
                        
                        // Action Buttons
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showNewAssignMobileDialog(student),
                              icon: const Icon(LucideIcons.phone, size: 16),
                              label: const Text('Assign Mobile'),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            if (_userRole != 'LEADER') ...[
                              TextButton.icon(
                                onPressed: () => _showAssignDialog(student),
                                icon: const Icon(LucideIcons.edit2, size: 16),
                                label: const Text('Assign'),
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.surface,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showDeleteConfirmation(student),
                                icon: const Icon(LucideIcons.trash2, color: AppColors.red),
                                tooltip: 'Delete Student',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.red.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
