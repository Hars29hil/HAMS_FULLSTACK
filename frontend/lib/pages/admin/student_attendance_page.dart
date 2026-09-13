import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import 'package:dio/dio.dart';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({super.key});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  bool _isLoading = true;
  List<dynamic> _allStudents = [];
  List<String> _allGroups = [];
  Map<String, dynamic> _reportData = {};
  
  List<String> _allTypes = [];
  List<String> _selectedTypes = [];
  final List<String> _selectedGroups = [];
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Students
      final studentRes = await Dio().get(
        'https://api.avdvvn.org/public/getStudentBasicDetails',
        options: Options(headers: {'x-hsh-auth-token': 'aF92Kx7QmN4Lp8Vz'}),
      );
      
      if (studentRes.data['data'] != null) {
        _allStudents = studentRes.data['data'];
        Set<String> groupSet = {};
        for (var student in _allStudents) {
          if (student['group'] != null && student['group'].toString().isNotEmpty) {
            groupSet.add(student['group'].toString().trim());
          }
        }
        _allGroups = groupSet.toList()..sort();
      }

      // 2. Fetch Sessions
      final sessionRes = await ApiClient().dio.get('/admin/sessions');
      if (sessionRes.data['success']) {
        _allTypes = (sessionRes.data['data'] as List)
            .map((s) => s['session_key'].toString())
            .toList();
        _selectedTypes = List.from(_allTypes);
      }

      // 3. Fetch Reports
      final reportRes = await ApiClient().dio.get('/admin/reports');
      if (reportRes.data['success']) {
        _reportData = reportRes.data;
      }

    } catch (e) {
      debugPrint('Failed to load data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredData() {
    if (_reportData.isEmpty || _reportData['totals'] == null) return [];
    
    List<Map<String, dynamic>> filteredList = [];
    
    // Calculate total possible sessions for selected types
    int totalPossible = 0;
    for (String type in _selectedTypes) {
      totalPossible += (_reportData['totals'][type] as int? ?? 0);
    }
    
    for (var student in _allStudents) {
      String studentGroup = (student['group'] ?? '').toString().trim();
      
      if (_selectedGroups.isNotEmpty && !_selectedGroups.contains(studentGroup)) {
        continue; // Group filter
      }
      
      String bankCodeStr = student['bankCode']?.toString() ?? '';
      
      // Try exact match or match after stripping leading zeros
      var studentRecords = _reportData['studentRecords'] ?? {};
      var record = studentRecords[bankCodeStr];
      if (record == null) {
        // Try stripping leading zeros
        String stripped = bankCodeStr.replaceFirst(RegExp(r'^0+'), '');
        for (String k in studentRecords.keys) {
          if (k.replaceFirst(RegExp(r'^0+'), '') == stripped) {
            record = studentRecords[k];
            break;
          }
        }
      }
      
      int attended = 0;
      if (record != null) {
        for (String type in _selectedTypes) {
          attended += (record[type] as int? ?? 0);
        }
      }
      
      double percentage = totalPossible > 0 ? (attended / totalPossible) * 100 : 0.0;
      
      Map<String, dynamic> breakdown = {};
      for (String type in _selectedTypes) {
        int tAtt = record != null ? (record[type] as int? ?? 0) : 0;
        int tTot = _reportData['totals'][type] as int? ?? 0;
        double tPerc = tTot > 0 ? (tAtt / tTot) * 100 : 0.0;
        breakdown[type] = {
          'attended': tAtt,
          'total': tTot,
          'percentage': tPerc
        };
      }

      String firstName = student['firstName'] ?? '';
      String lastName = student['lastName'] ?? '';
      String fullName = '$firstName $lastName'.trim();
      if (fullName.isEmpty) fullName = 'Unknown';
      
      String roomNumber = student['room']?.toString() ?? 'N/A';

      filteredList.add({
        'bankCode': bankCodeStr,
        'name': fullName,
        'group': studentGroup,
        'room': roomNumber,
        'attended': attended,
        'total': totalPossible,
        'percentage': percentage,
        'breakdown': breakdown,
      });
    }
    
    // Sort by percentage descending
    filteredList.sort((a, b) => b['percentage'].compareTo(a['percentage']));
    return filteredList;
  }

  Future<void> _exportToCsv() async {
    final filtered = _getFilteredData();
    if (filtered.isEmpty) return;
    
    String escapeCsv(dynamic val) {
      String s = val.toString();
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        s = s.replaceAll('"', '""');
        return '"$s"';
      }
      return s;
    }

    StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('Bank Code,Name,Group,Attended,Total,Percentage');
    
    for (var item in filtered) {
      csvBuffer.writeln([
        escapeCsv(item['bankCode']),
        escapeCsv(item['name']),
        escapeCsv(item['group']),
        item['attended'].toString(),
        item['total'].toString(),
        '${item['percentage'].toStringAsFixed(1)}%'
      ].join(','));
    }
    
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/attendance_report.csv';
    final file = File(path);
    await file.writeAsString(csvBuffer.toString());
    
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(path)], text: 'Student Attendance Report');
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  const Text('Session Types:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: _allTypes.map((type) {
                      bool isSelected = _selectedTypes.contains(type);
                      return FilterChip(
                        label: Text(type.toUpperCase()),
                        selected: isSelected,
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              _selectedTypes.add(type);
                            } else {
                              _selectedTypes.remove(type);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  const Text('Groups:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _allGroups.length,
                      itemBuilder: (ctx, i) {
                        String group = _allGroups[i];
                        bool isSelected = _selectedGroups.contains(group);
                        return CheckboxListTile(
                          title: Text(group),
                          value: isSelected,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                _selectedGroups.add(group);
                              } else {
                                _selectedGroups.remove(group);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredData = _getFilteredData();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Student Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.filter, color: AppColors.primary),
                    onPressed: _showFilterModal,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.download, color: AppColors.primary),
                    onPressed: _exportToCsv,
                  ),
                ],
              )
            ],
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            itemCount: filteredData.length,
            itemBuilder: (context, index) {
              final item = filteredData[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  title: Text(item['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item['group']} | ${item['bankCode']} | Room: ${item['room']}'),
                      const SizedBox(height: 4),
                      Text('Attended: ${item['attended']} / ${item['total']}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Text('${item['percentage'].toStringAsFixed(1)}%', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: item['percentage'] >= 75 ? Colors.green : Colors.red,
                    )
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: (item['breakdown'] as Map<String, dynamic>).entries.map((e) {
                          String typeName = e.key.toUpperCase();
                          var data = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(typeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  '${data['attended']} / ${data['total']} (${data['percentage'].toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    color: data['percentage'] >= 75 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
