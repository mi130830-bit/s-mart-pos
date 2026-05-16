import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'firestore_rest_service.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/delivery_history_repository.dart';
import '../services/settings_service.dart';

class ExcelExportService {
  final DeliveryHistoryRepository _repo;

  ExcelExportService({DeliveryHistoryRepository? repo})
      : _repo = repo ?? DeliveryHistoryRepository();

  // ✅ Main export method — รับข้อมูลที่โหลดจาก MySQL แล้ว แยก Sheet ตามรถ
  Future<bool> exportDeliveryReport(
    List<Map<String, dynamic>> records,
    DateTime startDate,
    DateTime endDate, {
    List<Map<String, dynamic>>? allVehicles,
  }) async {
    try {
      if (records.isEmpty) {
        debugPrint('⚠️ [ExcelExport] No records to export.');
        return false;
      }

      // Group by Vehicle (แยก Sheet ตามรถ)
      final Map<String, List<Map<String, dynamic>>> groupedJobs = {};
      for (var record in records) {
        String vehicle = record['vehiclePlate']?.toString().trim().toUpperCase() ?? '';
        String driver = record['driverName']?.toString().trim() ?? '';

        // 🛠️ Fallback for old data: If vehicle is empty but driver contains common truck names
        if (vehicle.isEmpty && driver.contains(',')) {
          final parts = driver.split(',').map((e) => e.trim()).toList();
          final lastPart = parts.last;
          if (lastPart.contains('รถ') || 
              lastPart.contains('ดั้ม') || 
              lastPart.contains('กระบะ') || 
              lastPart.contains('กะบะ') || 
              lastPart.contains('ใหญ่') ||
              lastPart.contains('เล็ก') ||
              lastPart.contains('โฟล์ค') ||
              lastPart.contains('ลิฟท์')) {
            vehicle = lastPart.toUpperCase();
            // Update driver to exclude the vehicle
            driver = parts.sublist(0, parts.length - 1).join(', ');
            record['driverName'] = driver;
          }
        }

        if (vehicle.isEmpty) vehicle = 'ไม่ระบุรถ';

        // ✅ Normalize vehicle name using allVehicles (Bidirectional match)
        List<Map<String, dynamic>>? vehiclesToUse = allVehicles;
        // Auto-fetch if not provided
        if (vehiclesToUse == null || vehiclesToUse.isEmpty) {
          try {
            List<Map<String, dynamic>> carsData = [];
            if (defaultTargetPlatform == TargetPlatform.windows) {
              carsData = await FirestoreRestService.fetchCars();
            } else {
              final snapshot = await FirebaseFirestore.instance.collection('cars').get();
              carsData = snapshot.docs.map((d) => d.data()).toList();
            }

            vehiclesToUse = carsData.map((data) {
              return {
                'vehicle_type': data['name']?.toString() ?? '',
                'vehicle_plate': data['licensePlate']?.toString() ?? '',
              };
            }).toList();
          } catch (_) {
            vehiclesToUse = []; // fallback empty
          }
        }

        if (vehiclesToUse.isNotEmpty) {
          final baseV = vehicle;
          try {
            final matched = vehiclesToUse.firstWhere((v) {
              final n = v['vehicle_type']?.toString().toUpperCase() ?? '';
              final p = v['vehicle_plate']?.toString().toUpperCase() ?? '';
              if (n.isNotEmpty && n == baseV) return true;
              if (p.isNotEmpty && p == baseV) return true;
              if (n.isNotEmpty && baseV.contains(n)) return true;
              if (p.isNotEmpty && baseV.contains(p)) return true;
              if (baseV.isNotEmpty && n.contains(baseV)) return true;
              if (baseV.isNotEmpty && p.contains(baseV)) return true;
              return false;
            });
            // Use the Firestore name to guarantee uniqueness across sheets
            final type = matched['vehicle_type']?.toString() ?? '';
            final plate = matched['vehicle_plate']?.toString() ?? '';
            if (type.isNotEmpty && plate.isNotEmpty && type != plate && !type.contains(plate)) {
               vehicle = '$type $plate';
            } else if (type.isNotEmpty) {
               vehicle = type;
            } else if (plate.isNotEmpty) {
               vehicle = plate;
            }
          } catch (_) {
            // Not found, preserve original vehicle string
          }
        }

        // Clean up for Excel sheet names
        String sheetName = vehicle.replaceAll(RegExp(r'[\\/:*?"<>|\[\]]'), '_');
        if (sheetName.length > 31) sheetName = sheetName.substring(0, 31);
        
        groupedJobs.putIfAbsent(sheetName, () => []).add(record);
      }

      var excel = Excel.createExcel();
      excel.delete('Sheet1'); // ลบ sheet เริ่มต้น



      for (final entry in groupedJobs.entries) {
        final sheetName = entry.key;
        final logs = entry.value;

        final Sheet sheet = excel[sheetName];

        // ── Header Row (ตรงกับ S-Link ต้นแบบเป๊ะๆ) ──
        final headers = [
          'วันที่',
          'ลูกค้า',
          'สถานที่ส่ง',
          'เบอร์โทร',
          'คนขับ/รถ',
          'ยอดเงิน',
          'Google Maps ลิงก์',
          'เลขบิล (POS)',     // Extra info for POS
          'ระยะทาง (กม.)',    // Extra info for POS
          'ต้นทุนน้ำมัน (฿)',   // Logistics module
        ];

        for (int i = 0; i < headers.length; i++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
          cell.value = TextCellValue(headers[i]);
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
            fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          );
        }

        // ── Data Rows ──────────────────────────────────────
        int rowIndex = 1;
        double subtotal = 0;
        double totalDistance = 0;
        double totalFuelCost = 0;
        for (var record in logs) {
          // A: วันที่ (รวมเวลาเหมือน S-Link)
          String dateStr = '';
          final rawDate = record['completedAt']?.toString() ?? '';
          if (rawDate.isNotEmpty) {
            try {
              final dt = DateTime.parse(rawDate);
              dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
            } catch (_) {
              dateStr = rawDate;
            }
          }

          final double amount =
              double.tryParse(record['totalAmount']?.toString() ?? '0') ?? 0.0;
          subtotal += amount;

          final String customerName = record['customerName']?.toString() ?? '';
          final String address = record['customerAddress']?.toString() ?? '';
          final String phone = record['customerPhone']?.toString() ?? '-';
          
          String driverLabel = 'ไม่ระบุ';
          String vehicle = record['vehiclePlate']?.toString().trim() ?? '';
          String driver = record['driverName']?.toString().trim() ?? '';
          if (driver.isNotEmpty && vehicle.isNotEmpty) {
            driverLabel = '$driver ($vehicle)';
          } else if (driver.isNotEmpty) {
            driverLabel = driver;
          } else if (vehicle.isNotEmpty) {
            driverLabel = vehicle;
          }
          
          String mapLink = '-';
          final String gpsUrl = record['locationUrl']?.toString() ?? '';
          if (gpsUrl.isNotEmpty) {
             mapLink = gpsUrl;
          }
          
          final double distanceKm = double.tryParse(record['distanceKm']?.toString() ?? '0') ?? 0.0;
          // ✅ คำนวณจากอัตราตั้งค่าปัจจุบัน (ไม่ใช้ค่าเก่าที่บันทึกไว้)
          final double fuelCost = distanceKm > 0 ? distanceKm * SettingsService().fuelCostPerKm : 0.0;
          totalDistance += distanceKm;
          totalFuelCost += fuelCost;

          final rowValues = [
            dateStr,                                              // A: วันที่
            customerName,                                         // B: ลูกค้า
            address,                                              // C: สถานที่ส่ง
            phone,                                                // D: เบอร์โทร
            driverLabel,                                          // E: คนขับ/รถ
            amount,                                               // F: ยอดเงิน
            mapLink,                                              // G: Google Maps (handled separately)
            "'${record['orderId']?.toString() ?? ''}",            // H: เลขบิล
            distanceKm > 0 ? distanceKm : '-',                    // I: ระยะทาง (กม.)
            fuelCost > 0 ? fuelCost : '-',                        // J: ต้นทุนน้ำมัน
          ];

          for (int col = 0; col < rowValues.length; col++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(
                columnIndex: col, rowIndex: rowIndex));

            // ── Column G: GPS Hyperlink ──────────────────────
            if (col == 6) {
              if (mapLink.startsWith('http')) {
                // HYPERLINK formula: =HYPERLINK("url", "label") — กดได้ใน Excel
                cell.value = FormulaCellValue('HYPERLINK("$mapLink","📍 เปิดแผนที่")');
                cell.cellStyle = CellStyle(
                  fontColorHex: ExcelColor.fromHexString('#0563C1'),
                  underline: Underline.Single,
                );
              } else {
                cell.value = TextCellValue('-');
              }
              continue;
            }

            final val = rowValues[col];
            if (val is double) {
              cell.value = DoubleCellValue(val);
            } else if (val is int) {
              cell.value = IntCellValue(val);
            } else {
              cell.value = TextCellValue(val.toString());
            }
          }
          rowIndex++;
        }

        // ── Summary Row ────────────────────────────────────
        rowIndex++;
        final totalLabelCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)); // col E (คนขับ/รถ)
        totalLabelCell.value = TextCellValue('ยอดรวม ${logs.length} งาน');
        totalLabelCell.cellStyle = CellStyle(bold: true);

        final totalAmountCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)); // col F (ยอดเงิน)
        totalAmountCell.value = DoubleCellValue(subtotal);
        totalAmountCell.cellStyle = CellStyle(bold: true);

        final totalDistanceCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)); // col I (ระยะทาง)
        totalDistanceCell.value = DoubleCellValue(totalDistance);
        totalDistanceCell.cellStyle = CellStyle(bold: true);

        final totalFuelCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)); // col J (น้ำมัน)
        totalFuelCell.value = DoubleCellValue(totalFuelCost);
        totalFuelCell.cellStyle = CellStyle(bold: true);

        // ── Column Widths ────────────────────────────
        final widths = [
          16.0, // A: วันที่ (dd/MM/yyyy HH:mm)
          22.0, // B: ลูกค้า
          36.0, // C: สถานที่ส่ง
          14.0, // D: เบอร์โทร
          20.0, // E: คนขับ/รถ
          12.0, // F: ยอดเงิน
          42.0, // G: Google Maps ลิงก์
          10.0, // H: เลขบิล (POS)
          14.0, // I: ระยะทาง (กม.)
          16.0, // J: ต้นทุนน้ำมัน (฿)
        ];
        for (int i = 0; i < widths.length; i++) {
          sheet.setColumnWidth(i, widths[i]);
        }
      }

      // ── Save & Open ────────────────────────────────────
      final dir = await getApplicationDocumentsDirectory();
      final dateFmt = DateFormat('yyyyMMdd_HHmm');
      final outputPath =
          '${dir.path}\\Delivery_Report_${dateFmt.format(DateTime.now())}.xlsx';

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        try {
          File(outputPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
        } on FileSystemException catch (fse) {
          if (fse.osError?.errorCode == 32) {
            throw Exception('ไม่สามารถบันทึกไฟล์ได้ เนื่องจากไฟล์ Excel นี้เปิดค้างไว้อยู่ กรุณาปิดไฟล์ก่อนทำการ Export ใหม่ครับ');
          }
          rethrow;
        }
        
        debugPrint('✅ [ExcelExport] Saved: $outputPath');
        OpenFile.open(outputPath);
        return true;
      }
      return false;
    } catch (e, stack) {
      debugPrint('⚠️ [ExcelExport] Error: $e\n$stack');
      throw e is Exception ? e : Exception('เกิดข้อผิดพลาดในการสร้างไฟล์: $e');
    }
  }

  // ✅ Legacy entry point (ใช้จาก Dashboard เดิม) — ดึงจาก MySQL แล้ว Export
  Future<bool> exportDeliveryHistory(DateTime start, DateTime end) async {
    try {
      final fullStart =
          DateTime(start.year, start.month, start.day, 0, 0, 0);
      final fullEnd =
          DateTime(end.year, end.month, end.day, 23, 59, 59);

      final records = await _repo.getHistoryByDateRange(fullStart, fullEnd);

      if (records.isEmpty) {
        debugPrint('⚠️ [ExcelExport] No records in MySQL for given dates.');
        return false;
      }

      return exportDeliveryReport(records, start, end);
    } catch (e, stack) {
      debugPrint('⚠️ [ExcelExport] exportDeliveryHistory error: $e\n$stack');
      return false;
    }
  }
}
