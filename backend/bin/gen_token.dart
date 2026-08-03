import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

void main() {
  final jwt = JWT({'uid': 'test_admin', 'role': 'admin'});
  final token = jwt.sign(SecretKey('s_link_pos_secret_key_2026'));
  print(token);
}
