import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:firedart/firedart.dart';
import 'package:backend/db_config.dart';

class PrintBridgeService {
  static final PrintBridgeService _instance = PrintBridgeService._internal();
  factory PrintBridgeService() => _instance;
  PrintBridgeService._internal();

  bool _isListening = false;
  
  /// Start listening to Firestore 'commands' and bridge to local MySQL
  Future<void> startBridge() async {
    if (_isListening) return;
    
    // Check if Firestore is initialized. We need it for fir-link-a8266
    // If it was initialized with opsmate-3dde2, it might crash, but let's assume
    // we can initialize it here if not already initialized.
    try {
      if (!Firestore.initialized) {
        Firestore.initialize('fir-link-a8266');
        stdout.writeln('✅ Firestore Bridge initialized for: fir-link-a8266');
      }
    } catch (e) {
      // Ignored if already initialized
    }

    stdout.writeln('📡 [Bridge] Polling for new PRINT_RECEIPT commands...');
    _isListening = true;

    // Use a periodic timer instead of stream to prevent gRPC timeout issues on Windows
    Timer.periodic(Duration(seconds: 3), (timer) async {
      try {
        final query = await Firestore.instance
            .collection('commands')
            .where('status', isEqualTo: 'PENDING')
            .get();

        for (var doc in query) {
          final data = doc.map;
          final docId = doc.id;
          final command = data['command']?.toString() ?? '';
          final target = data['target_device_id']?.toString() ?? 'POS_MASTER';
          
          final payloadStr = data['payload'] != null ? jsonEncode(data['payload']) : null;
          
          stdout.writeln('\n📥 [Bridge] Found PENDING command: $docId | CMD: $command');

          try {
            final conn = await DbConfig().connection;
            final result = await conn.execute(
              'SELECT id FROM pos_commands WHERE id = :id', 
              {'id': docId}
            );

            if (result.rows.isEmpty) {
              await conn.execute(
                '''
                INSERT INTO pos_commands (id, command, payload, status, target_device_id)
                VALUES (:id, :cmd, :payload, 'PENDING', :target)
                ''',
                {
                  'id': docId,
                  'cmd': command,
                  'payload': payloadStr,
                  'target': target,
                }
              );
              stdout.writeln('✅ [MySQL] Saved command $docId');
            }

            // Update Firestore to mark as transferred
            await Firestore.instance.collection('commands').document(docId).update({
              'status': 'TRANSFERRED_TO_LOCAL',
              'result_message': 'Transferred to Local DB via Backend Bridge',
              'transferred_at': DateTime.now().toIso8601String(),
            });
            stdout.writeln('✅ [Firestore] Marked $docId as TRANSFERRED_TO_LOCAL');

          } catch (e) {
            stderr.writeln('❌ [Bridge Error] Failed to process $docId: $e');
          }
        }
      } catch (e) {
        // Suppress network errors from polluting logs too much
        // stderr.writeln('❌ [Bridge] Polling error: $e');
      }
    });
  }
}
