import 'package:flutter/material.dart';
import '../../services/backup/google_drive_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _driveService = GoogleDriveService();
  bool _isLoading = false;
  String? _statusMsg;

  Future<void> _linkGoogleAccount() async {
    setState(() => _isLoading = true);
    final success = await _driveService.authenticate();
    setState(() {
      _isLoading = false;
      _statusMsg =
          success ? '✅ เชื่อมต่อ Google Drive สำเร็จ' : '❌ เชื่อมต่อไม่สำเร็จ';
    });
  }

  Future<void> _testUpload() async {
    // Pick a dummy file or create one
    // For real usage, we should dump DB to file.
    // Here we just pick a file to test upload.
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      final file = File(result.files.single.path!);
      final id = await _driveService.uploadFile(file, 'Test Backup from POS');
      setState(() {
        _isLoading = false;
        _statusMsg =
            id != null ? '✅ อัปโหลดสำเร็จ (ID: $id)' : '❌ อัปโหลดล้มเหลว';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าการสำรองข้อมูล (Backup)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text('Google Drive Backup',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('เชื่อมต่อกับบัญชี Google เพื่อสำรองข้อมูล',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              if (_statusMsg != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[200],
                  child:
                      Text(_statusMsg!, style: const TextStyle(fontSize: 16)),
                ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _linkGoogleAccount,
                icon: const Icon(Icons.link),
                label: const Text('เชื่อมต่อ Google Account'),
                style:
                    ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _testUpload,
                icon: const Icon(Icons.upload_file),
                label: const Text('ทดสอบอัปโหลดไฟล์'),
                style:
                    ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
