import 'package:decimal/decimal.dart';

/// Shared money formatting — `$2,393.92`, always 2 dp with thousands
/// separators. Amounts stay [Decimal] until display; this is the only place
/// they become text, so "171.00 NZD" and "$171.00" can never mix again.
///
/// [symbol] comes from locale config (`currencySymbolOf`); it defaults to `$`.
String formatMoney(Decimal amount, {String symbol = r'$'}) {
  final negative = amount < Decimal.zero;
  final fixed = amount.abs().toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed
      .substring(0, dot)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
  return '${negative ? '-' : ''}$symbol$whole${fixed.substring(dot)}';
}

/// Nullable convenience — `null` shows [placeholder] rather than `$0.00`,
/// so a missing amount is never presented as a real zero.
String formatMoneyOrDash(
  Decimal? amount, {
  String symbol = r'$',
  String placeholder = '—',
}) => amount == null ? placeholder : formatMoney(amount, symbol: symbol);

/// Hourly rate, e.g. `$85.50/h`.
String formatRate(Decimal rate, {String symbol = r'$'}) =>
    '${formatMoney(rate, symbol: symbol)}/h';
