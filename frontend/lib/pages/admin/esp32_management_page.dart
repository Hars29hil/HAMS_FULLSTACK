import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../components/hams_card.dart';
import '../../components/hams_button.dart';

class Esp32ManagementPage extends StatefulWidget {
  const Esp32ManagementPage({super.key});

  @override
  State<Esp32ManagementPage> createState() => _Esp32ManagementPageState();
}

class _Esp32ManagementPageState extends State<Esp32ManagementPage> {
  bool _isLoading = false;
  List<dynamic> _floors = [];
  
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _fetchStatus();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results.where((r) => 
          r.device.platformName.startsWith('ESP') || 
          r.device.platformName.startsWith('Hostel')
        ).toList();
      });
    }, onError: (e) {
      debugPrint('Scan Error: $e');
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      setState(() {
        _isScanning = state;
      });
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().dio.get('/admin/esp32/status');
      if (res.data['success']) {
        setState(() {
          _floors = res.data['data'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load status')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start scan: $e')));
    }
  }

  Future<void> _assignDevice(String deviceName, int floorId) async {
    try {
      final res = await ApiClient().dio.post('/admin/esp32/assign', data: {
        'device_name': deviceName,
        'floor_id': floorId,
      });
      if (res.data['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ESP-32 assigned successfully!')));
        _fetchStatus();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to assign device')));
    }
  }

  Future<void> _unassignDevice(int floorId) async {
    try {
      final res = await ApiClient().dio.post('/admin/esp32/unassign', data: {
        'floor_id': floorId,
      });
      if (res.data['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ESP-32 unassigned successfully!')));
        _fetchStatus();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to unassign device')));
    }
  }

  void _showAssignDialog(String deviceName) {
    showDialog(
      context: context,
      builder: (context) {
        int selectedFloor = 1;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign ESP-32', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device: $deviceName', style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  const Text('Select Floor:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedFloor,
                    dropdownColor: AppColors.bgElevated,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: List.generate(10, (index) => index).map((floor) {
                      return DropdownMenuItem<int>(
                        value: floor,
                        child: Text('Floor F0$floor'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedFloor = val!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _assignDevice(deviceName, selectedFloor);
                  },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ESP-32 Gateway Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
                  SizedBox(height: 8),
                  Text('Assign BLE gateways to floors and monitor their online status.', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                ],
              ),
              HamsButton(
                label: 'Refresh Status',
                icon: LucideIcons.refreshCw,
                onPressed: _fetchStatus,
                type: ButtonType.secondary,
              ),
            ],
          ),
          const SizedBox(height: 48),
          
          // Connected Devices Section
          const Row(
            children: [
              Icon(LucideIcons.server, color: AppColors.accent, size: 24),
              SizedBox(width: 12),
              Text('Assigned Floor Gateways', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: AppColors.accent),
            ))
          else if (_floors.isEmpty)
            HamsCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('No floors configured. Please check the backend.', style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
            )
          else
            HamsCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _floors.length,
                separatorBuilder: (context, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final floor = _floors[index];
                  final isOnline = floor['is_online'] == true;
                  final deviceName = floor['device_name'] ?? 'Not Assigned';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(
                            child: Text(
                              floor['floor_name'].replaceAll('Floor ', ''),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(floor['floor_name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                              const SizedBox(height: 4),
                              Text('Device: $deviceName', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.greenSoft : AppColors.redSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isOnline ? AppColors.green.withValues(alpha: 0.3) : AppColors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline ? AppColors.green : AppColors.red,
                                  boxShadow: [BoxShadow(color: isOnline ? AppColors.green : AppColors.red, blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOnline ? 'ONLINE' : 'OFFLINE',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isOnline ? AppColors.green : AppColors.red),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        
                        // Action
                        if (floor['device_name'] != null)
                          IconButton(
                            icon: const Icon(LucideIcons.unlink, color: AppColors.textMuted),
                            tooltip: 'Unassign Device',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Unassign Device', style: TextStyle(fontWeight: FontWeight.bold)),
                                  content: Text('Are you sure you want to unassign $deviceName from ${floor['floor_name']}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _unassignDevice(floor['floor_id']);
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
                                      child: const Text('Unassign'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        else
                          const SizedBox(width: 48), // Placeholder for alignment
                      ],
                    ),
                  );
                },
              ),
            ),
            
          const SizedBox(height: 64),
          
          // BLE Scanner Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.bluetooth, color: AppColors.accent, size: 24),
                  SizedBox(width: 12),
                  Text('Nearby BLE Devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
                ],
              ),
              HamsButton(
                label: _isScanning ? 'Scanning...' : 'Scan Nearby',
                icon: _isScanning ? LucideIcons.loader : LucideIcons.bluetooth,
                onPressed: _startScan,
                isLoading: _isScanning,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_scanResults.isEmpty)
            HamsCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Column(
                    children: [
                      Icon(LucideIcons.bluetoothSearching, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('No nearby ESP-32 devices found.', style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      const Text('Click "Scan Nearby" to search for broadcasting gateways.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            )
          else
            HamsCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _scanResults.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _scanResults[index];
                  final deviceName = result.device.platformName.isNotEmpty ? result.device.platformName : 'Unknown ESP';
                  // Check if already assigned
                  final isAssigned = _floors.any((f) => f['device_name'] == deviceName);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.cpu, color: AppColors.accent),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(deviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                              const SizedBox(height: 4),
                              Text('MAC: ${result.device.remoteId.str}  •  RSSI: ${result.rssi} dBm', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        if (isAssigned)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Already Assigned', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => _showAssignDialog(deviceName),
                            icon: const Icon(LucideIcons.link, size: 16),
                            label: const Text('Assign'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.bg,
                            ),
                          ),
                      ],
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
