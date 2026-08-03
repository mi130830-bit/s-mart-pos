import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:8080/api/v1/config/promptpay'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    print('API Response: $body');
  } catch(e) {
    print('API Error: $e');
  }
}
