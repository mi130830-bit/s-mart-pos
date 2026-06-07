part of '../firestore_rest_service.dart';

extension FirestoreRestUsers on FirestoreRestService {
  Future<FirestoreResult<List<Map<String, dynamic>>>> getSLinkUsers() async {
    final response = await _sendRequest(
      method: 'GET',
      uri: Uri.parse('${FirestoreRestService.baseUrl}/users'),
      logPrefix: 'getSLinkUsers',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final data = response.data;
    final results = <Map<String, dynamic>>[];
    if (data is Map && data.containsKey('documents')) {
      final docs = data['documents'] as List<dynamic>;
      for (var doc in docs) {
        results.add(_parseDocument(doc as Map<String, dynamic>));
      }
    }
    return FirestoreResult.success(results);
  }
}
