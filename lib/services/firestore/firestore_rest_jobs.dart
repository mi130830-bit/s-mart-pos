part of '../firestore_rest_service.dart';

extension FirestoreRestJobs on FirestoreRestService {
  Future<FirestoreResult<List<Map<String, dynamic>>>> getActiveDeliveryJobs() async {
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

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getActiveDeliveryJobs',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    final results = <Map<String, dynamic>>[];
    if (data is List<dynamic>) {
      for (var item in data) {
        if (item.containsKey('document')) {
          results.add(_parseDocument(item['document'] as Map<String, dynamic>));
        }
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
  }

  Future<FirestoreResult<List<Map<String, dynamic>>>> getArchivableJobs() async {
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

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getArchivableJobs',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    final results = <Map<String, dynamic>>[];
    if (data is List<dynamic>) {
      for (var item in data) {
        if (item.containsKey('document')) {
          results.add(_parseDocument(item['document'] as Map<String, dynamic>));
        }
      }
    }
    LoggerService.debug('FirestoreREST', 'REST Response: POST /jobs:runQuery (Archivable) - Success (${results.length} jobs)');
    return FirestoreResult.success(results);
  }

  Future<FirestoreResult<List<String>>> getExpiredPickupJobs(int minutesOld) async {
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

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getExpiredPickupJobs',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    final results = <String>[];
    if (data is List<dynamic>) {
      for (var item in data) {
        if (item.containsKey('document')) {
          final name = item['document']['name'] as String?;
          if (name != null) results.add(name.split('/').last);
        }
      }
    }
    LoggerService.debug('FirestoreREST', 'REST Response: POST /jobs:runQuery (Expired Pickup) - Success (${results.length} jobs)');
    return FirestoreResult.success(results);
  }

  Future<FirestoreResult<List<Map<String, dynamic>>>> getStockCheckJobs() async {
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

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getStockCheckJobs',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    final results = <Map<String, dynamic>>[];
    if (data is List<dynamic>) {
      for (var item in data) {
        if (item.containsKey('document')) {
          results.add(_parseDocument(item['document'] as Map<String, dynamic>));
        }
      }
    }
    LoggerService.debug('FirestoreREST', 'REST Response: POST /jobs:runQuery (Stock Check) - Success (${results.length} jobs)');
    return FirestoreResult.success(results);
  }
}
