import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleDriveService {
  // NOTE: Replace with User's Client ID from Google Cloud Console
  // See: https://console.cloud.google.com/
  static const _clientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
  static const _scopes = [drive.DriveApi.driveFileScope];

  drive.DriveApi? _driveApi;

  Future<bool> authenticate() async {
    try {
      if (_driveApi != null) return true;

      final client = ClientId(_clientId, '');

      // Note: This is a simplified flow. For production desktop apps,
      // you might need a local server or loopback flow to capture the token automatically.
      // Here we use a flow that prompts user in browser.

      // Since this is a Desktop app, autoObtainClientId might block or need callbacks.
      // For simplicity in this iteration, we focus on the structure.
      // A more robust way is using `clientViaUserConsent`

      final authClient = await clientViaUserConsent(client, _scopes, (url) {
        debugPrint('Please go to the following URL and grant access:');
        debugPrint('  => $url');
        launchUrl(Uri.parse(url));
      });

      _driveApi = drive.DriveApi(authClient);
      return true;
    } catch (e) {
      debugPrint('Error authenticating Drive: $e');
      return false;
    }
  }

  Future<bool> uploadBackup(File file) async {
    try {
      if (_driveApi == null) {
        final success = await authenticate();
        if (!success) return false;
      }

      var media = drive.Media(file.openRead(), await file.length());
      var driveFile = drive.File();
      driveFile.name = file.uri.pathSegments.last;

      // Optional: Upload to specific folder
      // driveFile.parents = ['folder_id'];

      await _driveApi!.files.create(driveFile, uploadMedia: media);
      debugPrint('Uploaded to Drive: ${driveFile.name}');
      return true;
    } catch (e) {
      debugPrint('Error uploading to Drive: $e');
      return false;
    }
  }

  bool get isAuthenticated => _driveApi != null;
}
