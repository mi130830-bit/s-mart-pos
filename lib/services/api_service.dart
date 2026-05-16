import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get _baseUrl {
    // Default to localhost:8080 if not set
    return SettingsService().getString('api_url') ??
        'http://localhost:8080/api/v1';
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  // ✅ Smart URL: Build alternative URL list for fallback discovery
  List<String> _buildUrlCandidates(String endpoint) {
    final base = _baseUrl;
    final urls = [base];

    try {
      final uri = Uri.parse(base);
      final host = uri.host;
      // If host is a simple name (no dots, not localhost/IP), try .local variant
      final isSimpleName = !host.contains('.') &&
          host != 'localhost' &&
          !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host);
      if (isSimpleName) {
        final localUri = uri.replace(host: '$host.local');
        urls.add(localUri.toString());
      }
    } catch (_) {}

    return urls.map((u) => '$u$endpoint').toList();
  }

  // ✅ If a fallback URL succeeded, persist the new host
  Future<void> _saveWorkingBaseUrl(String workingUrl, String endpoint) async {
    try {
      final uri = Uri.parse(workingUrl.replaceAll(endpoint, ''));
      final currentBase = _baseUrl;
      if (workingUrl != '$currentBase$endpoint') {
        debugPrint(
            '🔄 [API] Discovered working host: ${uri.host}. Updating config...');
        await SettingsService().set('api_url', uri.toString());
        debugPrint('✅ [API] api_url saved to: ${uri.toString()}');
      }
    } catch (e) {
      debugPrint('⚠️ [API] Failed to save working url: $e');
    }
  }

  // Generic POST (with mDNS Fallback)
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final candidates = _buildUrlCandidates(endpoint);
    Object? lastError;

    for (final urlStr in candidates) {
      try {
        debugPrint('📡 [API] POST → $urlStr');
        final url = Uri.parse(urlStr);
        final response = await http
            .post(url, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 10));
        await _saveWorkingBaseUrl(urlStr, endpoint);
        return _handleResponse(response);
      } on SocketException catch (e) {
        lastError = e;
        debugPrint('⚠️ [API] SocketException for $urlStr: $e');
        // Try next candidate
      } catch (e) {
        // Non-network error (e.g. 401 from server) — don't fallback
        rethrow;
      }
    }
    throw Exception('Network Error: $lastError');
  }

  // Generic GET (with mDNS Fallback)
  Future<dynamic> get(String endpoint) async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final candidates = _buildUrlCandidates(endpoint);
    Object? lastError;

    for (final urlStr in candidates) {
      try {
        debugPrint('📡 [API] GET → $urlStr');
        final url = Uri.parse(urlStr);
        final response = await http
            .get(url, headers: headers)
            .timeout(const Duration(seconds: 10));
        await _saveWorkingBaseUrl(urlStr, endpoint);
        return _handleResponse(response);
      } on SocketException catch (e) {
        lastError = e;
        debugPrint('⚠️ [API] SocketException for $urlStr: $e');
      } catch (e) {
        rethrow;
      }
    }
    throw Exception('Network Error: $lastError');
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      try {
        final body = jsonDecode(response.body);
        throw Exception(
            body['error'] ?? 'Request failed: ${response.statusCode}');
      } catch (_) {
        throw Exception('Request failed: ${response.statusCode}');
      }
    }
  }
}
