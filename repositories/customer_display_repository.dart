import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CustomerDisplayRepository {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/customer_display_data.json');
  }

  Future<Map<String, dynamic>?> fetchDisplayState() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return null; // File not created yet
      }
      final String contents = await file.readAsString();
      if (contents.isEmpty) return null;

      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ Error reading display file: $e');
      return null;
    }
  }
}
