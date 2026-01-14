import 'package:flutter/material.dart';

enum DateRangeType {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  custom,
}

class DateRangeHelper {
  static String getLabel(DateRangeType type) {
    switch (type) {
      case DateRangeType.today:
        return 'วันนี้';
      case DateRangeType.yesterday:
        return 'เมื่อวาน';
      case DateRangeType.last7Days:
        return '7 วันย้อนหลัง';
      case DateRangeType.last30Days:
        return '30 วันย้อนหลัง';
      case DateRangeType.thisMonth:
        return 'เดือนนี้';
      case DateRangeType.custom:
        return 'กำหนดเอง';
    }
  }

  static DateTimeRange getDateRange(DateRangeType type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (type) {
      case DateRangeType.today:
        return DateTimeRange(
            start: today,
            end: today
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1)));
      case DateRangeType.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(
            start: yesterday,
            end: yesterday
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1)));
      case DateRangeType.last7Days:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 6)),
            end: today
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1)));
      case DateRangeType.last30Days:
        return DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: today
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1)));
      case DateRangeType.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: startOfMonth, end: endOfMonth);
      case DateRangeType.custom:
        return DateTimeRange(
            start: today,
            end: today
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1)));
    }
  }
}
