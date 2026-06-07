import 'package:flutter/material.dart';

import 'tabs/hr_attendance_tab.dart';
import 'tabs/hr_employee_tab.dart';
import 'tabs/hr_leave_tab.dart';
import 'tabs/hr_advance_tab.dart';
import 'tabs/hr_payroll_tab.dart';
import 'tabs/hr_summary_tab.dart';

import '../../services/hr/attendance_sync_service.dart';
import '../../services/hr/advance_sync_service.dart';

class HrScreen extends StatefulWidget {
  const HrScreen({super.key});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _manualSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    
    try {
      await AttendanceSyncService().syncAttendanceFromCloud();
      await AdvanceSyncService().syncAdvanceRequestsFromCloud();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ซิงค์ข้อมูลจากคลาวด์เรียบร้อยแล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการซิงค์: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ระบบบริหารทรัพยากรบุคคล (HR & Payroll)'),
        actions: [
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'ซิงค์ข้อมูลคลาวด์',
                  onPressed: _manualSync,
                ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'ภาพรวม'),
            Tab(icon: Icon(Icons.people), text: 'พนักงาน'),
            Tab(icon: Icon(Icons.access_time), text: 'ลงเวลา (Attendance)'),
            Tab(icon: Icon(Icons.event_note), text: 'วันลา'),
            Tab(icon: Icon(Icons.money), text: 'เบิกล่วงหน้า'),
            Tab(icon: Icon(Icons.receipt_long), text: 'เงินเดือน (Payroll)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          HrSummaryTab(),
          HrEmployeeTab(),
          HrAttendanceTab(),
          HrLeaveTab(),
          HrAdvanceTab(),
          HrPayrollTab(),
        ],
      ),
    );
  }
}
