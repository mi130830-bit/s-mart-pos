part of '../firestore_rest_service.dart';

extension FirestoreRestAdvance on FirestoreRestService {
  Future<FirestoreResult<List<Map<String, dynamic>>>> getAdvanceMoneyRequests() async {
    final payload = {
      "structuredQuery": {
        "from": [{"collectionId": "advance_money_requests"}],
      }
    };

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getAdvanceMoneyRequests',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    final results = <Map<String, dynamic>>[];
    if (data is List<dynamic>) {
      for (var item in data) {
        if (item.containsKey('document')) {
          final mappedDoc = _parseDocument(item['document'] as Map<String, dynamic>);
          results.add(mappedDoc);
        }
      }
    }
    return FirestoreResult.success(results);
  }
}
