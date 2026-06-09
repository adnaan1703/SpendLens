import 'package:flutter/material.dart';

import '../../data/repositories/finance_repository.dart';

enum PeriodFilterSelectionType { allDates, month, customDateRange }

final class PeriodFilterSelection {
  const PeriodFilterSelection.allDates()
    : type = PeriodFilterSelectionType.allDates,
      month = null;

  const PeriodFilterSelection.month(DateTime this.month)
    : type = PeriodFilterSelectionType.month;

  const PeriodFilterSelection.customDateRange()
    : type = PeriodFilterSelectionType.customDateRange,
      month = null;

  final PeriodFilterSelectionType type;
  final DateTime? month;

  DateTimeRange? get dateRange {
    final selectedMonth = month;
    if (type != PeriodFilterSelectionType.month || selectedMonth == null) {
      return null;
    }

    return dateRangeForMonth(selectedMonth);
  }
}

class PeriodFilterDropdown extends StatelessWidget {
  const PeriodFilterDropdown({
    super.key,
    required this.availableMonths,
    required this.selectedRange,
    required this.onChanged,
  });

  final List<DateTime> availableMonths;
  final DateTimeRange? selectedRange;
  final ValueChanged<PeriodFilterSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = _PeriodFilterValue.fromRange(selectedRange);
    final months = _monthsWithSelection(
      availableMonths: availableMonths,
      selectedRange: selectedRange,
    );
    final items = [
      const _PeriodFilterValue.allDates(),
      for (final month in months) _PeriodFilterValue.month(month),
      const _PeriodFilterValue.customDateRange(),
    ];

    return SizedBox(
      width: 280,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Period',
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
        isEmpty: false,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_PeriodFilterValue>(
            isExpanded: true,
            value: value,
            selectedItemBuilder: (context) {
              return [
                for (final item in items)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _labelFor(item, selectedValue: value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ];
            },
            items: [
              for (final item in items)
                DropdownMenuItem(
                  value: item,
                  child: Text(_labelFor(item, selectedValue: value)),
                ),
            ],
            onChanged: (item) {
              if (item == null) return;

              switch (item.type) {
                case _PeriodFilterValueType.allDates:
                  onChanged(const PeriodFilterSelection.allDates());
                case _PeriodFilterValueType.month:
                  onChanged(PeriodFilterSelection.month(item.month!));
                case _PeriodFilterValueType.customDateRange:
                  onChanged(const PeriodFilterSelection.customDateRange());
              }
            },
          ),
        ),
      ),
    );
  }

  String _labelFor(
    _PeriodFilterValue item, {
    required _PeriodFilterValue selectedValue,
  }) {
    return switch (item.type) {
      _PeriodFilterValueType.allDates => 'All dates',
      _PeriodFilterValueType.month => formatMonth(item.month!),
      _PeriodFilterValueType.customDateRange =>
        selectedValue.type == _PeriodFilterValueType.customDateRange &&
                selectedRange != null
            ? '${dateString(selectedRange!.start)} to '
                  '${dateString(selectedRange!.end)}'
            : 'Custom date range',
    };
  }
}

DateTimeRange dateRangeForMonth(DateTime month) {
  final start = firstDayOfMonth(month);

  return DateTimeRange(
    start: start,
    end: addMonths(start, 1).subtract(const Duration(days: 1)),
  );
}

DateTime? monthForExactDateRange(DateTimeRange? range) {
  if (range == null) return null;

  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  if (start.day != 1) return null;

  final monthEnd = addMonths(start, 1).subtract(const Duration(days: 1));
  if (dateString(end) != dateString(monthEnd)) return null;

  return firstDayOfMonth(start);
}

List<DateTime> _monthsWithSelection({
  required List<DateTime> availableMonths,
  required DateTimeRange? selectedRange,
}) {
  final monthsByKey = <String, DateTime>{};
  for (final month in availableMonths) {
    final normalized = firstDayOfMonth(month);
    monthsByKey[dateString(normalized)] = normalized;
  }

  final selectedMonth = monthForExactDateRange(selectedRange);
  if (selectedMonth != null) {
    monthsByKey.putIfAbsent(dateString(selectedMonth), () => selectedMonth);
  }

  final months = monthsByKey.values.toList();
  months.sort((a, b) => b.compareTo(a));

  return months;
}

enum _PeriodFilterValueType { allDates, month, customDateRange }

final class _PeriodFilterValue {
  const _PeriodFilterValue.allDates()
    : type = _PeriodFilterValueType.allDates,
      month = null;

  const _PeriodFilterValue.month(DateTime this.month)
    : type = _PeriodFilterValueType.month;

  const _PeriodFilterValue.customDateRange()
    : type = _PeriodFilterValueType.customDateRange,
      month = null;

  factory _PeriodFilterValue.fromRange(DateTimeRange? range) {
    if (range == null) return const _PeriodFilterValue.allDates();

    final month = monthForExactDateRange(range);
    if (month != null) return _PeriodFilterValue.month(month);

    return const _PeriodFilterValue.customDateRange();
  }

  final _PeriodFilterValueType type;
  final DateTime? month;

  String get key {
    return switch (type) {
      _PeriodFilterValueType.allDates => 'all-dates',
      _PeriodFilterValueType.month => 'month-${dateString(month!)}',
      _PeriodFilterValueType.customDateRange => 'custom-date-range',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is _PeriodFilterValue &&
        other.type == type &&
        _monthKey(other.month) == _monthKey(month);
  }

  @override
  int get hashCode => Object.hash(type, _monthKey(month));

  String? _monthKey(DateTime? value) {
    return value == null ? null : dateString(firstDayOfMonth(value));
  }
}
