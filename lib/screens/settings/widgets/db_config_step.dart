import 'package:flutter/material.dart';

class DbConfigStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController userController;
  final TextEditingController passController;
  final TextEditingController dbController;
  final TextEditingController machineNameController;
  final bool isServer;
  final bool isLoading;
  final String? statusMessage;
  final bool isSuccess;
  final void Function(bool value) onServerModeChanged;
  final VoidCallback onTestAndSave;

  const DbConfigStep({
    super.key,
    required this.formKey,
    required this.hostController,
    required this.portController,
    required this.userController,
    required this.passController,
    required this.dbController,
    required this.machineNameController,
    required this.isServer,
    required this.isLoading,
    required this.statusMessage,
    required this.isSuccess,
    required this.onServerModeChanged,
    required this.onTestAndSave,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('1. การตั้งค่าฐานข้อมูล (Database)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Machine Type Selector
          RadioGroup<bool>(
            groupValue: isServer,
            onChanged: (v) {
              if (v != null) onServerModeChanged(v);
            },
            child: Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    value: true,
                    title: const Text('เครื่องแม่ (Server)'),
                    subtitle: const Text('เครื่องนี้เก็บฐานข้อมูลไว้ที่ตัวเอง'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    value: false,
                    title: const Text('เครื่องลูก (Client)'),
                    subtitle: const Text('เชื่อมต่อกับเครื่องแม่ผ่าน Network'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: 10),

          // Machine Name (Server only)
          if (isServer) ...[
            TextFormField(
              controller: machineNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อเครื่องแม่ (Machine Name)',
                hintText: 'ตัวอย่าง: DESKTOP-SERVER01 หรือ POS-MAIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextFormField(
            controller: hostController,
            enabled: !isServer,
            decoration: InputDecoration(
              labelText: isServer ? 'Host IP (Local)' : 'Host IP / Machine Name',
              hintText: isServer
                  ? '127.0.0.1'
                  : 'ตัวอย่าง: 192.168.1.100 หรือ COMPUTER-01',
              border: const OutlineInputBorder(),
              suffixIcon: isServer ? const Icon(Icons.lock_outline, color: Colors.grey) : null,
            ),
            validator: (v) => v!.isEmpty ? 'ระบุ Host/IP' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: portController,
            decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            validator: (v) => v!.isEmpty ? 'ระบุ Port' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: userController,
            decoration:
                const InputDecoration(labelText: 'DB Username', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'ระบุ Username' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passController,
            decoration:
                const InputDecoration(labelText: 'DB Password', border: OutlineInputBorder()),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: dbController,
            decoration:
                const InputDecoration(labelText: 'Database Name', border: OutlineInputBorder()),
            validator: (v) => v!.isEmpty ? 'ระบุชื่อฐานข้อมูล' : null,
          ),
          const SizedBox(height: 20),

          if (statusMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              color: isSuccess ? Colors.green.shade100 : Colors.red.shade100,
              child: Text(
                statusMessage!,
                style: TextStyle(
                  color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
            ),

          ElevatedButton.icon(
            onPressed: isLoading ? null : onTestAndSave,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('ทดสอบและบันทึกการตั้งค่า'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ],
      ),
    );
  }
}
