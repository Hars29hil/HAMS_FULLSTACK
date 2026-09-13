import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';

class AddAttendancePage extends StatefulWidget {
  final VoidCallback onAdded;
  const AddAttendancePage({super.key, required this.onAdded});

  @override
  State<AddAttendancePage> createState() => _AddAttendancePageState();
}

class _AddAttendancePageState extends State<AddAttendancePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedIcon = 'moon';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _icons = [
    {'name': 'moon', 'icon': LucideIcons.moon, 'label': 'Night'},
    {'name': 'sun', 'icon': LucideIcons.sun, 'label': 'Morning'},
    {'name': 'users', 'icon': LucideIcons.users, 'label': 'Group'},
    {'name': 'code', 'icon': LucideIcons.code, 'label': 'Coding'},
    {'name': 'book', 'icon': LucideIcons.book, 'label': 'Study'},
    {'name': 'coffee', 'icon': LucideIcons.coffee, 'label': 'Break'},
    {'name': 'activity', 'icon': LucideIcons.activity, 'label': 'Activity'},
    {'name': 'calendar', 'icon': LucideIcons.calendar, 'label': 'Event'},
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().dio.post('/admin/sessions', data: {
        'session_name': _nameController.text.trim(),
        'icon_name': _selectedIcon,
      });

      if (res.data['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance session added successfully')),
          );
          _nameController.clear();
          widget.onAdded();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Attendance Session',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Session Label (e.g., Coding)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a session label';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Icon',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _icons.map((iconMap) {
                  final isSelected = _selectedIcon == iconMap['name'];
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = iconMap['name']),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            iconMap['icon'],
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            iconMap['label'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Add Session',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
