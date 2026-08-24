import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../components/hams_card.dart';

class FloorsPage extends StatefulWidget {
  const FloorsPage({super.key});

  @override
  State<FloorsPage> createState() => _FloorsPageState();
}

class _FloorsPageState extends State<FloorsPage> {
  bool _isLoading = true;
  List<dynamic> _floors = [];

  @override
  void initState() {
    super.initState();
    _fetchFloors();
  }

  Future<void> _fetchFloors() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.get('/floors');
      if (response.data['success']) {
        setState(() {
          _floors = response.data['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch floors: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFloor(String floorId, String name) async {
    try {
      final response = await ApiClient().dio.post('/floors', data: {
        'floor_id': floorId,
        'name': name
      });
      if (response.data['success']) {
        _fetchFloors();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add floor: $e')),
      );
    }
  }

  Future<void> _deleteFloor(String floorId) async {
    try {
      final response = await ApiClient().dio.delete('/floors/$floorId');
      if (response.data['success']) {
        _fetchFloors();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete floor: $e')),
      );
    }
  }

  void _showAddFloorDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Floor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: 'Floor ID (e.g. F01)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Floor Name (e.g. 1st Floor Boys)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (idController.text.isNotEmpty && nameController.text.isNotEmpty) {
                Navigator.of(ctx).pop();
                _addFloor(idController.text.trim(), nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _floors.isEmpty
          ? const Center(
              child: Text('No floors configured yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _floors.length,
              itemBuilder: (context, index) {
                final floor = _floors[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: HamsCard(
                    padding: const EdgeInsets.all(16),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.accentSoft,
                        child: Icon(Icons.layers, color: AppColors.accent),
                      ),
                      title: Text(floor['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text('ID: ${floor['floor_id']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteFloor(floor['floor_id']),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFloorDialog,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('Add Floor'),
      ),
    );
  }
}
