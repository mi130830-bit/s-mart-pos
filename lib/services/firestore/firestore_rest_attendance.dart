part of '../firestore_rest_service.dart';

extension FirestoreRestAttendance on FirestoreRestService {
  Future<FirestoreResult<List<Map<String, dynamic>>>> getAttendanceLogs() async {
    final payload = {
      "structuredQuery": {
        "from": [{"collectionId": "attendance_logs"}],
      }
    };

    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}:runQuery'),
      payload: payload,
      logPrefix: 'getAttendanceLogs',
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
