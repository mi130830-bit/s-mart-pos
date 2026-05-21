import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/delivery_history_repository.dart';
import '../../repositories/fuel_price_repository.dart';
import '../../repositories/vehicle_settings_repository.dart';
import '../../services/firestore_rest_service.dart';

/// Immutable data container for delivery dashboard query results
@immutable
class DeliveryDashboardData {
  final List<Map<String, dynamic>> records;
  final Map<String, double> priceLookup;
  final Map<String, double> efficiencyMap;
  final List<Map<String, dynamic>> vehicles;

  const DeliveryDashboardData({
    required this.records,
    required this.priceLookup,
    required this.efficiencyMap,
    required this.vehicles,
  });
}

/// Orchestrates data aggregation from multiple storage backends (Firestore + MySQL)
/// for the delivery dashboard report and analysis UI.
class DeliveryCoordinator {
  final DeliveryHistoryRepository _historyRepo;
  final FuelPriceRepository _fuelRepo;
  final VehicleSettingsRepository _vehicleRepo;

  static const double defaultEfficiency = VehicleSettingsRepository.defaultEfficiency;

  static double resolvePriceFromLookup(Map<String, double> lookup, DateTime date) {
    return FuelPriceRepository.resolvePriceFromLookup(lookup, date);
  }

  DeliveryCoordinator({
    DeliveryHistoryRepository? historyRepo,
    FuelPriceRepository? fuelRepo,
    VehicleSettingsRepository? vehicleRepo,
  })  : _historyRepo = historyRepo ?? DeliveryHistoryRepository(),
        _fuelRepo = fuelRepo ?? FuelPriceRepository(),
        _vehicleRepo = vehicleRepo ?? VehicleSettingsRepository();

  /// Loads and merges vehicle settings, remote Firestore active fleets,
  /// archived histories in date range, fuel prices, and fuel efficiencies.
  Future<DeliveryDashboardData> loadDashboardData(DateTime startDate, DateTime endDate) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    // ── 1. ดึงรถจาก MySQL vehicle_settings (Base) ──
    final vehicleResult = await _vehicleRepo.getAllVehicles();
    final Map<String, Map<String, dynamic>> vehicleMap = {};
    for (final v in vehicleResult) {
      final plate = v['vehicle_plate']?.toString().trim().toUpperCase() ?? '';
      if (plate.isNotEmpty) vehicleMap[plate] = Map<String, dynamic>.from(v);
    }

    // ── 2. Merge กับ Firestore cars collection (Source of Truth) ──
    try {
      List<Map<String, dynamic>> carsData = [];
      if (defaultTargetPlatform == TargetPlatform.windows) {
        carsData = await FirestoreRestService.fetchCars();
      } else {
        final snapshot = await FirebaseFirestore.instance.collection('cars').orderBy('name').get();
        carsData = snapshot.docs.map((d) => d.data()).toList();
      }
      
      for (final data in carsData) {
        final name = data['name']?.toString().trim() ?? '';
        final plate = data['licensePlate']?.toString().trim().toUpperCase() ?? '';
        if (plate.isEmpty && name.isEmpty) continue;

        final key = plate.isNotEmpty ? plate : name.toUpperCase();
        if (vehicleMap.containsKey(key)) {
          if ((vehicleMap[key]!['vehicle_type']?.toString() ?? '').isEmpty && name.isNotEmpty) {
            vehicleMap[key]!['vehicle_type'] = name;
          }
        } else {
          vehicleMap[key] = {
            'vehicle_plate': plate.isNotEmpty ? plate : name,
            'vehicle_type': name,
            'fuel_efficiency': 7.0, // Default efficiency fallback
          };
        }
      }
    } catch (e) {
      debugPrint('⚠️ [DeliveryCoordinator] Firestore cars load failed: $e');
    }

    final mergedVehicles = vehicleMap.values.toList()
      ..sort((a, b) {
        final pa = a['vehicle_plate']?.toString() ?? '';
        final pb = b['vehicle_plate']?.toString() ?? '';
        return pa.compareTo(pb);
      });

    // ── 3. Fetch history, fuel price lookup, and efficiency map concurrently ──
    final results = await Future.wait([
      _historyRepo.getHistoryByDateRange(start, end),
      _fuelRepo.buildPriceLookup(start, end),
      _vehicleRepo.getEfficiencyMap(),
    ]);

    return DeliveryDashboardData(
      records: results[0] as List<Map<String, dynamic>>,
      priceLookup: results[1] as Map<String, double>,
      efficiencyMap: results[2] as Map<String, double>,
      vehicles: mergedVehicles,
    );
  }
}
