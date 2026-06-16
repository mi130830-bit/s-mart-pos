import 'package:flutter/material.dart';
import '../../services/integration/fingerprint_network_service.dart';
import '../../services/hr/fingerprint_attendance_service.dart';
import '../../repositories/hr/employee_repository.dart';
import '../../models/hr/employee_profile.dart';

/// หน้าตั้งค่าและจัดการระบบแสกนลายนิ้วมือ
///
/// ระบบลงทะเบียน: 2 นิ้วต่อคน x 5 รอบต่อนิ้ว = 4 Slots ต่อคน
///   - นิ้วชี้มือขวา: รอบ 1+2 → Slot A, รอบ 3+4 → Slot B, รอบ 5 = ยืนยัน
///   - นิ้วชี้มือซ้าย: รอบ 1+2 → Slot C, รอบ 3+4 → Slot D, รอบ 5 = ยืนยัน
///   - รองรับสูงสุด 31 คน (127 ÷ 4 slots)
class FingerprintSettingsScreen extends StatefulWidget {
  const FingerprintSettingsScreen({super.key});

  @override
  State<FingerprintSettingsScreen> createState() =>
      _FingerprintSettingsScreenState();
}

class _FingerprintSettingsScreenState
    extends State<FingerprintSettingsScreen> {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------
  final FingerprintNetworkService _network = FingerprintNetworkService();
  final FingerprintAttendanceService _fingerprintService =
      FingerprintAttendanceService();
  final EmployeeRepository _employeeRepo = EmployeeRepository();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  List<EmployeeProfile> _employees = [];

  // employeeId → baseSlotId (slot แรกของ 4 slots)
  // null = ยังไม่ได้ลงทะเบียน
  Map<int, int?> _baseSlotMap = {};

  final TextEditingController _hostController = TextEditingController();
  bool _isLoading = true;

  // State ระหว่างลงทะเบียน
  int? _enrollingEmployeeId;
  String _enrollStatus = '';
  int _enrollStep = 0; // 0-10: 5 ครั้งต่อนิ้ว x 2 นิ้ว
  bool _isEnrolling = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadData();
    _hostController.text = _network.connectedAddress ?? 'fingerprint.local';

    // ดักฟัง callback ผล Enroll และ Step Update จาก ESP32
    _network.onEnrollResult = _handleEnrollResult;
    _network.onEnrollStep = _handleEnrollStep;
  }

  @override
  void dispose() {
    // ⚠️ คืน callback ให้ background service เสมอ ห้าม dispose ทิ้งเปล่าๆ
    _network.onEnrollResult = null;
    _network.onEnrollStep = null;
    _hostController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI Helpers
  // ---------------------------------------------------------------------------
  void _showSnackBar(String message, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    final width = MediaQuery.of(context).size.width;
    final rightMargin = (width > 420) ? width - 380 : 20.0;

    Color bgColor = Colors.green.shade600;
    IconData icon = Icons.check_circle_outline;
    
    if (isError) {
      bgColor = Colors.red.shade600;
      icon = Icons.error_outline;
    } else if (isWarning) {
      bgColor = Colors.orange.shade700;
      icon = Icons.warning_amber_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(
          left: 20,
          bottom: 20,
          right: rightMargin,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _employeeRepo.getAll();
      final Map<int, int?> slotMap = {};
      for (final emp in employees) {
        // ดึง base slot (slot แรกจาก 4 slots ของคนนี้)
        final baseSlot =
            await _employeeRepo.getFingerprintBaseSlotByEmployee(emp.id);
        slotMap[emp.id] = baseSlot;
      }
      if (mounted) {
        setState(() {
          _employees = employees;
          _baseSlotMap = slotMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Network Connection
  // ---------------------------------------------------------------------------
  Future<void> _connectToHost() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      _showSnackBar('กรุณาระบุ IP Address หรือ Hostname', isWarning: true);
      return;
    }
    
    // UI feedback ขณะเชื่อมต่อ
    _showSnackBar('กำลังเชื่อมต่อไปยัง $host...', isWarning: true);

    final ok = await _fingerprintService.changeHost(host);
    if (!mounted) return;
    
    setState(() {}); // trigger rebuild to update connection status
    
    _showSnackBar(
      ok ? 'เชื่อมต่อ $host สำเร็จแล้วครับ!' : 'ไม่สามารถเชื่อมต่อ $host ได้',
      isError: !ok,
    );
  }

  // ---------------------------------------------------------------------------
  // Enrollment - หา Base Slot ที่ว่าง 4 ช่องติดกัน
  // ---------------------------------------------------------------------------
  int _getNextAvailableBaseSlot() {
    final usedSlots = <int>{};
    for (final base in _baseSlotMap.values) {
      if (base != null) {
        // ใช้ 4 slots: base, base+1, base+2, base+3
        usedSlots.addAll([base, base + 1, base + 2, base + 3]);
      }
    }

    // หา 4 slots ที่ว่างติดกัน (1-124 เพื่อให้มีที่เหลืออีก 3)
    for (int i = 1; i <= 124; i++) {
      if (!usedSlots.contains(i) &&
          !usedSlots.contains(i + 1) &&
          !usedSlots.contains(i + 2) &&
          !usedSlots.contains(i + 3)) {
        return i;
      }
    }
    return -1; // เต็มแล้ว
  }

  Future<void> _startEnroll(EmployeeProfile emp) async {
    if (!_network.isConnected) {
      _showSnackBar(
        'กรุณาเชื่อมต่อ ESP32 ผ่าน WiFi ก่อนลงทะเบียนลายนิ้วมือครับ',
        isWarning: true,
      );
      return;
    }

    final baseSlot = _getNextAvailableBaseSlot();
    if (baseSlot == -1) {
      _showSnackBar(
        'หน่วยความจำเครื่องสแกนเต็มแล้ว (รองรับสูงสุด ~31 คน)',
        isError: true,
      );
      return;
    }

    final name = emp.displayName ?? 'พนักงาน #${emp.id}';
    final alreadyEnrolled = _baseSlotMap[emp.id] != null;

    // ───── Dialog ยืนยันก่อนลงทะเบียน ─────
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.fingerprint, color: Colors.blue),
            const SizedBox(width: 8),
            Text(alreadyEnrolled ? 'ลงทะเบียนใหม่' : 'ลงทะเบียนลายนิ้วมือ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alreadyEnrolled)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  '⚠️ พนักงานคนนี้มีลายนิ้วมือในระบบแล้ว\nการลงทะเบียนใหม่จะเขียนทับข้อมูลเดิมในฐานข้อมูล',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            _infoRow(Icons.person, 'พนักงาน', name),
            _infoRow(Icons.storage, 'Slot ที่จะใช้',
                '#$baseSlot – #${baseSlot + 3} (รวม 4 slots)'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 ขั้นตอนการลงทะเบียน:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('นิ้วชี้มือขวา  3 ครั้ง  (สแกน 2 ยืนยัน 1)'),
                  Text('นิ้วชี้มือซ้าย  3 ครั้ง  (สแกน 2 ยืนยัน 1)'),
                  SizedBox(height: 4),
                  Text('รวมวางนิ้วทั้งหมด: 6 ครั้ง',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.fingerprint),
            label: const Text('เริ่มลงทะเบียน'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _enrollingEmployeeId = emp.id;
      _isEnrolling = true;
      _enrollStep = 0;
      _enrollStatus = 'กำลังส่งคำสั่งไปยัง ESP32...';
    });

    // ส่งคำสั่ง ENROLL:<baseSlot>:<name> → ESP32 จัดการ 2 slots เองอัตโนมัติ
    _network.sendCommand('ENROLL:$baseSlot:$name');

    setState(() {
      _enrollStatus = 'เตรียมพร้อม... รอ ESP32 ตอบรับ';
    });
  }

  // ---------------------------------------------------------------------------
  // Callbacks จาก ESP32
  // ---------------------------------------------------------------------------

  /// รับ step update ระหว่าง enroll เพื่ออัปเดต progress UI
  /// format: ENROLL_STEP:stepNumber:message
  void _handleEnrollStep(int step, String message) {
    if (!mounted) return;
    setState(() {
      _enrollStep = step;
      _enrollStatus = message;
    });
  }

  /// รับผลลัพธ์สุดท้ายจาก ESP32 (ENROLL_OK หรือ ENROLL_FAIL)
  Future<void> _handleEnrollResult(bool success, int baseSlot) async {
    if (!mounted) return;

    if (success && _enrollingEmployeeId != null) {
      try {
        final emp =
            _employees.firstWhere((e) => e.id == _enrollingEmployeeId);

        // บันทึก 4 slots ลงฐานข้อมูล
        await _employeeRepo.assignFingerprintToEmployee(
            _enrollingEmployeeId!, baseSlot, 'RIGHT_1');
        await _employeeRepo.assignFingerprintToEmployee(
            _enrollingEmployeeId!, baseSlot + 1, 'RIGHT_2');
        await _employeeRepo.assignFingerprintToEmployee(
            _enrollingEmployeeId!, baseSlot + 2, 'LEFT_1');
        await _employeeRepo.assignFingerprintToEmployee(
            _enrollingEmployeeId!, baseSlot + 3, 'LEFT_2');

        if (mounted) {
          setState(() {
            _baseSlotMap[_enrollingEmployeeId!] = baseSlot;
            _isEnrolling = false;
            _enrollingEmployeeId = null;
            _enrollStep = 0;
            _enrollStatus = '';
          });
          _showSnackBar('ลงทะเบียนลายนิ้วมือของ ${emp.displayName} สำเร็จ!');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isEnrolling = false;
            _enrollingEmployeeId = null;
            _enrollStep = 0;
            _enrollStatus = '';
          });
          _showSnackBar(
            'บันทึกข้อมูลลง DB ล้มเหลว: $e',
            isError: true,
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isEnrolling = false;
          _enrollingEmployeeId = null;
          _enrollStep = 0;
          _enrollStatus = '';
        });
        _showSnackBar(
          'ลงทะเบียนลายนิ้วมือล้มเหลว กรุณาลองใหม่อีกครั้งครับ',
          isError: true,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete - มี Dialog ยืนยัน 2 ชั้น
  // ---------------------------------------------------------------------------
  Future<void> _removeFingerprint(EmployeeProfile emp) async {
    // ชั้นที่ 1: Dialog แจ้งเตือนว่าจะลบ
    final step1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('ลบลายนิ้วมือ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(ctx).style,
                children: [
                  const TextSpan(text: 'ต้องการลบลายนิ้วมือของ\n'),
                  TextSpan(
                    text: '"${emp.displayName}"',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const TextSpan(text: '\nออกจากระบบหรือไม่?'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ ผลที่จะเกิดขึ้น:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('• ลบ 4 Slots ออกจากฐานข้อมูล POS'),
                  Text('• พนักงานจะไม่สามารถสแกนเข้างานได้'),
                  Text('• ข้อมูลใน Sensor ยังอยู่จนกว่าจะ Enroll ใหม่'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ดำเนินการต่อ'),
          ),
        ],
      ),
    );

    if (step1 != true || !mounted) return;

    // ชั้นที่ 2: ยืนยันซ้ำอีกครั้งด้วยชื่อพนักงาน
    final step2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('ยืนยันการลบ', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.fingerprint, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    emp.displayName ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'การลบนี้ไม่สามารถย้อนกลับได้',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก ไม่ลบ'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('ยืนยัน ลบออกเลย'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (step2 != true || !mounted) return;

    // ลบออกจากฐานข้อมูล (ลบทุก slots ที่ผูกกับพนักงานคนนี้)
    try {
      await _employeeRepo.removeFingerprint(emp.id);
      if (mounted) {
        setState(() => _baseSlotMap[emp.id] = null);
        _showSnackBar('ลบข้อมูลลายนิ้วมือของ ${emp.displayName} เรียบร้อยแล้วครับ');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'เกิดข้อผิดพลาดขณะลบ: $e',
          isError: true,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // คำนวณว่ายังเหลือที่ว่างกี่คน
    final enrolledCount = _baseSlotMap.values.where((v) => v != null).length;
    final remainingSlots = ((127 - (enrolledCount * 4)) / 4).floor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าเครื่องสแกนลายนิ้วมือ',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // แสดงสถานะ slot ที่เหลือ
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: remainingSlots > 5
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'เหลือ $remainingSlots คน',
                style: TextStyle(
                  color:
                      remainingSlots > 5 ? Colors.green.shade700 : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชข้อมูล',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionCard(),
            const SizedBox(height: 16),
            if (_isEnrolling) ...[
              _buildEnrollProgressCard(),
              const SizedBox(height: 16),
            ],
            Expanded(child: _buildEmployeeList()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _buildConnectionCard() {
    final isConnected = _network.isConnected;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi,
                    color: isConnected ? Colors.green : Colors.grey, size: 28),
                const SizedBox(width: 12),
                Text('สถานะการเชื่อมต่อ ESP32 (WiFi)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isConnected
                        ? '🟢 เชื่อมต่อแล้ว (${_network.connectedAddress})'
                        : '🔴 ยังไม่ได้เชื่อมต่อ',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: 'IP Address / Hostname',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.router),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหาอัตโนมัติ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('กำลังส่งสัญญาณค้นหาเครื่องสแกนในวง LAN...')),
                    );
                    _network.startAutoDiscovery();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('เชื่อมต่อ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _connectToHost,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollProgressCard() {
    // Progress 0-10: 5 steps per finger x 2 fingers
    final progress = _enrollStep / 10.0;
    final finger =
        _enrollStep <= 5 ? 'นิ้วชี้มือขวา' : 'นิ้วชี้มือซ้าย';
    final round = _enrollStep <= 5 ? _enrollStep : _enrollStep - 5;

    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.blue.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('กำลังลงทะเบียนลายนิ้วมือ...',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_enrollStatus,
                          style: TextStyle(color: Colors.blue.shade700)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _network.sendCommand('ENROLL_CANCEL');
                    setState(() {
                      _isEnrolling = false;
                      _enrollingEmployeeId = null;
                      _enrollStep = 0;
                      _enrollStatus = '';
                    });
                  },
                  child:
                      const Text('ยกเลิก', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.blue.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _enrollStep > 0 ? '$finger ครั้งที่ $round/5' : '',
                  style: TextStyle(
                      fontSize: 12, color: Colors.blue.shade600),
                ),
                Text(
                  '${(_enrollStep / 10 * 100).round()}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('รายชื่อพนักงาน',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(
              '(${_employees.length} คน)',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'ลงทะเบียน 2 นิ้ว × 5 รอบต่อนิ้ว  |  ใช้ 4 Slots ต่อคน',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _employees.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final emp = _employees[i];
              final baseSlot = _baseSlotMap[emp.id];
              final hasFingerprint = baseSlot != null;
              final isCurrentlyEnrolling = _enrollingEmployeeId == emp.id;

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: hasFingerprint
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  child: Icon(
                    Icons.fingerprint,
                    color: hasFingerprint ? Colors.green : Colors.grey,
                  ),
                ),
                title: Text(emp.displayName ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: hasFingerprint
                    ? Text(
                        '✅ ลงทะเบียนแล้ว  |  Slots #$baseSlot–#${baseSlot + 3}',
                        style: const TextStyle(color: Colors.green),
                      )
                    : const Text('❌ ยังไม่ได้ลงทะเบียน',
                        style: TextStyle(color: Colors.grey)),
                trailing: isCurrentlyEnrolling
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ปุ่มลงทะเบียน / ลงทะเบียนใหม่
                          ElevatedButton.icon(
                            icon: Icon(
                                hasFingerprint
                                    ? Icons.refresh
                                    : Icons.fingerprint,
                                size: 15),
                            label: Text(
                                hasFingerprint ? 'ลงทะเบียนใหม่' : 'ลงทะเบียน'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasFingerprint
                                  ? Colors.blue.shade50
                                  : Colors.blue,
                              foregroundColor: hasFingerprint
                                  ? Colors.blue
                                  : Colors.white,
                              elevation: hasFingerprint ? 0 : 2,
                              side: hasFingerprint
                                  ? BorderSide(color: Colors.blue.shade200)
                                  : null,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isEnrolling
                                ? null
                                : () => _startEnroll(emp),
                          ),

                          // ปุ่มลบ (แสดงเฉพาะเมื่อลงทะเบียนแล้ว)
                          if (hasFingerprint) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              tooltip: 'ลบลายนิ้วมือ',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                              ),
                              onPressed: _isEnrolling
                                  ? null
                                  : () => _removeFingerprint(emp),
                            ),
                          ],
                        ],
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
