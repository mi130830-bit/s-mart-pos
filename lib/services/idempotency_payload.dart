import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Produces a stable SHA-256 digest for an operation payload.
///
/// Maps are sorted recursively so a retry with the same business data gets the
/// same digest regardless of Dart map insertion order.
String canonicalPayloadHash(Object? payload) {
  String canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries
          .map((entry) => MapEntry(entry.key.toString(), entry.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${canonicalize(entry.value)}').join(',')}}';
    }
    if (value is Iterable) {
      return '[${value.map(canonicalize).join(',')}]';
    }
    return jsonEncode(value);
  }

  return sha256.convert(utf8.encode(canonicalize(payload))).toString();
}
