import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class FirebaseAuthVerifier {
  static final FirebaseAuthVerifier _instance = FirebaseAuthVerifier._internal();
  factory FirebaseAuthVerifier() => _instance;
  FirebaseAuthVerifier._internal();

  static const String _projectId = 'opsmate-3dde2';
  static const String _jwksUrl = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
  
  Map<String, String> _keys = {};
  DateTime? _keysExpiration;

  /// Fetch and cache the public keys from Google
  Future<void> _refreshKeys() async {
    try {
      final response = await http.get(Uri.parse(_jwksUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _keys = data.map((key, value) => MapEntry(key, value.toString()));

        // Parse Cache-Control header to set expiration
        final cacheControl = response.headers['cache-control'];
        int maxAge = 3600; // default 1 hour
        if (cacheControl != null && cacheControl.contains('max-age=')) {
          final match = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
          if (match != null) {
            maxAge = int.tryParse(match.group(1) ?? '3600') ?? 3600;
          }
        }
        _keysExpiration = DateTime.now().add(Duration(seconds: maxAge));
      } else {
        throw Exception('Failed to fetch JWKS: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ FirebaseAuthVerifier Error fetching keys: $e');
      rethrow;
    }
  }

  /// Verifies a Firebase ID token and returns the decoded payload if valid
  Future<Map<String, dynamic>?> verify(String token) async {
    try {
      // 1. Decode token without verifying to get header (kid)
      final unverifiedJwt = JWT.decode(token);
      final kid = unverifiedJwt.header?['kid'];

      if (kid == null) {
        print('⚠️ FirebaseAuthVerifier: Token missing kid in header');
        return null;
      }

      // 2. Refresh keys if expired or kid is unknown
      if (_keysExpiration == null || DateTime.now().isAfter(_keysExpiration!) || !_keys.containsKey(kid)) {
        await _refreshKeys();
      }

      final certificateString = _keys[kid];
      if (certificateString == null) {
        print('⚠️ FirebaseAuthVerifier: Unknown kid $kid even after refresh');
        return null;
      }

      // 3. Verify Signature using RSAPublicKey
      final jwt = JWT.verify(
        token,
        RSAPublicKey(certificateString),
        issueAt: Duration(seconds: 0), // Allow iat check
      );

      final payload = jwt.payload;

      // 4. Validate Audience (aud) and Issuer (iss)
      final aud = payload['aud'];
      final iss = payload['iss'];
      final exp = payload['exp'];

      if (aud != _projectId) {
        print('⚠️ FirebaseAuthVerifier: Invalid aud: $aud');
        return null;
      }

      if (iss != 'https://securetoken.google.com/$_projectId') {
        print('⚠️ FirebaseAuthVerifier: Invalid iss: $iss');
        return null;
      }

      // 5. Validate Expiration (exp)
      if (exp != null) {
        final expTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expTime)) {
          print('⚠️ FirebaseAuthVerifier: Token expired');
          return null;
        }
      }

      return payload; // Validation passed
    } catch (e) {
      print('⚠️ FirebaseAuthVerifier: Verification Failed: $e');
      return null;
    }
  }
}
