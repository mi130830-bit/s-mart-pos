import 'package:pos_desktop/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/hr/employee_profile.dart';
import '../../../state/hr/employee_provider.dart';
import '../../../models/user.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/firestore_rest_service.dart';

class EmployeeFormDialog extends ConsumerStatefulWidget {
  final EmployeeProfile? employee;

  const EmployeeFormDialog({super.key, this.employee});

  static void show(BuildContext context, {EmployeeProfile? employee}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmployeeFormDialog(employee: employee),
    );
  }

  @override
  ConsumerState<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic info
  int? _userId;
  String? _firebaseUid;
  late TextEditingController _codeCtrl;
  late TextEditingController _displayNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _positionCtrl;
  
  // Settings
  late String _empType;
  late String _wageType;
  late String _payCycle;
  
  // Financials
  late TextEditingController _dailyWageCtrl;
  late TextEditingController _baseSalaryCtrl;
  late TextEditingController _tripRateCtrl;
  
  // Status
  bool _isActive = true;

  List<User> _systemUsers = [];
  List<Map<String, dynamic>> _slinkUsers = [];
  bool _isLoadingUsers = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _userId = emp?.userId;
    _firebaseUid = emp?.firebaseUid;
    _codeCtrl = TextEditingController(text: emp?.employeeCode ?? '');
    _displayNameCtrl = TextEditingController(text: emp?.displayName ?? '');
    _phoneCtrl = TextEditingController(text: emp?.phone ?? '');
    _positionCtrl = TextEditingController(text: emp?.position ?? '');
    String empType = emp?.roleType ?? 'REQUESTER';
    if (empType == 'OFFICE') empType = 'REQUESTER';
    if (empType == 'MAID') empType = 'REQUESTER';
    if (!['ADMIN', 'REQUESTER', 'DRIVER', 'GAS_STATION'].contains(empType)) {
      empType = 'REQUESTER';
    }
    _empType = empType;
    
    _wageType = emp?.wageType ?? 'MONTHLY';
    _payCycle = emp?.payCycle ?? 'MONTHLY';
    
    _dailyWageCtrl = TextEditingController(text: emp?.dailyWage.toString() ?? '0');
    _baseSalaryCtrl = TextEditingController(text: emp?.baseSalary.toString() ?? '0');
    _tripRateCtrl = TextEditingController(text: emp?.tripRate.toString() ?? '0');
    
    _isActive = emp?.isActive ?? true;
    
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final repo = UserRepository();
      final users = await repo.getAllUsers();
      
      List<Map<String, dynamic>> slinkUsers = [];
      try {
        slinkUsers = await FirestoreRestService.fetchSLinkUsers();
      } catch (e) {
        debugPrint('Error fetching S-Link users: $e');
      }

      if (mounted) {
        setState(() {
          _systemUsers = users;
          _slinkUsers = slinkUsers;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _displayNameCtrl.dispose();
    _phoneCtrl.dispose();
    _positionCtrl.dispose();
    _dailyWageCtrl.dispose();
    _baseSalaryCtrl.dispose();
    _tripRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final newEmp = EmployeeProfile(
        id: widget.employee?.id ?? 0,
        userId: _userId,
        firebaseUid: _firebaseUid,
        employeeCode: _codeCtrl.text,
        displayName: _displayNameCtrl.text,
        phone: _phoneCtrl.text,
        position: _positionCtrl.text,
        roleType: _empType,
        wageType: _wageType,
        payCycle: _payCycle,
        dailyWage: double.tryParse(_dailyWageCtrl.text) ?? 0,
        baseSalary: double.tryParse(_baseSalaryCtrl.text) ?? 0,
        tripRate: double.tryParse(_tripRateCtrl.text) ?? 0,
        isActive: _isActive,
      );

      if (widget.employee == null) {
        await ref.read(employeeProvider.notifier).create(newEmp);
      } else {
        await ref.read(employeeProvider.notifier).updateEmployee(newEmp);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showLeft(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.employee == null ? 'เพิ่มพนักงานใหม่' : 'แก้ไขข้อมูลพนักงาน'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // User selection dropdown (Combines POS Local Users and S-Link Cloud Users)
                _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : Builder(
                        builder: (context) {
                          String? validVal = _firebaseUid ?? _userId?.toString();
                          bool exists = _slinkUsers.any((u) => u['id'].toString() == validVal) ||
                              _systemUsers.any((u) => u.id.toString() == validVal);
                          if (!exists) validVal = null;

                          return DropdownButtonFormField<String>(
                            initialValue: validVal,
                            decoration: const InputDecoration(labelText: 'เชื่อมโยงบัญชีผู้ใช้ในระบบ', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem<String>(
                            value: null,
                            child: Text('-- ไม่เชื่อมโยงบัญชี --'),
                          ),
                          ..._slinkUsers.map((u) {
                            return DropdownMenuItem<String>(
                              value: u['id'].toString(), // firebase uid
                              child: Text('📱 ${u['name'] ?? 'ไม่มีชื่อ'}'),
                            );
                          }),
                          ..._systemUsers.map((u) {
                            return DropdownMenuItem<String>(
                              value: u.id.toString(), // local id
                              child: Text('💻 ${u.displayName} (${u.role})'),
                            );
                          }),
                        ],
                        onChanged: (v) {
                          setState(() {
                            if (v == null) {
                              _firebaseUid = null;
                              _userId = null;
                            } else {
                              // Check if it's an S-Link user (UID is usually a long string, local ID is numeric)
                              final isNumeric = int.tryParse(v) != null;
                              if (!isNumeric || v.length > 10) {
                                _firebaseUid = v;
                                _userId = null;
                                final slinkUser = _slinkUsers.firstWhere((u) => u['id'] == v, orElse: () => {});
                                if (slinkUser.isNotEmpty && _displayNameCtrl.text.isEmpty) {
                                  _displayNameCtrl.text = slinkUser['name']?.toString() ?? '';
                                }
                                final slinkRole = (slinkUser['role']?.toString() ?? '').toUpperCase();
                                if (['ADMIN', 'REQUESTER', 'DRIVER', 'GAS_STATION'].contains(slinkRole)) {
                                  _empType = slinkRole;
                                } else {
                                  _empType = 'REQUESTER'; // Fallback for unknown roles
                                }
                              } else {
                                _userId = int.tryParse(v);
                                _firebaseUid = null;
                                final localUser = _systemUsers.firstWhere((u) => u.id == _userId, orElse: () => User(id: 0, username: '', displayName: '', passwordHash: '', role: '', isActive: true, canViewCostPrice: false, canViewProfit: false));
                                if (localUser.id != 0 && _displayNameCtrl.text.isEmpty) {
                                  _displayNameCtrl.text = localUser.displayName.isNotEmpty ? localUser.displayName : localUser.username;
                                }
                                if (localUser.role == 'DRIVER') _empType = 'DRIVER';
                              }
                            }
                          });
                        },
                      );
                    },
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(labelText: 'รหัสพนักงาน', border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: _displayNameCtrl,
                      decoration: const InputDecoration(labelText: 'ชื่อเล่น', border: OutlineInputBorder()),
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'เบอร์โทร', border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: _positionCtrl,
                      decoration: const InputDecoration(labelText: 'ตำแหน่ง', border: OutlineInputBorder()),
                    )),
                  ],
                ),
                const Divider(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _empType,
                        decoration: const InputDecoration(labelText: 'ประเภทพนักงาน', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'ADMIN', child: Text('ผู้ดูแลร้าน')),
                          DropdownMenuItem(value: 'REQUESTER', child: Text('พนักงานหน้าร้านและแม่บ้าน')),
                          DropdownMenuItem(value: 'DRIVER', child: Text('พนักงานหลังร้าน / คนขับรถ')),
                          DropdownMenuItem(value: 'GAS_STATION', child: Text('พนักงานปั๊ม')),
                          DropdownMenuItem(value: 'HR', child: Text('ฝ่ายบุคคล')),
                        ],
                        onChanged: (v) => setState(() => _empType = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _wageType,
                        decoration: const InputDecoration(labelText: 'รูปแบบการจ้าง', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'MONTHLY', child: Text('รายเดือน')),
                          DropdownMenuItem(value: 'DAILY', child: Text('รายวัน')),
                        ],
                        onChanged: (v) => setState(() => _wageType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(
                      controller: _baseSalaryCtrl,
                      decoration: const InputDecoration(labelText: 'เงินเดือน (สำหรับรายเดือน)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: _dailyWageCtrl,
                      decoration: const InputDecoration(labelText: 'ค่าแรงต่อวัน (สำหรับรายวัน)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _payCycle,
                        decoration: const InputDecoration(labelText: 'รอบจ่ายเงิน', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'MONTHLY', child: Text('รายเดือน')),
                          DropdownMenuItem(value: 'WEEKLY', child: Text('รายสัปดาห์')),
                          DropdownMenuItem(value: 'DAILY', child: Text('รายวัน')),
                        ],
                        onChanged: (v) => setState(() => _payCycle = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: _tripRateCtrl,
                      decoration: const InputDecoration(labelText: 'ค่าเที่ยว (บาท/เที่ยว)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('ยังปฏิบัติงานอยู่ (Active)'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v!),
                )
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
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const CircularProgressIndicator() : const Text('บันทึก'),
        ),
      ],
    );
  }
}
