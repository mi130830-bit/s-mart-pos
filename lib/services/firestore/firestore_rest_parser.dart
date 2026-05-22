part of '../firestore_rest_service.dart';

extension FirestoreRestParser on FirestoreRestService {
  /// แปลง Firestore Value Type เป็น Dart Type
  dynamic _parseValue(Map<String, dynamic>? valueMap) {
    if (valueMap == null) return null;
    
    if (valueMap.containsKey('stringValue')) return valueMap['stringValue'];
    if (valueMap.containsKey('integerValue')) return int.tryParse(valueMap['integerValue'].toString());
    if (valueMap.containsKey('doubleValue')) return double.tryParse(valueMap['doubleValue'].toString());
    if (valueMap.containsKey('booleanValue')) return valueMap['booleanValue'];
    if (valueMap.containsKey('timestampValue')) {
      try {
        return DateTime.parse(valueMap['timestampValue'].toString()).toLocal();
      } catch (e) {
        return DateTime.now();
      }
    }
    if (valueMap.containsKey('nullValue')) return null;
    
    if (valueMap.containsKey('mapValue')) {
      final fields = valueMap['mapValue']['fields'] as Map<String, dynamic>?;
      if (fields == null) return <String, dynamic>{};
      final result = <String, dynamic>{};
      fields.forEach((k, v) {
        result[k] = _parseValue(v as Map<String, dynamic>);
      });
      return result;
    }
    
    if (valueMap.containsKey('arrayValue')) {
      final values = valueMap['arrayValue']['values'] as List<dynamic>?;
      if (values == null) return [];
      return values.map((v) => _parseValue(v as Map<String, dynamic>)).toList();
    }
    
    if (valueMap.containsKey('geoPointValue')) {
      return valueMap['geoPointValue']; // { "latitude": x, "longitude": y }
    }
    
    return null;
  }

  /// แปลง Firestore Document ให้เป็น Map ปกติ
  Map<String, dynamic> _parseDocument(Map<String, dynamic> doc) {
    final result = <String, dynamic>{};
    
    final name = doc['name'] as String?;
    if (name != null) {
      result['id'] = name.split('/').last;
    }

    final fields = doc['fields'] as Map<String, dynamic>?;
    if (fields != null) {
      fields.forEach((key, valueMap) {
        result[key] = _parseValue(valueMap as Map<String, dynamic>);
      });
    }
    
    return result;
  }

  /// แปลง Dart value เป็น Firestore REST format
  dynamic _encodeValue(dynamic value) {
    if (value == null) return {"nullValue": null};
    if (value is String) return {"stringValue": value};
    if (value is int) return {"integerValue": value.toString()};
    if (value is double) return {"doubleValue": value};
    if (value is bool) return {"booleanValue": value};
    if (value is DateTime) return {"timestampValue": value.toUtc().toIso8601String()};
    if (value is Map && value.containsKey('latitude') && value.containsKey('longitude')) {
      return {
        "geoPointValue": {
          "latitude": value['latitude'],
          "longitude": value['longitude']
        }
      };
    }
    if (value is Map<String, dynamic>) {
      return {
        "mapValue": {
          "fields": value.map((k, v) => MapEntry(k, _encodeValue(v)))
        }
      };
    }
    if (value is Map) {
      final strMap = value.cast<String, dynamic>();
      return {
        "mapValue": {
          "fields": strMap.map((k, v) => MapEntry(k, _encodeValue(v)))
        }
      };
    }
    if (value is List) {
      return {
        "arrayValue": {
          "values": value.map((v) => _encodeValue(v)).toList()
        }
      };
    }
    return {"stringValue": value.toString()};
  }

  /// แปลง Dart Map ทั้งหมดเป็น Firestore fields format
  Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _encodeValue(value)));
  }
}
