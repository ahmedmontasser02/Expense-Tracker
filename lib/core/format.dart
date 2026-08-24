import 'package:intl/intl.dart';

import 'enums.dart';

/// Money is stored and passed around as integer minor units (e.g. cents)
/// to avoid floating point drift. All UI formatting goes through here.
class MoneyFmt {
  MoneyFmt._();

  static String symbol = r'$';

  static String amount(int minorUnits) =>
      withSymbol(symbol, minorUnits);

  /// Formats using an explicit symbol — preferred inside widgets that
  /// watch [currencySymbolProvider].
  static String withSymbol(String sym, int minorUnits) {
    final f = NumberFormat.currency(symbol: sym, decimalDigits: 2);
    return f.format(minorUnits / 100);
  }

  static String signed(int minorUnits) =>
      minorUnits < 0 ? '-${amount(minorUnits.abs())}' : '+${amount(minorUnits)}';

  static String signedWith(String sym, int minorUnits) => minorUnits < 0
      ? '-${withSymbol(sym, -minorUnits)}'
      : '+${withSymbol(sym, minorUnits)}';

  static int parseToMinorUnits(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty) return 0;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return 0;
    return (value * 100).round();
  }

  /// Extracts an amount (minor units) and a cleaned note from arbitrary
  /// shared text, e.g. "Paid 250.50 for lunch at Koshary" →
  /// (25050, 'Paid 250.50 for lunch at Koshary').
  /// Handles European formatting ("1.250,50") and thousands separators.
  static (int?, String) parseSharedTransaction(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return (null, text);

    final matches = RegExp(r'\d[\d.,]*').allMatches(text).toList();
    int? amountMinor;
    for (final m in matches) {
      final token = m.group(0)!;
      final hasComma = token.contains(',');
      final hasDot = token.contains('.');
      String normalized;
      if (hasComma && hasDot) {
        // The right-most separator is the decimal one.
        normalized = token.lastIndexOf(',') > token.lastIndexOf('.')
            ? token.replaceAll('.', '').replaceAll(',', '.')
            : token.replaceAll(',', '');
      } else if (hasComma) {
        // Comma is decimal only when followed by exactly 2 digits.
        normalized = RegExp(r',\d{1,2}$').hasMatch(token)
            ? token.replaceAll(',', '.')
            : token.replaceAll(',', '');
      } else if (hasDot) {
        normalized = RegExp(r'\.\d{1,2}$').hasMatch(token) &&
                !RegExp(r'\.\d{3}(\.|$)').hasMatch(token)
            ? token
            : token.replaceAll('.', '');
      } else {
        normalized = token;
      }
      final value = double.tryParse(normalized);
      if (value != null && value > 0) {
        amountMinor = (value * 100).round();
        break;
      }
    }
    return (amountMinor, text);
  }
}

class DateX {
  DateX._();

  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

  static DateTime endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1).subtract(const Duration(microseconds: 1));

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime endOfDay(DateTime d) => startOfDay(d)
      .add(const Duration(days: 1))
      .subtract(const Duration(microseconds: 1));

  static DateTime startOfYear(int year) => DateTime(year);

  static DateTime endOfYear(int year) =>
      DateTime(year + 1).subtract(const Duration(microseconds: 1));

  /// Advances [from] by [periods] steps of [freq], clamping day-of-month
  /// for monthly/yearly steps so Jan 31 -> Feb 28 instead of overflowing.
  /// Daily/weekly steps preserve local wall-clock time across DST changes.
  static DateTime addPeriods(DateTime from, Frequency freq, int periods) {
    switch (freq) {
      case Frequency.daily:
        return _addDays(from, periods);
      case Frequency.weekly:
        return _addDays(from, 7 * periods);
      case Frequency.monthly:
        return _addMonths(from, periods);
      case Frequency.yearly:
        return _addMonths(from, 12 * periods);
    }
  }

  static DateTime _addDays(DateTime from, int days) => DateTime(
      from.year, from.month, from.day + days, from.hour, from.minute,
      from.second);

  static DateTime _addMonths(DateTime from, int months) {
    var year = from.year;
    var month = from.month + months;
    year += (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = from.day.clamp(1, lastDay);
    return DateTime(
        year, month, day, from.hour, from.minute, from.second);
  }

  static String prettyDate(DateTime d) => DateFormat.yMMMd().format(d);

  static String prettyDateTime(DateTime d) =>
      DateFormat('MMM d, yyyy • HH:mm').format(d);

  static String monthName(int month) =>
      DateFormat.MMMM().format(DateTime(2020, month));
}
