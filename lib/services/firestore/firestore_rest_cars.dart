part of '../firestore_rest_service.dart';

extension FirestoreRestCars on FirestoreRestService {
  Future<FirestoreResult<List<Map<String, dynamic>>>> getCars() async {
    final response = await _sendRequest(
      method: 'GET',
      uri: Uri.parse('${FirestoreRestService.baseUrl}/cars'),
      logPrefix: 'getCars',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    final docs = data?['documents'] as List<dynamic>? ?? [];
    final list = docs.map((d) => _parseDocument(d as Map<String, dynamic>)).toList();
    LoggerService.debug('FirestoreREST', 'REST Response: GET /cars - Success (${list.length} cars)');
    return FirestoreResult.success(list);
  }
}
