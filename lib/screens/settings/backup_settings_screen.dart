import 'package:flutter/material.dart';

import 'tabs/backup_tab.dart';
import 'tabs/database_config_tab.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการข้อมูล (Database & Backup)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'สำรอง & กู้คืน (Backup)'),
            Tab(text: 'ตั้งค่าฐานข้อมูล (DB Config)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BackupTab(),
          DatabaseConfigTab(),
        ],
      ),
    );
  }
}
