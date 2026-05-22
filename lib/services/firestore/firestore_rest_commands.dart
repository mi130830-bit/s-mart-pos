part of '../firestore_rest_service.dart';

extension FirestoreRestCommands on FirestoreRestService {
  Future<FirestoreResult<List<Map<String, dynamic>>>> getPendingCommands(String devId) async {
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

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getPendingCommands',
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
    LoggerService.debug('FirestoreREST', 'REST Response: POST /commands:runQuery - Success (${results.length} commands)');
    return FirestoreResult.success(results);
  }
}
