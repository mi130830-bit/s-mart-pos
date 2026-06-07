// ignore: unnecessary_library_name
library firestore_rest_service;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

part 'firestore/firestore_rest_parser.dart';
part 'firestore/firestore_rest_core.dart';
part 'firestore/firestore_rest_jobs.dart';
part 'firestore/firestore_rest_cars.dart';
part 'firestore/firestore_rest_customers.dart';
part 'firestore/firestore_rest_commands.dart';
part 'firestore/firestore_rest_logs.dart';
part 'firestore/firestore_rest_users.dart';
part 'firestore/firestore_rest_attendance.dart';
part 'firestore/firestore_rest_advance.dart';

class FirestoreResult<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  FirestoreResult.success(this.data) : errorMessage = null, isSuccess = true;
  FirestoreResult.failure(this.errorMessage) : data = null, isSuccess = false;
}

class FirestoreRestService {
  static const String projectId = 'fir-link-a8266';
  static const String baseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  // Singleton Instance
  static final FirestoreRestService _instance = FirestoreRestService._internal();
  factory FirestoreRestService() => _instance;
  FirestoreRestService._internal();

  // Persistent Client for Connection Pooling
  final http.Client _client = http.Client();

  /// ดึง Token ปัจจุบันจาก FirebaseAuth
  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      LoggerService.warning('FirestoreREST', '[REST] No current user found. Token is null.');
      return null;
    }
    return await user.getIdToken();
  }

  /// Sends HTTP request to Firestore REST API with token authorization, logging and exception handling.
  Future<FirestoreResult<dynamic>> _sendRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? payload,
    required String logPrefix,
  }) async {
    LoggerService.info('FirestoreREST', 'REST Request: $method ${uri.path} ($logPrefix)');
    try {
      final token = await _getToken();
      if (token == null) {
        final errorMsg = 'Auth failed: Token is null ($logPrefix)';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final headers = {
        'Authorization': 'Bearer $token',
        if (payload != null) 'Content-Type': 'application/json',
      };

      http.Response response;
      if (method == 'GET') {
        response = await _client.get(uri, headers: headers);
      } else if (method == 'POST') {
        response = await _client.post(uri, headers: headers, body: jsonEncode(payload));
      } else if (method == 'PATCH') {
        response = await _client.patch(uri, headers: headers, body: jsonEncode(payload));
      } else if (method == 'DELETE') {
        response = await _client.delete(uri, headers: headers);
      } else {
        return FirestoreResult.failure('Unsupported HTTP method: $method');
      }

      if (response.statusCode == 200) {
        final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        LoggerService.debug('FirestoreREST', 'REST Response: $method ${uri.path} - Success ($logPrefix)');
        return FirestoreResult.success(data);
      } else {
        final errorMsg = 'Failed ($logPrefix): ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in $logPrefix: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  // --- Static Legacy Compatibility Wrappers ---

  static Future<List<Map<String, dynamic>>> fetchCars() async {
    final result = await _instance.getCars();
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data!;
  }

  static Future<List<Map<String, dynamic>>> fetchActiveDeliveryJobs() async {
    final result = await _instance.getActiveDeliveryJobs();
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data!;
  }

  static Future<List<Map<String, dynamic>>> fetchArchivableJobs() async {
    final result = await _instance.getArchivableJobs();
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data!;
  }

  static Future<List<Map<String, dynamic>>> fetchShopWorkLogs() async {
    final result = await _instance.getShopWorkLogs();
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data!;
  }

  static Future<List<Map<String, dynamic>>> fetchPendingCommands(String devId) async {
    final result = await _instance.getPendingCommands(devId);
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data!;
  }

  static Future<List<Map<String, dynamic>>> fetchSLinkUsers() async {
    final result = await _instance.getSLinkUsers();
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data!;
  }

  static Future<List<String>> fetchExpiredPickupJobs(int minutesOld) async {
    final result = await _instance.getExpiredPickupJobs(minutesOld);
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data!;
  }

  static Future<List<Map<String, dynamic>>> fetchStockCheckJobs() async {
    final result = await _instance.getStockCheckJobs();
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data!;
  }

  static Future<String?> findCustomerByPhone(String phone) async {
    final result = await _instance.getCustomerByPhone(phone);
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data;
  }

  static Future<String?> createDocument(String collection, Map<String, dynamic> data) async {
    final result = await _instance.addDocument(collection, data);
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
    return result.data;
  }

  static Future<void> updateDocument(String collection, String docId, Map<String, dynamic> updates) async {
    final result = await _instance.setDocument(collection, docId, updates);
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
  }

  static Future<void> deleteDocument(String collection, String docId) async {
    final result = await _instance.removeDocument(collection, docId);
    if (!result.isSuccess) {
      throw Exception(result.errorMessage);
    }
  }
}
