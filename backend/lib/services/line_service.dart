import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../db_config.dart';

class LineService {
  // Fallback token if not set in DB or env — kept for reference only
  static const String defaultChannelAccessToken =
      'rbwbRRNy8wjP2GDiKog0TlimQwr7WZ0FIXrQu0FjzApCF4Qfu3zBB5Pm+lMLiUgoJFUdgrHJMZCq0wznkxCosr3B6QUHIvKuPSIO/BFVzs7lLcfHNwjQ0vDdre+VJ/eB1nysWDpSbVprK9PwZhlpkQdB04t89/1O/w1cDnyilFU==';

  // Load token from DB if not set
  Future<String> getAccessToken() async {
    // Always reload from DB to ensure latest token
    try {
      // 1. Try Environment Variable first
      final envToken = Platform.environment['LINE_CHANNEL_TOKEN'];
      if (envToken != null && envToken.isNotEmpty) {
        return envToken;
      }

      // 2. Try Database (system_settings)
      final conn = await DbConfig().connection;
      final results = await conn.execute(
        "SELECT setting_value FROM system_settings WHERE setting_key = 'line_channel_access_token'",
      );

      if (results.numOfRows > 0) {
        final dbToken = results.rows.first.colAt(0);
        if (dbToken != null && dbToken.isNotEmpty) {
          return dbToken;
        }
      }
    } catch (e) {
      stderr.writeln('Error loading Line Token: $e');
    }

    return defaultChannelAccessToken;
  }

  // Future<void> setAccessToken(String token) async {
  //   _channelAccessToken = token;
  // }

  Future<bool> pushMessage(String userId, String text) async {
    final token = await getAccessToken();
    if (token.isEmpty) {
      stderr.writeln('⚠️ Line Token not configured — skipping push.');
      return false;
    }

    final url = Uri.parse('https://api.line.me/v2/bot/message/push');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'to': userId,
      'messages': [
        {'type': 'text', 'text': text},
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        stderr.writeln('❌ [LINE] Push Message Failed: HTTP ${response.statusCode}');
        stderr.writeln('❌ [LINE] Response Body: ${response.body}');
        stderr.writeln('❌ [LINE] Token Used (first 20): ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      } else {
        stdout.writeln('✅ [LINE] Push Message OK → $userId');
      }
      return response.statusCode == 200;
    } catch (e) {
      stderr.writeln('Line Push Error: $e');
      return false;
    }
  }

  Future<bool> pushImage(
    String userId,
    String imageUrl, {
    String? previewUrl,
  }) async {
    final token = await getAccessToken();
    if (token.isEmpty) return false;

    final url = Uri.parse('https://api.line.me/v2/bot/message/push');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'to': userId,
      'messages': [
        {
          'type': 'image',
          'originalContentUrl': imageUrl,
          'previewImageUrl': previewUrl ?? imageUrl,
        },
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        stderr.writeln('❌ [LINE] Push Image Failed: HTTP ${response.statusCode}');
        stderr.writeln('❌ [LINE] Response Body: ${response.body}');
      } else {
        stdout.writeln('✅ [LINE] Push Image OK → $userId ($imageUrl)');
      }
      return response.statusCode == 200;
    } catch (e) {
      stderr.writeln('Line Push Image Error: $e');
      return false;
    }
  }

  // Reply Message (Generalized)
  Future<bool> reply(
    String replyToken,
    List<Map<String, dynamic>> messages,
  ) async {
    final token = await getAccessToken();
    if (token == defaultChannelAccessToken) {
      return false;
    }

    final url = Uri.parse('https://api.line.me/v2/bot/message/reply');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({'replyToken': replyToken, 'messages': messages});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        stderr.writeln('Line Reply Failed: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      stderr.writeln('Line Reply Error: $e');
      return false;
    }
  }

  // Legacy Text Reply Helper
  Future<bool> replyMessage(String replyToken, String text) async {
    return reply(replyToken, [
      {'type': 'text', 'text': text},
    ]);
  }

  // Helper for Image Reply (using public URL)
  Future<bool> replyImage(String replyToken, String imageUrl) async {
    return reply(replyToken, [
      {
        'type': 'image',
        'originalContentUrl': imageUrl,
        'previewImageUrl': imageUrl,
      },
    ]);
  }
}
