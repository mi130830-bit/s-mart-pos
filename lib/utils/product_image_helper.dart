import 'dart:io';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class ProductImageHelper {
  /// Resolves an ImageProvider for a product image.
  /// Supports:
  /// - Full HTTP/HTTPS URLs (e.g. https://api.namecheap.work/public/products/...)
  /// - Relative public URLs (e.g. /public/products/...) -> prepends SettingsService().apiUrl base
  /// - Local file paths on disk (e.g. C:\... or local path)
  static ImageProvider? getImageProvider(String? rawUrl, {File? localFile}) {
    if (localFile != null && localFile.existsSync()) {
      return FileImage(localFile);
    }
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return null;
    }
    final trimmed = rawUrl.trim();

    // 1. Full HTTP/HTTPS URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    // 2. Relative public URL starting with /public/ or public/ or /
    if (trimmed.startsWith('/public/') ||
        trimmed.startsWith('public/') ||
        trimmed.startsWith('/')) {
      try {
        final String rawApiUrl = SettingsService().apiUrl;
        final String base =
            rawApiUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
        final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
        final fullUrl = '$base$cleanPath';
        return NetworkImage(fullUrl);
      } catch (e) {
        debugPrint('⚠️ Error resolving relative image URL: $e');
      }
    }

    // 3. Absolute local file path
    final file = File(trimmed);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return null;
  }
}
