import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreRestService {
  static const String projectId = 'fir-link-a8266';
  static const String baseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// ดึง Token ปัจจุบันจาก FirebaseAuth
  static Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [REST] No current user found. Token is null.');
      return null;
    }
    return await user.getIdToken();
  }

  /// แปลง Firestore Value Type เป็น Dart Type
  static dynamic _parseValue(Map<String, dynamic>? valueMap) {
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
    
    // GeoPoint
    if (valueMap.containsKey('geoPointValue')) {
      return valueMap['geoPointValue']; // { "latitude": x, "longitude": y }
    }
    
    return null;
  }

  /// แปลง Firestore Document ให้เป็น Map ปกติ
  static Map<String, dynamic> _parseDocument(Map<String, dynamic> doc) {
    final result = <String, dynamic>{};
    
    // ดึง ID ออกมาจาก name: projects/fir-link-a8266/databases/(default)/documents/collection/id
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
  static dynamic _encodeValue(dynamic value) {
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
      // Generic map fallback
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
    // Fallback: stringify
    return {"stringValue": value.toString()};
  }

  /// แปลง Dart Map ทั้งหมดเป็น Firestore fields format
  static Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _encodeValue(value)));
  }

  /// ดึงข้อมูลรถ (Cars)
  static Future<List<Map<String, dynamic>>> fetchCars() async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

    final response = await http.get(
      Uri.parse('$baseUrl/cars'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final docs = data['documents'] as List<dynamic>? ?? [];
      
      return docs.map((d) => _parseDocument(d as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch cars: ${response.body}');
    }
  }

  /// ดึง Active Jobs (status IN [pending, shipping, enroute, en_route, accepted])
  static Future<List<Map<String, dynamic>>> fetchActiveDeliveryJobs() async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

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

    final response = await http.post(
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
      
      // Sort locally by created_at descending
      results.sort((a, b) {
        final dateA = a['created_at'] as DateTime?;
        final dateB = b['created_at'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
      
      return results;
    } else {
      throw Exception('Failed to fetch active jobs: ${response.body}');
    }
  }

  /// ดึงข้อมูลงานที่พร้อม Archive (สถานะ completed)
  static Future<List<Map<String, dynamic>>> fetchArchivableJobs() async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

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

    final response = await http.post(
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
      return results;
    } else {
      throw Exception('Failed to fetch archivable jobs: ${response.body}');
    }
  }

  /// ดึงข้อมูล Shop Work Logs
  static Future<List<Map<String, dynamic>>> fetchShopWorkLogs() async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

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

    final response = await http.post(
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
          // Map 'logged_at' to 'created_at' for consistency in UI
          if (mappedDoc['logged_at'] is DateTime) {
            mappedDoc['created_at'] = mappedDoc['logged_at'];
          }
          results.add(mappedDoc);
        }
      }
      return results;
    } else {
      throw Exception('Failed to fetch shop work logs: ${response.body}');
    }
  }

  /// ดึงคำสั่งที่ค้างอยู่ (Commands) สำหรับอุปกรณ์นี้ (ใช้แก้ปัญหาการพิมพ์ใบเสร็จบน Windows)
  static Future<List<Map<String, dynamic>>> fetchPendingCommands(String devId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

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

    final response = await http.post(
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
      return results;
    } else {
      throw Exception('Failed to fetch commands: ${response.body}');
    }
  }

  /// ดึงข้อมูลงาน Pickup ที่หมดอายุ (เก่ากว่า minutesOld)
  static Future<List<String>> fetchExpiredPickupJobs(int minutesOld) async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

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

    final response = await http.post(
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
      return results;
    } else {
      throw Exception('Failed to fetch expired pickup jobs: ${response.body}');
    }
  }

  /// ดึงข้อมูลงานนับสต็อก (Stock Check Jobs)
  static Future<List<Map<String, dynamic>>> fetchStockCheckJobs() async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

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

    final response = await http.post(
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
      return results;
    } else {
      throw Exception('Failed to fetch stock check jobs: ${response.body}');
    }
  }

  /// ค้นหา Customer จากเบอร์โทร
  static Future<String?> findCustomerByPhone(String phone) async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

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

    final response = await http.post(
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
          return name?.split('/').last;
        }
      }
      return null;
    } else {
      throw Exception('Failed to find customer: ${response.body}');
    }
  }

  /// สร้างเอกสารใหม่ใน Firestore (ใช้สำหรับ createDeliveryJob)
  static Future<String?> createDocument(String collection, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

    final payload = {"fields": _encodeFields(data)};

    final response = await http.post(
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
      return name?.split('/').last;
    } else {
      throw Exception('Failed to create doc: ${response.body}');
    }
  }

  /// อัปเดตเอกสารใน Firestore (ใช้สำหรับ updateJob)
  static Future<void> updateDocument(String collection, String docId, Map<String, dynamic> updates) async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

    // Convert Dart Map to Firestore Document Format
    final fields = <String, dynamic>{};
    updates.forEach((key, value) {
      fields[key] = _encodeValue(value);
    });

    final payload = {"fields": fields};
    final updateMask = updates.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');

    final response = await http.patch(
      Uri.parse('$baseUrl/$collection/$docId?$updateMask'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update doc: ${response.body}');
    }
  }

  /// ลบเอกสารจาก Firestore (ใช้สำหรับลบ Job)
  static Future<void> deleteDocument(String collection, String docId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No Auth Token');

    final response = await http.delete(
      Uri.parse('$baseUrl/$collection/$docId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete doc: ${response.body}');
    }
  }
}
