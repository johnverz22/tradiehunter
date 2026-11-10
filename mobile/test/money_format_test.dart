import 'package:decimal/decimal.dart';
import 'package:fixo/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  test('formats with symbol, separators and 2 dp', () {
    expect(formatMoney(d('171')), r'$171.00');
    expect(formatMoney(d('85.5')), r'$85.50');
    expect(formatMoney(d('2393.92')), r'$2,393.92');
    expect(formatMoney(d('1234567.891')), r'$1,234,567.89');
    expect(formatMoney(d('0')), r'$0.00');
  });

  test('negative amounts keep the sign before the symbol', () {
    expect(formatMoney(d('-1200.5')), r'-$1,200.50');
  });

  test('null shows a placeholder, not zero', () {
    expect(formatMoneyOrDash(null), '—');
    expect(formatMoneyOrDash(d('10')), r'$10.00');
  });

  test('rate suffix', () {
    expect(formatRate(d('85.5')), r'$85.50/h');
  });
}
