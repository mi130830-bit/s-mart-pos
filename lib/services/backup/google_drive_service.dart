import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../notification_service.dart';

class GoogleDriveService {
  // Google Drive Credentials
  // Configured on: 2026-01-13
  static const _clientId = 'YOUR_GOOGLE_CLIENT_ID';
  static const _clientSecret = 'YOUR_GOOGLE_CLIENT_SECRET';

  static const _scopes = [drive.DriveApi.driveFileScope];
  static const _storage = FlutterSecureStorage();

  AuthClient? _client;

  // 1. Authenticate (Load saved or Request new)
  Future<bool> authenticate() async {
    try {
      // Try verify existing credentials
      final jsonCreds = await _storage.read(key: 'gdrive_credentials');
      if (jsonCreds != null) {
        final creds = AccessCredentials.fromJson(jsonDecode(jsonCreds));
        // Use autoRefreshingClient to handle token refresh
        _client = autoRefreshingClient(
          ClientId(_clientId, _clientSecret),
          creds,
          http.Client(),
        );
        debugPrint('✅ Google Drive: Loaded saved credentials.');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Google Drive: Saved credentials invalid or expired: $e');
      await _storage.delete(
          key: 'gdrive_credentials'); // Clear if invalid format
    }

    // New Login Flow
    try {
      final id = ClientId(_clientId, _clientSecret);
      _client = await clientViaUserConsent(id, _scopes, (url) {
        _launchURL(url);
      });

      // Save Credentials
      if (_client != null && _client!.credentials.accessToken.data.isNotEmpty) {
        // AccessCredentials doesn't have a direct toJson in some versions,
        // but googleapis_auth 1.0+ supports it usually or we verify logic.
        // Actually AccessCredentials properties are exposed.
        // Let's rely on manually serializing to be safe if toJson is missing.
        // Wait, checking pubspec 'googleapis_auth: ^2.0.0'. It definitely supports JSON.
        // Checking source code or docs ideally.
        // Assuming toJson() exists or using a helper.
        // AccessCredentials.fromJson exists.
        // AccessCredentials.toJson may not exist. We construct map.
        final creds = _client!.credentials;
        final map = {
          'accessToken': {
            'data': creds.accessToken.data,
            'expiry': creds.accessToken.expiry.toIso8601String(),
            'type': creds.accessToken.type
          },
          'refreshToken': creds.refreshToken,
          'idToken': creds.idToken,
          'scopes': creds.scopes,
        };
        await _storage.write(key: 'gdrive_credentials', value: jsonEncode(map));
        debugPrint('✅ Google Drive: Authenticated and saved.');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Google Drive Auth Error: $e');
    }
    return false;
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  // 2. Upload File (Backup)
  Future<String?> uploadFile(File file, String verifyInfo) async {
    if (_client == null && !(await authenticate())) {
      return null;
    }

    try {
      final driveApi = drive.DriveApi(_client!);

      // Check if backup folder exists
      final folderId = await _getOrCreateFolder(driveApi, 'POS_Backup');

      // Upload
      final driveFile = drive.File();
      driveFile.name =
          'backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.sql';
      driveFile.parents = [folderId];
      driveFile.description =
          verifyInfo; // Store metadata like checksum or info

      final media = drive.Media(file.openRead(), file.lengthSync());
      final result = await driveApi.files.create(driveFile, uploadMedia: media);

      debugPrint('✅ Upload Success: ${result.name} (${result.id})');
      return result.id;
    } catch (e) {
      debugPrint('❌ Upload Error: $e');
      // Check for invalid_grant or auth errors
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('invalid_grant') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('status code: 401') ||
          errorStr.contains('status code: 400')) {
        debugPrint(
            '⚠️ Google Drive Token Expired/Revoked. Clearing credentials...');
        await logout();
        await NotificationService()
            .sendBackupFailedNotification('Token หมดอายุ (โปรดเชื่อมต่อใหม่)');
      }
      return null;
    }
  }

  Future<String> _getOrCreateFolder(
      drive.DriveApi api, String folderName) async {
    final q =
        "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false";
    final list = await api.files.list(q: q);

    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    // Create
    final folder = drive.File();
    folder.name = folderName;
    folder.mimeType = 'application/vnd.google-apps.folder';
    final result = await api.files.create(folder);
    return result.id!;
  }

  Future<void> logout() async {
    _client?.close();
    _client = null;
    await _storage.delete(key: 'gdrive_credentials');
  }

  // 3. Wrapper for Scheduler
  Future<bool> uploadBackup(File file) async {
    final result = await uploadFile(file, 'Auto Backup via Scheduler');
    return result != null;
  }

  // 4. List Backup Files
  Future<List<drive.File>> listBackups() async {
    if (_client == null && !(await authenticate())) {
      return [];
    }

    try {
      final driveApi = drive.DriveApi(_client!);
      // Get folder ID first
      final folderId = await _getOrCreateFolder(driveApi, 'POS_Backup');

      // Query files in folder
      final q =
          "'$folderId' in parents and trashed = false and name contains 'backup_'";
      final fileList = await driveApi.files.list(
        q: q,
        orderBy: 'createdTime desc',
        $fields: 'files(id, name, size, createdTime, description)',
      );

      return fileList.files ?? [];
    } catch (e) {
      debugPrint('❌ List Files Error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('invalid_grant') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('status code: 401') ||
          errorStr.contains('status code: 400')) {
        await logout();
        await NotificationService()
            .sendBackupFailedNotification('Token หมดอายุ (โปรดเชื่อมต่อใหม่)');
      }
      return [];
    }
  }

  // 5. Download File
  Future<File?> downloadFile(String fileId, String fileName) async {
    if (_client == null && !(await authenticate())) {
      return null;
    }

    try {
      final driveApi = drive.DriveApi(_client!);
      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Create temp file
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');

      final List<int> dataStore = [];
      await media.stream.listen((data) {
        dataStore.addAll(data);
      }).asFuture();

      await file.writeAsBytes(dataStore);
      debugPrint('✅ Download Success: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('❌ Download Error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('invalid_grant') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('status code: 401') ||
          errorStr.contains('status code: 400')) {
        await logout();
        await NotificationService()
            .sendBackupFailedNotification('Token หมดอายุ (โปรดเชื่อมต่อใหม่)');
      }
      return null;
    }
  }

  // 6. Delete File
  Future<void> deleteFile(String fileId) async {
    if (_client == null && !(await authenticate())) return;
    try {
      final driveApi = drive.DriveApi(_client!);
      await driveApi.files.delete(fileId);
      debugPrint('🗑️ Deleted Drive File: $fileId');
    } catch (e) {
      debugPrint('❌ Delete Error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('invalid_grant') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('status code: 401') ||
          errorStr.contains('status code: 400')) {
        await logout();
        await NotificationService()
            .sendBackupFailedNotification('Token หมดอายุ (โปรดเชื่อมต่อใหม่)');
      }
    }
  }

  // 7. Cleanup Old Backups (Count Based)
  Future<int> cleanupOldBackups(int maxKeep) async {
    final files = await listBackups(); // Sorted by createdTime desc
    if (files.length <= maxKeep) return 0;

    int count = 0;

    // items from index [maxKeep] to end are "old" -> delete them
    // Example: keep 10, size 12. Delete index 10, 11.
    for (int i = maxKeep; i < files.length; i++) {
      final f = files[i];
      if (f.id != null) {
        await deleteFile(f.id!);
        count++;
      }
    }

    if (count > 0) {
      debugPrint(
          '🧹 Cleaned up $count old backups from Drive (Policy: Keep $maxKeep).');
    }
    return count;
  }
}
