import 'package:fixo/viewmodels/locale_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('region shows country and code, never "\$ NZD"', () {
    expect(
      regionLabel({'defaultCurrency': 'NZD', 'legalEntityCountry': 'NZ'}),
      'New Zealand (NZD)',
    );
    expect(
      regionLabel({
        'locale': {'defaultCurrency': 'NZD', 'legalEntityCountry': 'nz'},
      }),
      'New Zealand (NZD)',
    );
  });

  test('unknown country falls back to the currency code only', () {
    expect(regionLabel({'defaultCurrency': 'USD'}), 'USD');
    expect(regionLabel(null), 'NZD');
  });
}
