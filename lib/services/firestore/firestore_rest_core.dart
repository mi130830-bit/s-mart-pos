part of '../firestore_rest_service.dart';

extension FirestoreRestCore on FirestoreRestService {
  Future<FirestoreResult<String?>> addDocument(String collection, Map<String, dynamic> data) async {
    final payload = {"fields": _encodeFields(data)};
    final response = await _sendRequest(
      method: 'POST',
      uri: Uri.parse('${FirestoreRestService.baseUrl}/$collection'),
      payload: payload,
      logPrefix: 'addDocument',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);

    final json = response.data;
    final name = json?['name'] as String?;
    final docId = name?.split('/').last;
    if (docId != null) {
      LoggerService.debug('FirestoreREST', 'REST Response: POST /$collection - Success (Created: $docId)');
    }
    return FirestoreResult.success(docId);
  }

  Future<FirestoreResult<void>> setDocument(String collection, String docId, Map<String, dynamic> updates) async {
    final fields = <String, dynamic>{};
    updates.forEach((key, value) {
      fields[key] = _encodeValue(value);
    });

    final payload = {"fields": fields};
    final updateMask = updates.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');

    final response = await _sendRequest(
      method: 'PATCH',
      uri: Uri.parse('${FirestoreRestService.baseUrl}/$collection/$docId?$updateMask'),
      payload: payload,
      logPrefix: 'setDocument',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);
    return FirestoreResult.success(null);
  }

  Future<FirestoreResult<void>> removeDocument(String collection, String docId) async {
    final response = await _sendRequest(
      method: 'DELETE',
      uri: Uri.parse('${FirestoreRestService.baseUrl}/$collection/$docId'),
      logPrefix: 'removeDocument',
    );

    if (!response.isSuccess) return FirestoreResult.failure(response.errorMessage);
    return FirestoreResult.success(null);
  }
}
