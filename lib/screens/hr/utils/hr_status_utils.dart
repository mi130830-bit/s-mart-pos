import 'package:flutter/material.dart';

enum HrItemType {
  leave,
  advance,
  payroll,
}

class HrStatusUtils {
  static Color getStatusColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.green;
      case 'PARTIAL': return Colors.orange;
      case 'DEDUCTED': return Colors.blue;
      case 'REJECTED': return Colors.red;
      case 'CANCELLED': return Colors.grey;
      case 'DRAFT': return Colors.grey;
      case 'CONFIRMED': return Colors.orange;
      case 'PAID': return Colors.green;
      case 'PENDING': return Colors.orange;
      default: return Colors.orange;
    }
  }

  static String formatStatus(String status, HrItemType type) {
    if (type == HrItemType.leave) {
      switch (status) {
        case 'APPROVED': return 'อนุมัติแล้ว';
        case 'REJECTED': return 'ปฏิเสธ';
        case 'CANCELLED': return 'ยกเลิก';
        default: return 'รออนุมัติ';
      }
    } else if (type == HrItemType.advance) {
      switch (status) {
        case 'APPROVED': return 'อนุมัติ (รอหัก)';
        case 'PARTIAL': return 'หักบางส่วน';
        case 'DEDUCTED': return 'หักครบแล้ว';
        case 'REJECTED': return 'ปฏิเสธ';
        default: return 'รออนุมัติ';
      }
    } else if (type == HrItemType.payroll) {
      switch (status) {
        case 'DRAFT': return 'ฉบับร่าง';
        case 'CONFIRMED': return 'ยืนยันแล้ว (รอจ่าย)';
        case 'PAID': return 'จ่ายแล้ว';
        default: return status;
      }
    }
    return status;
  }
}
