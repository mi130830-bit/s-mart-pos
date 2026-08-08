import 'package:flutter/material.dart';

enum DateRangeType {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

class DateRangeHelper {
  static String getLabel(DateRangeType type) {
    switch (type) {
      case DateRangeType.today:
        return 'วันนี้';
      case DateRangeType.thisWeek:
        return 'สัปดาห์นี้';
      case DateRangeType.thisMonth:
        return 'เดือนนี้';
      case DateRangeType.thisYear:
        return 'ปีนี้';
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
      case DateRangeType.thisWeek:
        return DateTimeRange(
            start: today.subtract(Duration(days: today.weekday - 1)),
            end: today
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1)));
      case DateRangeType.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: startOfMonth, end: _endOfToday(today));
      case DateRangeType.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: _endOfToday(today),
        );
      case DateRangeType.custom:
        return DateTimeRange(
            start: today,
            end: today
                .add(const Duration(days: 1))
                .subtract(const Duration(seconds: 1)));
    }
  }

  static DateTimeRange normalize(DateTimeRange range) => DateTimeRange(
        start: DateTime(range.start.year, range.start.month, range.start.day),
        end: DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        ),
      );

  static DateTime _endOfToday(DateTime today) =>
      today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
}
