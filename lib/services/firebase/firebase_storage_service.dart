import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../logger_service.dart';

/// Service dedicated to Firebase Storage actions.
class FirebaseStorageService {
  /// Uploads raw PNG bill image data to Firebase Storage under the 'bills/' folder.
  Future<String?> uploadBillImage(Uint8List imageData, String jobId) async {
    try {
      final String fileName =
          'bills/${jobId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      final uploadTask = storageRef.putData(
        imageData,
        SettableMetadata(contentType: 'image/png'),
      );

      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      LoggerService.error('FirebaseStorage', 'Failed to upload Bill Image', e);
      return null;
    }
  }
}
