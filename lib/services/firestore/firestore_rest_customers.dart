part of '../firestore_rest_service.dart';

extension FirestoreRestCustomers on FirestoreRestService {
  Future<FirestoreResult<String?>> getCustomerByPhone(String phone) async {
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

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getCustomerByPhone',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    if (data is List<dynamic>) {
      for (var item in data) {
        if (item.containsKey('document')) {
          final doc = item['document'];
          final name = doc['name'] as String?;
          final docId = name?.split('/').last;
          LoggerService.debug('FirestoreREST', 'REST Response: POST /customers:runQuery - Success (Found customer: $docId)');
          return FirestoreResult.success(docId);
        }
      }
    }
    LoggerService.debug('FirestoreREST', 'REST Response: POST /customers:runQuery - Success (No customer found)');
    return FirestoreResult.success(null);
  }
}
