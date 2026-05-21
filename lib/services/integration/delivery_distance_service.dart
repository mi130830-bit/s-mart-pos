import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../logger_service.dart';

class DeliveryDistanceService {
  /// ดึงระยะทางถนนจริงเส้นทางเดียว (กิโลเมตร) × 2 สำหรับไปกลับ
  /// Fallback: Haversine × 1.4 (road factor) × 2 ถ้า OSRM ไม่ตอบ
  Future<double> getRoadDistanceRoundTrip(
      double lat1, double lon1, double lat2, double lon2) async {
    try {
      // OSRM: lon,lat order (!สำคัญ)
      final url =
          'http://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=false';
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'POS-Desktop/1.0');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(const Utf8Decoder()).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final routes = json['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final distanceM = (routes[0]['distance'] as num).toDouble();
          final oneWayKm = distanceM / 1000.0;
          LoggerService.info('DeliveryDistance', 'OSRM: ${oneWayKm.toStringAsFixed(2)} km × 2 = ${(oneWayKm * 2).toStringAsFixed(2)} km (RT)');
          return oneWayKm * 2; // ไปกลับ
        }
      }
    } catch (e) {
      LoggerService.error('DeliveryDistance', 'OSRM failed — falling back to Haversine ×1.4 ×2', e);
    }
    // Fallback: เส้นตรง × 1.4 (road factor) × 2 (ไปกลับ)
    return haversineDistance(lat1, lon1, lat2, lon2) * 1.4 * 2;
  }

  /// คำนวณระยะทางเส้นตรงระหว่าง 2 พิกัด GPS (กิโลเมตร)
  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0;
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);
}
