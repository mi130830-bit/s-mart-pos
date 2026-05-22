part of '../firestore_rest_service.dart';

extension FirestoreRestLogs on FirestoreRestService {
  Future<FirestoreResult<List<Map<String, dynamic>>>> getShopWorkLogs() async {
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

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getShopWorkLogs',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    final results = <Map<String, dynamic>>[];
    if (data is List<dynamic>) {
      for (var item in data) {
        if (item.containsKey('document')) {
          final mappedDoc = _parseDocument(item['document'] as Map<String, dynamic>);
          if (mappedDoc['logged_at'] is DateTime) {
            mappedDoc['created_at'] = mappedDoc['logged_at'];
          }
          results.add(mappedDoc);
        }
      }
    }
    LoggerService.debug('FirestoreREST', 'REST Response: POST /shop_work_logs:runQuery - Success (${results.length} logs)');
    return FirestoreResult.success(results);
  }
}
