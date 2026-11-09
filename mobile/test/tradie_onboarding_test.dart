// Wire-format and money-precision tests for the tradie onboarding wizard
// (P1-09). These cover the seams where the Flutter client meets the .NET
// API: `TimeSpan` serialisation, `decimal` rates, and PascalCase enums.

import 'package:decimal/decimal.dart';
import 'package:fixo/models/tradie_onboarding.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseApiTimeOfDay', () {
    test('parses the System.Text.Json TimeSpan format', () {
      expect(
        parseApiTimeOfDay('09:00:00'),
        const TimeOfDay(hour: 9, minute: 0),
      );
      expect(
        parseApiTimeOfDay('17:30:00'),
        const TimeOfDay(hour: 17, minute: 30),
      );
    });

    test('tolerates fractional seconds and a bare HH:mm', () {
      expect(
        parseApiTimeOfDay('08:15:00.0000000'),
        const TimeOfDay(hour: 8, minute: 15),
      );
      expect(
        parseApiTimeOfDay('08:15'),
        const TimeOfDay(hour: 8, minute: 15),
      );
    });

    test('strips a .NET day prefix', () {
      expect(
        parseApiTimeOfDay('1.09:00:00'),
        const TimeOfDay(hour: 9, minute: 0),
      );
    });

    test('returns null for junk rather than throwing', () {
      expect(parseApiTimeOfDay(null), isNull);
      expect(parseApiTimeOfDay(''), isNull);
      expect(parseApiTimeOfDay('not-a-time'), isNull);
      expect(parseApiTimeOfDay('25:00:00'), isNull);
      expect(parseApiTimeOfDay('09:99:00'), isNull);
    });
  });

  group('formatApiTimeOfDay', () {
    test('emits the HH:mm:ss shape the API binds to TimeSpan', () {
      expect(
        formatApiTimeOfDay(const TimeOfDay(hour: 8, minute: 5)),
        '08:05:00',
      );
      expect(
        formatApiTimeOfDay(const TimeOfDay(hour: 17, minute: 30)),
        '17:30:00',
      );
    });

    test('round-trips through the parser', () {
      const time = TimeOfDay(hour: 6, minute: 45);
      expect(parseApiTimeOfDay(formatApiTimeOfDay(time)), time);
    });
  });

  group('parseDecimal', () {
    test('keeps two-decimal money exact', () {
      expect(parseDecimal(85), Decimal.parse('85'));
      expect(parseDecimal(85.5), Decimal.parse('85.5'));
      expect(parseDecimal('85.55'), Decimal.parse('85.55'));
      expect(parseDecimal(85.55), Decimal.parse('85.55'));
    });

    test('returns null for missing or unparseable values', () {
      expect(parseDecimal(null), isNull);
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('abc'), isNull);
    });

    test('accepts 0.1 + 0.2 exactly, unlike double', () {
      final sum = Decimal.parse('0.1') + Decimal.parse('0.2');
      expect(sum, Decimal.parse('0.3'));
      expect(0.1 + 0.2, isNot(0.3));
    });
  });

  group('TradieScheduleSlot', () {
    test('deserialises the backend DTO', () {
      final slot = TradieScheduleSlot.fromJson({
        'weekday': 3,
        'startTime': '08:30:00',
        'endTime': '16:45:00',
      });
      expect(slot.weekday, 3);
      expect(slot.start, const TimeOfDay(hour: 8, minute: 30));
      expect(slot.end, const TimeOfDay(hour: 16, minute: 45));
      expect(slot.toJson(), {
        'weekday': 3,
        'startTime': '08:30:00',
        'endTime': '16:45:00',
      });
    });

    test('falls back to sensible hours on an unparseable time', () {
      final slot = TradieScheduleSlot.fromJson({
        'weekday': 1,
        'startTime': 'oops',
        'endTime': 'oops',
      });
      expect(slot.start, const TimeOfDay(hour: 9, minute: 0));
      expect(slot.end, const TimeOfDay(hour: 17, minute: 0));
    });
  });

  group('TradieRateEntry', () {
    test('reads the decimal rate the API sends as a JSON number', () {
      final rate = TradieRateEntry.fromJson({
        'serviceId': 2,
        'serviceName': 'Plumber',
        'hourlyRate': 95.50,
      });
      expect(rate.hourlyRate, Decimal.parse('95.5'));
      expect(rate.toInputJson(), {'serviceId': 2, 'hourlyRate': 95.5});
    });
  });

  group('CredentialKind', () {
    test('maps the PascalCase enum names from the API', () {
      expect(CredentialKind.fromWire('License'), CredentialKind.license);
      expect(CredentialKind.fromWire('Insurance'), CredentialKind.insurance);
      expect(
        CredentialKind.fromWire('Certification'),
        CredentialKind.certification,
      );
      expect(CredentialKind.fromWire('Other'), CredentialKind.other);
    });

    test('falls back to other for an unknown or missing value', () {
      expect(CredentialKind.fromWire('Bogus'), CredentialKind.other);
      expect(CredentialKind.fromWire(null), CredentialKind.other);
    });
  });

  group('TradieCredential', () {
    test('reads status case-insensitively', () {
      TradieCredential withStatus(String status) => TradieCredential.fromJson({
            'id': 1,
            'type': 'License',
            'originalFileName': 'licence.pdf',
            'status': status,
          });

      expect(withStatus('Pending').isPending, isTrue);
      expect(withStatus('approved').isApproved, isTrue);
      expect(withStatus('REJECTED').isRejected, isTrue);
    });
  });

  group('weekday helpers', () {
    test('orders days Monday-first for display', () {
      expect(kWeekdayOrder, [1, 2, 3, 4, 5, 6, 0]);
      expect(weekdayShortLabel(1), 'Mon');
      expect(weekdayShortLabel(0), 'Sun');
    });
  });
}
