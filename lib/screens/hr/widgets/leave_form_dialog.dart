import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/hr/employee_profile.dart';
import '../../../models/hr/leave_request.dart';
import '../../../state/hr/employee_provider.dart';
import '../../../state/hr/leave_provider.dart';

class LeaveFormDialog extends ConsumerStatefulWidget {
  const LeaveFormDialog({super.key});

  @override
  ConsumerState<LeaveFormDialog> createState() => _LeaveFormDialogState();
}

class _LeaveFormDialogState extends ConsumerState<LeaveFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  EmployeeProfile? _selectedEmployee;
  String _leaveType = 'PERSONAL'; // SICK, PERSONAL, VACATION, MATERNITY, OTHER
  String _leaveFormat = 'FULL_DAY'; // FULL_DAY, HALF_MORNING, HALF_AFTERNOON, HOURLY
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  
  double _totalDays = 1.0;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _calculateTotalDays() {
    if (_leaveFormat == 'FULL_DAY') {
      final diff = _endDate.difference(_startDate).inDays;
      _totalDays = (diff >= 0 ? diff + 1 : 1).toDouble();
    } else if (_leaveFormat == 'HALF_MORNING' || _leaveFormat == 'HALF_AFTERNOON') {
      _totalDays = 0.5;
    } else if (_leaveFormat == 'HOURLY') {
      final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
      final end = DateTime(_startDate.year, _startDate.month, _startDate.day, _endTime.hour, _endTime.minute);
      final diffHours = end.difference(start).inMinutes / 60.0;
      _totalDays = double.parse((diffHours / 8.0).toStringAsFixed(2)); // Assuming 8 hours per day
      if (_totalDays < 0) _totalDays = 0;
    }
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_leaveFormat != 'FULL_DAY' || _endDate.isBefore(_startDate)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = picked;
          }
        }
      });
      _calculateTotalDays();
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      initialEntryMode: TimePickerEntryMode.input,
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      _calculateTotalDays();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null) {
      final screenWidth = MediaQuery.of(context).size.width;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณาเลือกพนักงาน'), 
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(left: 16, bottom: 16, right: screenWidth > 350 ? screenWidth - 332 : 16),
        ),
      );
      return;
    }
    if (_totalDays <= 0) {
      final screenWidth = MediaQuery.of(context).size.width;
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('จำนวนวันลาไม่ถูกต้อง'), 
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(left: 16, bottom: 16, right: screenWidth > 350 ? screenWidth - 332 : 16),
        ),
      );
      return;
    }

    final start = DateTime(
      _startDate.year, _startDate.month, _startDate.day, 
      _leaveFormat == 'HOURLY' ? _startTime.hour : 0, 
      _leaveFormat == 'HOURLY' ? _startTime.minute : 0
    );
    
    final end = DateTime(
      _leaveFormat == 'FULL_DAY' ? _endDate.year : _startDate.year,
      _leaveFormat == 'FULL_DAY' ? _endDate.month : _startDate.month,
      _leaveFormat == 'FULL_DAY' ? _endDate.day : _startDate.day,
      _leaveFormat == 'HOURLY' ? _endTime.hour : 23,
      _leaveFormat == 'HOURLY' ? _endTime.minute : 59
    );

    final request = LeaveRequest(
      id: 0,
      employeeId: _selectedEmployee!.id,
      leaveType: _leaveType,
      leaveFormat: _leaveFormat,
      startDate: start,
      endDate: end,
      totalDays: _totalDays,
      reason: _reasonController.text.trim(),
      status: 'PENDING',
    );

    try {
      await ref.read(leaveProvider.notifier).create(request);
      if (mounted) {
        Navigator.pop(context, true);
        final screenWidth = MediaQuery.of(context).size.width;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('บันทึกใบลาสำเร็จ'), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(left: 16, bottom: 16, right: screenWidth > 350 ? screenWidth - 332 : 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(left: 16, bottom: 16, right: screenWidth > 350 ? screenWidth - 332 : 16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final empState = ref.watch(employeeProvider);
    final employees = empState.employees.where((e) => e.isActive).toList();
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      title: const Text('➕ สร้างใบลา (Leave Request)'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Selection
                DropdownButtonFormField<EmployeeProfile>(
                  decoration: const InputDecoration(
                    labelText: 'พนักงาน',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  initialValue: _selectedEmployee,
                  items: employees.map((e) {
                    return DropdownMenuItem(
                      value: e,
                      child: Text('${e.employeeCode ?? ''} - ${e.displayName ?? 'ไม่ระบุชื่อ'}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedEmployee = val);
                  },
                  validator: (val) => val == null ? 'กรุณาเลือกพนักงาน' : null,
                ),
                const SizedBox(height: 16),

                // Leave Type
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'ประเภทการลา',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _leaveType,
                  items: const [
                    DropdownMenuItem(value: 'PERSONAL', child: Text('ลากิจ (Personal Leave)')),
                    DropdownMenuItem(value: 'SICK', child: Text('ลาป่วย (Sick Leave)')),
                    DropdownMenuItem(value: 'VACATION', child: Text('ลาพักร้อน (Vacation)')),
                    DropdownMenuItem(value: 'MATERNITY', child: Text('ลาคลอด (Maternity)')),
                    DropdownMenuItem(value: 'OTHER', child: Text('อื่นๆ (Other)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _leaveType = val);
                  },
                ),
                const SizedBox(height: 16),

                // Leave Format
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'รูปแบบการลา',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _leaveFormat,
                  items: const [
                    DropdownMenuItem(value: 'FULL_DAY', child: Text('ลาเต็มวัน (Full Day)')),
                    DropdownMenuItem(value: 'HALF_MORNING', child: Text('ลาครึ่งวันเช้า (Morning)')),
                    DropdownMenuItem(value: 'HALF_AFTERNOON', child: Text('ลาครึ่งวันบ่าย (Afternoon)')),
                    DropdownMenuItem(value: 'HOURLY', child: Text('ลาระบุเวลา (Hourly)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _leaveFormat = val;
                        _endDate = _startDate; // Reset end date for non full-day
                        _calculateTotalDays();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Date Selection
                if (_leaveFormat == 'FULL_DAY')
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'วันที่เริ่มลา', border: OutlineInputBorder()),
                            child: Text(dateFormat.format(_startDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'ถึงวันที่', border: OutlineInputBorder()),
                            child: Text(dateFormat.format(_endDate)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'วันที่ลา', border: OutlineInputBorder()),
                      child: Text(dateFormat.format(_startDate)),
                    ),
                  ),

                const SizedBox(height: 16),
                
                // Time Selection for HOURLY
                if (_leaveFormat == 'HOURLY')
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'ตั้งแต่เวลา', border: OutlineInputBorder()),
                            child: Text(_startTime.format(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, false),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'ถึงเวลา', border: OutlineInputBorder()),
                            child: Text(_endTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (_leaveFormat == 'HOURLY') const SizedBox(height: 16),

                // Summary Days
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text('สรุปจำนวนวันลา: $_totalDays วัน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reason
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'เหตุผลการลา (ถ้ามี)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: const Text('บันทึกใบลา'),
        ),
      ],
    );
  }
}
