import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

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

  /// แปลง Firestore Value Type เป็น Dart Type
  dynamic _parseValue(Map<String, dynamic>? valueMap) {
    if (valueMap == null) return null;
    
    if (valueMap.containsKey('stringValue')) return valueMap['stringValue'];
    if (valueMap.containsKey('integerValue')) return int.tryParse(valueMap['integerValue'].toString());
    if (valueMap.containsKey('doubleValue')) return double.tryParse(valueMap['doubleValue'].toString());
    if (valueMap.containsKey('booleanValue')) return valueMap['booleanValue'];
    if (valueMap.containsKey('timestampValue')) {
      try {
        return DateTime.parse(valueMap['timestampValue'].toString()).toLocal();
      } catch (e) {
        return DateTime.now();
      }
    }
    if (valueMap.containsKey('nullValue')) return null;
    
    if (valueMap.containsKey('mapValue')) {
      final fields = valueMap['mapValue']['fields'] as Map<String, dynamic>?;
      if (fields == null) return <String, dynamic>{};
      final result = <String, dynamic>{};
      fields.forEach((k, v) {
        result[k] = _parseValue(v as Map<String, dynamic>);
      });
      return result;
    }
    
    if (valueMap.containsKey('arrayValue')) {
      final values = valueMap['arrayValue']['values'] as List<dynamic>?;
      if (values == null) return [];
      return values.map((v) => _parseValue(v as Map<String, dynamic>)).toList();
    }
    
    if (valueMap.containsKey('geoPointValue')) {
      return valueMap['geoPointValue']; // { "latitude": x, "longitude": y }
    }
    
    return null;
  }

  /// แปลง Firestore Document ให้เป็น Map ปกติ
  Map<String, dynamic> _parseDocument(Map<String, dynamic> doc) {
    final result = <String, dynamic>{};
    
    final name = doc['name'] as String?;
    if (name != null) {
      result['id'] = name.split('/').last;
    }

    final fields = doc['fields'] as Map<String, dynamic>?;
    if (fields != null) {
      fields.forEach((key, valueMap) {
        result[key] = _parseValue(valueMap as Map<String, dynamic>);
      });
    }
    
    return result;
  }

  /// แปลง Dart value เป็น Firestore REST format
  dynamic _encodeValue(dynamic value) {
    if (value == null) return {"nullValue": null};
    if (value is String) return {"stringValue": value};
    if (value is int) return {"integerValue": value.toString()};
    if (value is double) return {"doubleValue": value};
    if (value is bool) return {"booleanValue": value};
    if (value is DateTime) return {"timestampValue": value.toUtc().toIso8601String()};
    if (value is Map && value.containsKey('latitude') && value.containsKey('longitude')) {
      return {
        "geoPointValue": {
          "latitude": value['latitude'],
          "longitude": value['longitude']
        }
      };
    }
    if (value is Map<String, dynamic>) {
      return {
        "mapValue": {
          "fields": value.map((k, v) => MapEntry(k, _encodeValue(v)))
        }
      };
    }
    if (value is Map) {
      final strMap = value.cast<String, dynamic>();
      return {
        "mapValue": {
          "fields": strMap.map((k, v) => MapEntry(k, _encodeValue(v)))
        }
      };
    }
    if (value is List) {
      return {
        "arrayValue": {
          "values": value.map((v) => _encodeValue(v)).toList()
        }
      };
    }
    return {"stringValue": value.toString()};
  }

  /// แปลง Dart Map ทั้งหมดเป็น Firestore fields format
  Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _encodeValue(value)));
  }

  // --- Instance Methods ---

  Future<FirestoreResult<List<Map<String, dynamic>>>> getCars() async {
    LoggerService.info('FirestoreREST', 'REST Request: GET /cars');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/cars'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final docs = data['documents'] as List<dynamic>? ?? [];
        final list = docs.map((d) => _parseDocument(d as Map<String, dynamic>)).toList();
        LoggerService.debug('FirestoreREST', 'REST Response: GET /cars - Success (${list.length} cars)');
        return FirestoreResult.success(list);
      } else {
        final errorMsg = 'Failed to fetch cars: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in getCars: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<List<Map<String, dynamic>>>> getActiveDeliveryJobs() async {
    LoggerService.info('FirestoreREST', 'REST Request: POST /jobs:runQuery (Active Jobs)');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final payload = {
        "structuredQuery": {
          "from": [{"collectionId": "jobs"}],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "status"},
              "op": "IN",
              "value": {
                "arrayValue": {
                  "values": [
                    {"stringValue": "pending"},
                    {"stringValue": "shipping"},
                    {"stringValue": "enroute"},
                    {"stringValue": "en_route"},
                    {"stringValue": "accepted"}
                  ]
                }
              }
            }
          }
        }
      };

      final response = await _client.post(
        Uri.parse('$baseUrl:runQuery'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final results = <Map<String, dynamic>>[];
        
        for (var item in data) {
          if (item.containsKey('document')) {
            results.add(_parseDocument(item['document'] as Map<String, dynamic>));
          }
        }
        
        results.sort((a, b) {
          final dateA = a['created_at'] as DateTime?;
          final dateB = b['created_at'] as DateTime?;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

        LoggerService.debug('FirestoreREST', 'REST Response: POST /jobs:runQuery (Active) - Success (${results.length} jobs)');
        return FirestoreResult.success(results);
      } else {
        final errorMsg = 'Failed to fetch active jobs: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in getActiveDeliveryJobs: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<List<Map<String, dynamic>>>> getArchivableJobs() async {
    LoggerService.info('FirestoreREST', 'REST Request: POST /jobs:runQuery (Archivable Jobs)');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final payload = {
        "structuredQuery": {
          "from": [{"collectionId": "jobs"}],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "status"},
              "op": "EQUAL",
              "value": {
                "stringValue": "completed"
              }
            }
          }
        }
      };

      final response = await _client.post(
        Uri.parse('$baseUrl:runQuery'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final results = <Map<String, dynamic>>[];
        
        for (var item in data) {
          if (item.containsKey('document')) {
            results.add(_parseDocument(item['document'] as Map<String, dynamic>));
          }
        }
        LoggerService.debug('FirestoreREST', 'REST Response: POST /jobs:runQuery (Archivable) - Success (${results.length} jobs)');
        return FirestoreResult.success(results);
      } else {
        final errorMsg = 'Failed to fetch archivable jobs: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in getArchivableJobs: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<List<Map<String, dynamic>>>> getShopWorkLogs() async {
    LoggerService.info('FirestoreREST', 'REST Request: POST /shop_work_logs:runQuery');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final payload = {
        "structuredQuery": {
          "from": [{"collectionId": "shop_work_logs"}],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "logged_at"},
              "op": "GREATER_THAN_OR_EQUAL",
              "value": {
                "timestampValue": sevenDaysAgo.toUtc().toIso8601String()
              }
            }
          },
          "orderBy": [
            {
              "field": {"fieldPath": "logged_at"},
              "direction": "DESCENDING"
            }
          ],
          "limit": 20
        }
      };

      final response = await _client.post(
        Uri.parse('$baseUrl:runQuery'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final results = <Map<String, dynamic>>[];
        
        for (var item in data) {
          if (item.containsKey('document')) {
            final mappedDoc = _parseDocument(item['document'] as Map<String, dynamic>);
            if (mappedDoc['logged_at'] is DateTime) {
              mappedDoc['created_at'] = mappedDoc['logged_at'];
            }
            results.add(mappedDoc);
          }
        }
        LoggerService.debug('FirestoreREST', 'REST Response: POST /shop_work_logs:runQuery - Success (${results.length} logs)');
        return FirestoreResult.success(results);
      } else {
        final errorMsg = 'Failed to fetch shop work logs: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in getShopWorkLogs: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<List<Map<String, dynamic>>>> getPendingCommands(String devId) async {
    LoggerService.info('FirestoreREST', 'REST Request: POST /commands:runQuery for $devId');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final payload = {
        "structuredQuery": {
          "from": [{"collectionId": "commands"}],
          "where": {
            "compositeFilter": {
              "op": "AND",
              "filters": [
                {
                  "fieldFilter": {
                    "field": {"fieldPath": "status"},
                    "op": "EQUAL",
                    "value": {"stringValue": "PENDING"}
                  }
                },
                {
                  "fieldFilter": {
                    "field": {"fieldPath": "created_at"},
                    "op": "GREATER_THAN_OR_EQUAL",
                    "value": {
                      "timestampValue": DateTime.now()
                          .subtract(const Duration(minutes: 5))
                          .toUtc()
                          .toIso8601String()
                    }
                  }
                },
                {
                  "fieldFilter": {
                    "field": {"fieldPath": "target_device_id"},
                    "op": "IN",
                    "value": {
                      "arrayValue": {
                        "values": [
                          {"stringValue": devId},
                          {"stringValue": "POS_MASTER"}
                        ]
                      }
                    }
                  }
                }
              ]
            }
          },
          "limit": 10
        }
      };

    final response = await _client.post(
      Uri.parse('$baseUrl:runQuery'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      final results = <Map<String, dynamic>>[];
      
      for (var item in data) {
        if (item.containsKey('document')) {
          results.add(_parseDocument(item['document'] as Map<String, dynamic>));
        }
      }
      LoggerService.debug('FirestoreREST', 'REST Response: POST /commands:runQuery - Success (${results.length} commands)');
      return FirestoreResult.success(results);
    } else {
      final errorMsg = 'Failed to fetch commands: ${response.statusCode} - ${response.body}';
      LoggerService.error('FirestoreREST', errorMsg);
      return FirestoreResult.failure(errorMsg);
    }
  } catch (e) {
    final errorMsg = 'Exception in getPendingCommands: $e';
    LoggerService.error('FirestoreREST', errorMsg, e);
    return FirestoreResult.failure(errorMsg);
  }
}

  Future<FirestoreResult<List<String>>> getExpiredPickupJobs(int minutesOld) async {
    LoggerService.info('FirestoreREST', 'REST Request: POST /jobs:runQuery (Expired Pickup Jobs)');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final cutoff = DateTime.now().subtract(Duration(minutes: minutesOld));

      final payload = {
        "structuredQuery": {
          "from": [{"collectionId": "jobs"}],
          "where": {
            "compositeFilter": {
              "op": "AND",
              "filters": [
                {
                  "fieldFilter": {
                    "field": {"fieldPath": "job_type"},
                    "op": "IN",
                    "value": {
                      "arrayValue": {
                        "values": [
                          {"stringValue": "pickup"},
                          {"stringValue": "customer_pickup"}
                        ]
                      }
                    }
                  }
                },
                {
                  "fieldFilter": {
                    "field": {"fieldPath": "created_at"},
                    "op": "LESS_THAN",
                    "value": {
                      "timestampValue": cutoff.toUtc().toIso8601String()
                    }
                  }
                }
              ]
            }
          }
        }
      };

      final response = await _client.post(
        Uri.parse('$baseUrl:runQuery'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final results = <String>[];
        for (var item in data) {
          if (item.containsKey('document')) {
            final name = item['document']['name'] as String?;
            if (name != null) results.add(name.split('/').last);
          }
        }
        LoggerService.debug('FirestoreREST', 'REST Response: POST /jobs:runQuery (Expired Pickup) - Success (${results.length} jobs)');
        return FirestoreResult.success(results);
      } else {
        final errorMsg = 'Failed to fetch expired pickup jobs: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in getExpiredPickupJobs: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<List<Map<String, dynamic>>>> getStockCheckJobs() async {
    LoggerService.info('FirestoreREST', 'REST Request: POST /jobs:runQuery (Stock Check Jobs)');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final payload = {
        "structuredQuery": {
          "from": [{"collectionId": "jobs"}],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "created_at"},
              "op": "GREATER_THAN",
              "value": {
                "timestampValue": sevenDaysAgo.toUtc().toIso8601String()
              }
            }
          },
          "orderBy": [
            {
              "field": {"fieldPath": "created_at"},
              "direction": "DESCENDING"
            }
          ],
          "limit": 20
        }
      };

      final response = await _client.post(
        Uri.parse('$baseUrl:runQuery'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final results = <Map<String, dynamic>>[];
        for (var item in data) {
          if (item.containsKey('document')) {
            results.add(_parseDocument(item['document'] as Map<String, dynamic>));
          }
        }
        LoggerService.debug('FirestoreREST', 'REST Response: POST /jobs:runQuery (Stock Check) - Success (${results.length} jobs)');
        return FirestoreResult.success(results);
      } else {
        final errorMsg = 'Failed to fetch stock check jobs: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in getStockCheckJobs: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<String?>> getCustomerByPhone(String phone) async {
    LoggerService.info('FirestoreREST', 'REST Request: POST /customers:runQuery for phone $phone');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final payload = {
        "structuredQuery": {
          "from": [{"collectionId": "customers"}],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "phone_number"},
              "op": "EQUAL",
              "value": {
                "stringValue": phone
              }
            }
          },
          "limit": 1
        }
      };

      final response = await _client.post(
        Uri.parse('$baseUrl:runQuery'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        for (var item in data) {
          if (item.containsKey('document')) {
            final doc = item['document'];
            final name = doc['name'] as String?;
            final docId = name?.split('/').last;
            LoggerService.debug('FirestoreREST', 'REST Response: POST /customers:runQuery - Success (Found customer: $docId)');
            return FirestoreResult.success(docId);
          }
        }
        LoggerService.debug('FirestoreREST', 'REST Response: POST /customers:runQuery - Success (No customer found)');
        return FirestoreResult.success(null);
      } else {
        final errorMsg = 'Failed to find customer: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in getCustomerByPhone: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<String?>> addDocument(String collection, Map<String, dynamic> data) async {
    LoggerService.info('FirestoreREST', 'REST Request: POST /$collection');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final payload = {"fields": _encodeFields(data)};

      final response = await _client.post(
        Uri.parse('$baseUrl/$collection'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final name = json['name'] as String?;
        final docId = name?.split('/').last;
        LoggerService.debug('FirestoreREST', 'REST Response: POST /$collection - Success (Created: $docId)');
        return FirestoreResult.success(docId);
      } else {
        final errorMsg = 'Failed to create doc: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in addDocument: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<void>> setDocument(String collection, String docId, Map<String, dynamic> updates) async {
    LoggerService.info('FirestoreREST', 'REST Request: PATCH /$collection/$docId');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final fields = <String, dynamic>{};
      updates.forEach((key, value) {
        fields[key] = _encodeValue(value);
      });

      final payload = {"fields": fields};
      final updateMask = updates.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');

      final response = await _client.patch(
        Uri.parse('$baseUrl/$collection/$docId?$updateMask'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        LoggerService.debug('FirestoreREST', 'REST Response: PATCH /$collection/$docId - Success');
        return FirestoreResult.success(null);
      } else {
        final errorMsg = 'Failed to update doc: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in setDocument: $e';
      LoggerService.error('FirestoreREST', errorMsg, e);
      return FirestoreResult.failure(errorMsg);
    }
  }

  Future<FirestoreResult<void>> removeDocument(String collection, String docId) async {
    LoggerService.info('FirestoreREST', 'REST Request: DELETE /$collection/$docId');
    try {
      final token = await _getToken();
      if (token == null) {
        const errorMsg = 'Auth failed: Token is null';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }

      final response = await _client.delete(
        Uri.parse('$baseUrl/$collection/$docId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        LoggerService.debug('FirestoreREST', 'REST Response: DELETE /$collection/$docId - Success');
        return FirestoreResult.success(null);
      } else {
        final errorMsg = 'Failed to delete doc: ${response.statusCode} - ${response.body}';
        LoggerService.error('FirestoreREST', errorMsg);
        return FirestoreResult.failure(errorMsg);
      }
    } catch (e) {
      final errorMsg = 'Exception in removeDocument: $e';
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
