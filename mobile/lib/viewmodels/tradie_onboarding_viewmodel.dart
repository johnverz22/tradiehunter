import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tradie_onboarding.dart';
import '../network/api_error.dart';
import '../repositories/profile_repository.dart';
import 'profile_viewmodel.dart';

/// Wizard-scoped state for the tradie onboarding flow (P1-09).
///
/// This is deliberately separate from `profileViewModelProvider`: the
/// wizard needs per-step draft values, per-field validation and its own save
/// flags, none of which belong in the state every other screen watches.
class TradieOnboardingState {
  /// 0-based index of the visible step: 0 where you work (profile + schedule),
  /// 1 trades (primary trade + services & rates), 2 verification, 3 payout.
  final int step;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  /// Inline validation messages keyed by field: `'firstName'`, `'lastName'`,
  /// `'phone'`, `'address'`, `'latitude'`, `'longitude'`, `'tradeType'`,
  /// `'services'`, `'rate:<serviceId>'`, `'day:<weekday>'` and
  /// `'bankAccountNumber'`. Set only by local validation — server failures
  /// keep using the per-step error banners.
  final Map<String, String> fieldErrors;

  // ── Step 1: where you work ──────────────────────────────────────────────
  final String firstName;
  final String lastName;
  final String phone;
  final String address;
  final String latitude;
  final String longitude;

  /// Must match a `TradeCategory` name — matching compares it against the
  /// job's category, so a tradie left on `"General"` never gets matched.
  final String tradeType;

  /// Service radius in km, held as a `Decimal` to match the backend column.
  final Decimal serviceRadiusKm;

  // ── Step 1 (cont.): weekly availability ─────────────────────────────────
  /// weekday → slot. Absent means the tradie is unavailable that day.
  final Map<int, TradieScheduleSlot> schedule;

  /// Save failure for step 1 — the profile PUT or the schedule POST.
  final String? step1Error;

  // ── Step 2: trades ──────────────────────────────────────────────────────
  final List<TradieService> catalog;

  /// serviceId → hourly rate. A key means the service is selected.
  final Map<int, Decimal> rates;
  final Map<int, String> rateInputs;
  final String? step2Error;

  // ── Step 3: verification ────────────────────────────────────────────────
  final List<TradieCredential> credentials;
  final String? uploadingFileName;
  final String? step3Error;

  // ── Step 4: payout ──────────────────────────────────────────────────────
  final String bankAccountName;
  final String bankAccountNumber;
  final String? step4Error;

  TradieOnboardingState({
    this.step = 0,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.fieldErrors = const {},
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.address = '',
    this.latitude = '',
    this.longitude = '',
    this.tradeType = '',
    Decimal? serviceRadiusKm,
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.step1Error,
    this.catalog = const [],
    this.rates = const {},
    this.rateInputs = const {},
    this.step2Error,
    this.schedule = const {},
    this.step3Error,
    this.credentials = const [],
    this.uploadingFileName,
    this.step4Error,
  }) : serviceRadiusKm = serviceRadiusKm ?? defaultServiceRadiusKm;

  /// Number of wizard steps.
  static const int stepCount = 4;

  /// Backend `TradieProfile.ServiceRadiusKm` default.
  static final Decimal defaultServiceRadiusKm = Decimal.fromInt(25);

  bool get isFirstStep => step == 0;
  bool get isLastStep => step == stepCount - 1;
  bool get hasSelectedServices => rates.isNotEmpty;

  /// Distinct `TradeCategory` values in the catalog, for the primary-trade
  /// picker. Sorted so the dropdown is stable between loads.
  List<String> get tradeCategories {
    final seen = <String>{for (final s in catalog) s.category};
    return seen.toList()..sort();
  }

  /// Services grouped by `TradeCategory`, in catalog order.
  Map<String, List<TradieService>> get catalogByCategory {
    final grouped = <String, List<TradieService>>{};
    for (final service in catalog) {
      grouped.putIfAbsent(service.category, () => []).add(service);
    }
    return grouped;
  }

  TradieOnboardingState copyWith({
    int? step,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    Map<String, String>? fieldErrors,
    String? firstName,
    String? lastName,
    String? phone,
    String? address,
    String? latitude,
    String? longitude,
    String? tradeType,
    Decimal? serviceRadiusKm,
    String? bankAccountName,
    String? bankAccountNumber,
    String? step1Error,
    bool clearStep1Error = false,
    List<TradieService>? catalog,
    Map<int, Decimal>? rates,
    Map<int, String>? rateInputs,
    String? step2Error,
    bool clearStep2Error = false,
    Map<int, TradieScheduleSlot>? schedule,
    String? step3Error,
    bool clearStep3Error = false,
    List<TradieCredential>? credentials,
    String? uploadingFileName,
    bool clearUploading = false,
    String? step4Error,
    bool clearStep4Error = false,
  }) {
    return TradieOnboardingState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tradeType: tradeType ?? this.tradeType,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      step1Error: clearStep1Error ? null : (step1Error ?? this.step1Error),
      catalog: catalog ?? this.catalog,
      rates: rates ?? this.rates,
      rateInputs: rateInputs ?? this.rateInputs,
      step2Error: clearStep2Error ? null : (step2Error ?? this.step2Error),
      schedule: schedule ?? this.schedule,
      step3Error: clearStep3Error ? null : (step3Error ?? this.step3Error),
      credentials: credentials ?? this.credentials,
      uploadingFileName: clearUploading
          ? null
          : (uploadingFileName ?? this.uploadingFileName),
      step4Error: clearStep4Error ? null : (step4Error ?? this.step4Error),
    );
  }
}

class TradieOnboardingNotifier extends StateNotifier<TradieOnboardingState> {
  final ProfileRepository _repository;

  TradieOnboardingNotifier(this._repository) : super(TradieOnboardingState()) {
    load();
  }

  /// Loads the existing profile, trade catalog, rates, schedule and
  /// credentials so a returning tradie resumes where they left off.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // The `TradieProfile` row is created by `PUT /api/profile`, so the
      // profile read has to come first — a brand new tradie has no profile
      // and every `api/tradie` call would 403.
      final profile = await _repository.getCurrentProfile();
      final catalog = await _repository.getServiceCatalog();
      final existingRates = await _repository.getRates();
      final existingSchedule = await _repository.getSchedule();
      final credentials = await _repository.getCredentials();

      final rates = <int, Decimal>{};
      final rateInputs = <int, String>{};
      for (final entry in existingRates) {
        rates[entry.serviceId] = entry.hourlyRate;
        rateInputs[entry.serviceId] = entry.hourlyRate.toStringAsFixed(2);
      }

      state = state.copyWith(
        isLoading: false,
        firstName: (profile['firstName'] as String?) ?? '',
        lastName: (profile['lastName'] as String?) ?? '',
        phone: (profile['phoneNumber'] as String?) ?? '',
        address: (profile['address'] as String?) ?? '',
        latitude: _coordToInput(profile['latitude']),
        longitude: _coordToInput(profile['longitude']),
        tradeType: (profile['tradeType'] as String?) ?? '',
        serviceRadiusKm:
            parseDecimal(profile['serviceRadiusKm']) ??
            TradieOnboardingState.defaultServiceRadiusKm,
        bankAccountName: (profile['bankAccountName'] as String?) ?? '',
        bankAccountNumber: (profile['bankAccountNumber'] as String?) ?? '',
        catalog: catalog,
        rates: rates,
        rateInputs: rateInputs,
        schedule: {for (final slot in existingSchedule) slot.weekday: slot},
        credentials: credentials,
        clearError: true,
      );
    } on ProfileApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e, s) {
      debugPrint('[TradieOnboarding] load failed: $e\n$s');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your onboarding details. Please try again.',
      );
    }
  }

  /// Returns the field-error map minus [key], so editing a field clears the
  /// message shown beneath it.
  Map<String, String> _withoutField(String key) {
    if (!state.fieldErrors.containsKey(key)) return state.fieldErrors;
    return Map.of(state.fieldErrors)..remove(key);
  }

  // ── Step 1 field setters ────────────────────────────────────────────────

  void setFirstName(String value) => state = state.copyWith(
    firstName: value,
    fieldErrors: _withoutField('firstName'),
    clearStep1Error: true,
  );

  void setLastName(String value) => state = state.copyWith(
    lastName: value,
    fieldErrors: _withoutField('lastName'),
    clearStep1Error: true,
  );

  void setPhone(String value) => state = state.copyWith(
    phone: value,
    fieldErrors: _withoutField('phone'),
    clearStep1Error: true,
  );

  void setAddress(String value) => state = state.copyWith(
    address: value,
    fieldErrors: _withoutField('address'),
    clearStep1Error: true,
  );

  void setLatitude(String value) => state = state.copyWith(
    latitude: value,
    fieldErrors: _withoutField('latitude'),
    clearStep1Error: true,
  );

  void setLongitude(String value) => state = state.copyWith(
    longitude: value,
    fieldErrors: _withoutField('longitude'),
    clearStep1Error: true,
  );

  void setTradeType(String value) => state = state.copyWith(
    tradeType: value,
    fieldErrors: _withoutField('tradeType'),
    clearStep2Error: true,
  );

  void setServiceRadiusKm(Decimal value) =>
      state = state.copyWith(serviceRadiusKm: value, clearStep1Error: true);

  void setBankAccountName(String value) =>
      state = state.copyWith(bankAccountName: value, clearStep4Error: true);

  void setBankAccountNumber(String value) => state = state.copyWith(
    bankAccountNumber: value,
    fieldErrors: _withoutField('bankAccountNumber'),
    clearStep4Error: true,
  );

  // ── Step 2 field setters ────────────────────────────────────────────────

  /// Selecting a service seeds a blank rate field; deselecting drops it.
  void toggleService(TradieService service) {
    final rates = Map<int, Decimal>.from(state.rates);
    final inputs = Map<int, String>.from(state.rateInputs);
    if (rates.containsKey(service.id)) {
      rates.remove(service.id);
      inputs.remove(service.id);
    } else {
      rates[service.id] = Decimal.zero;
      inputs[service.id] = '';
    }
    state = state.copyWith(
      rates: rates,
      rateInputs: inputs,
      fieldErrors: Map.of(state.fieldErrors)
        ..remove('services')
        ..remove('rate:${service.id}'),
      clearStep2Error: true,
    );
  }

  /// Rate text is parsed straight into a `Decimal` — a `double` would let
  /// typing and re-editing accumulate binary floating-point error.
  void setRateInput(TradieService service, String value) {
    final inputs = Map<int, String>.from(state.rateInputs);
    final rates = Map<int, Decimal>.from(state.rates);
    inputs[service.id] = value;
    final parsed = parseDecimal(value);
    if (parsed != null) rates[service.id] = parsed;
    state = state.copyWith(
      rateInputs: inputs,
      rates: rates,
      fieldErrors: _withoutField('rate:${service.id}'),
      clearStep2Error: true,
    );
  }

  // ── Step 1 field setters (weekly availability) ──────────────────────────

  void setDayEnabled(int weekday, bool enabled) {
    final schedule = Map<int, TradieScheduleSlot>.from(state.schedule);
    if (enabled) {
      schedule[weekday] =
          schedule[weekday] ??
          TradieScheduleSlot(
            weekday: weekday,
            start: const TimeOfDay(hour: 8, minute: 0),
            end: const TimeOfDay(hour: 17, minute: 0),
          );
    } else {
      schedule.remove(weekday);
    }
    state = state.copyWith(
      schedule: schedule,
      fieldErrors: _withoutField('day:$weekday'),
      clearStep1Error: true,
    );
  }

  void setDayTimes(int weekday, {TimeOfDay? start, TimeOfDay? end}) {
    final existing = state.schedule[weekday];
    if (existing == null) return;
    final schedule = Map<int, TradieScheduleSlot>.from(state.schedule);
    schedule[weekday] = existing.copyWith(start: start, end: end);
    state = state.copyWith(
      schedule: schedule,
      fieldErrors: _withoutField('day:$weekday'),
      clearStep1Error: true,
    );
  }

  // ── Step 3: verification ────────────────────────────────────────────────

  /// Uploads one document. The backend records it as `Pending`; an admin
  /// approves it (P1-07) before the tradie counts as verified.
  Future<bool> uploadCredential({
    required String filePath,
    required String fileName,
    required CredentialKind kind,
  }) async {
    state = state.copyWith(
      uploadingFileName: fileName,
      clearStep3Error: true,
      clearError: true,
    );
    try {
      final credential = await _repository.uploadCredential(
        filePath: filePath,
        fileName: fileName,
        kind: kind,
      );
      state = state.copyWith(
        credentials: [credential, ...state.credentials],
        clearUploading: true,
      );
      return true;
    } on ProfileApiException catch (e) {
      state = state.copyWith(
        clearUploading: true,
        step3Error: e.isForbidden
            ? 'Save your base profile first so we know which tradie these '
                  'documents belong to.'
            : e.message,
      );
      return false;
    }
  }

  // ── Navigation & persistence ────────────────────────────────────────────

  /// Validates the current step, saves it, then advances. Returns false when
  /// validation or the save fails so the view stays on the step. The last
  /// step saves through [finishSetup] instead.
  Future<bool> saveStepAndAdvance() async {
    switch (state.step) {
      case 0:
        return _saveWorkAndAdvance();
      case 1:
        return _saveTradesAndAdvance();
      default:
        // Verification uploads save inline during the step, so moving on
        // needs no extra call.
        goToStep(state.step + 1);
        return true;
    }
  }

  void goToStep(int step) => state = state.copyWith(
    step: step.clamp(0, TradieOnboardingState.stepCount - 1),
  );

  void goBack() {
    if (state.isFirstStep) return;
    state = state.copyWith(step: state.step - 1);
  }

  /// Re-reads credentials so an admin's decision shows up without a restart.
  Future<void> refreshCredentials() async {
    try {
      final credentials = await _repository.getCredentials();
      state = state.copyWith(credentials: credentials);
    } on ProfileApiException catch (e) {
      state = state.copyWith(step3Error: e.message);
    }
  }

  /// `PUT /api/profile` then `POST /api/tradie/schedule` — name, phone,
  /// address, geo point, radius and weekly availability. The profile PUT is
  /// also the call that provisions the `TradieProfile` row for a new
  /// tradie, so it always goes first.
  Future<bool> _saveWorkAndAdvance() async {
    final errors = <String, String>{};
    if (state.firstName.trim().isEmpty) {
      errors['firstName'] = 'Enter your first name.';
    }
    if (state.lastName.trim().isEmpty) {
      errors['lastName'] = 'Enter your last name.';
    }
    if (state.address.trim().isEmpty) {
      errors['address'] = 'Enter the address you work from.';
    }
    final phone = state.phone.trim();
    if (phone.isNotEmpty && !_looksLikePhone(phone)) {
      errors['phone'] =
          'Enter a valid phone number — digits, spaces and + only.';
    }

    final latText = state.latitude.trim();
    final lngText = state.longitude.trim();
    final double? lat = latText.isEmpty ? null : double.tryParse(latText);
    final double? lng = lngText.isEmpty ? null : double.tryParse(lngText);
    if (latText.isEmpty != lngText.isEmpty) {
      errors['latitude'] =
          'Enter both latitude and longitude, or leave both blank.';
      errors['longitude'] =
          'Enter both latitude and longitude, or leave both blank.';
    } else {
      if (latText.isNotEmpty && (lat == null || lat < -90 || lat > 90)) {
        errors['latitude'] = 'Latitude must be between -90 and 90.';
      }
      if (lngText.isNotEmpty && (lng == null || lng < -180 || lng > 180)) {
        errors['longitude'] = 'Longitude must be between -180 and 180.';
      }
    }

    for (final slot in state.schedule.values) {
      // Mirrors UpdateScheduleRequestValidator: start must be before end.
      final startMinutes = slot.start.hour * 60 + slot.start.minute;
      final endMinutes = slot.end.hour * 60 + slot.end.minute;
      if (startMinutes >= endMinutes) {
        errors['day:${slot.weekday}'] =
            '${kWeekdayLabels[slot.weekday]}: the start time must be before '
            'the end time.';
      }
    }

    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      fieldErrors: const {},
      clearStep1Error: true,
    );
    if (!await _putProfile('step1')) return false;

    try {
      final saved = await _repository.updateSchedule(
        state.schedule.values.toList(),
      );
      state = state.copyWith(
        isSaving: false,
        step: state.step + 1,
        schedule: {for (final s in saved) s.weekday: s},
        clearStep1Error: true,
      );
      return true;
    } on ProfileApiException catch (e) {
      state = state.copyWith(isSaving: false, step1Error: e.message);
      return false;
    }
  }

  /// `PUT /api/profile` (persists the primary trade) then
  /// `POST /api/tradie/rates` — per-service hourly rates, full replacement.
  Future<bool> _saveTradesAndAdvance() async {
    final errors = <String, String>{};
    if (state.tradeType.trim().isEmpty) {
      errors['tradeType'] = 'Choose your primary trade.';
    }

    final names = {for (final s in state.catalog) s.id: s.name};
    final entries = <TradieRateEntry>[];
    if (state.rates.isEmpty) {
      errors['services'] = 'Pick at least one service you offer.';
    } else {
      for (final entry in state.rates.entries) {
        final name = names[entry.key] ?? 'Rate';
        final raw = state.rateInputs[entry.key]?.trim() ?? '';
        final parsed = parseDecimal(raw);
        if (parsed == null) {
          errors['rate:${entry.key}'] = 'Enter an hourly rate for $name.';
          continue;
        }
        // Mirrors UpdateRatesRequestValidator: > 0 and <= 10000.
        if (parsed <= Decimal.zero || parsed > Decimal.fromInt(10000)) {
          errors['rate:${entry.key}'] =
              '$name must be between 0 and 10,000 per hour.';
          continue;
        }
        entries.add(
          TradieRateEntry(
            serviceId: entry.key,
            serviceName: name,
            hourlyRate: parsed,
          ),
        );
      }
    }

    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      fieldErrors: const {},
      clearStep2Error: true,
    );
    if (!await _putProfile('step2')) return false;

    try {
      final saved = await _repository.updateRates(entries);
      final rates = <int, Decimal>{};
      final inputs = <int, String>{};
      for (final entry in saved) {
        rates[entry.serviceId] = entry.hourlyRate;
        inputs[entry.serviceId] = entry.hourlyRate.toStringAsFixed(2);
      }
      state = state.copyWith(
        isSaving: false,
        step: state.step + 1,
        rates: rates.isEmpty ? state.rates : rates,
        rateInputs: inputs.isEmpty ? state.rateInputs : inputs,
        clearStep2Error: true,
      );
      return true;
    } on ProfileApiException catch (e) {
      state = state.copyWith(isSaving: false, step2Error: e.message);
      return false;
    }
  }

  /// `PUT /api/profile` — the payout step's bank details plus every other
  /// profile field, since the endpoint replaces the whole profile. Returns
  /// true when the save landed and the wizard may close.
  Future<bool> finishSetup() async {
    final bankAccountNumber = state.bankAccountNumber.trim();
    if (bankAccountNumber.isNotEmpty &&
        !RegExp(r'^\d{2}-\d{4}-\d{7}-\d{2,3}$').hasMatch(bankAccountNumber)) {
      state = state.copyWith(
        fieldErrors: const {
          'bankAccountNumber':
              'Bank account number must be in format XX-XXXX-XXXXXXX-XX',
        },
      );
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      fieldErrors: const {},
      clearStep4Error: true,
    );
    if (!await _putProfile('step4')) return false;
    state = state.copyWith(isSaving: false, clearStep4Error: true);
    return true;
  }

  /// The full profile payload `PUT /api/profile` expects. Every wizard step
  /// that touches profile fields re-sends them all — the endpoint replaces
  /// the record, and re-sending is what keeps earlier answers intact.
  Map<String, dynamic> _profilePayload() {
    final latText = state.latitude.trim();
    final lngText = state.longitude.trim();
    final phone = state.phone.trim();
    final bankAccountName = state.bankAccountName.trim();
    final bankAccountNumber = state.bankAccountNumber.trim();
    return {
      'firstName': state.firstName.trim(),
      'lastName': state.lastName.trim(),
      'phoneNumber': phone.isEmpty ? null : phone,
      'tradeType': state.tradeType.trim(),
      'address': state.address.trim(),
      'latitude': latText.isEmpty ? null : double.tryParse(latText),
      'longitude': lngText.isEmpty ? null : double.tryParse(lngText),
      'serviceRadiusKm': state.serviceRadiusKm.toDouble(),
      'bankAccountName': bankAccountName.isEmpty ? null : bankAccountName,
      'bankAccountNumber': bankAccountNumber.isEmpty ? null : bankAccountNumber,
    };
  }

  /// Sends [_profilePayload] and records a server failure on the given
  /// step's error banner (`'step1'`, `'step2'` or `'step4'`). Leaves
  /// `isSaving` untouched on success so the caller can chain more calls.
  Future<bool> _putProfile(String step) async {
    try {
      await _repository.updateProfile(_profilePayload());
      return true;
    } on DioException catch (e) {
      final message = friendlyDioError(
        e,
        tag: 'TradieOnboarding.updateProfile',
        statusOverrides: const {403: 'Only tradies can save these details.'},
      );
      state = switch (step) {
        'step2' => state.copyWith(isSaving: false, step2Error: message),
        'step4' => state.copyWith(isSaving: false, step4Error: message),
        _ => state.copyWith(isSaving: false, step1Error: message),
      };
      return false;
    } on ProfileApiException catch (e) {
      state = switch (step) {
        'step2' => state.copyWith(isSaving: false, step2Error: e.message),
        'step4' => state.copyWith(isSaving: false, step4Error: e.message),
        _ => state.copyWith(isSaving: false, step1Error: e.message),
      };
      return false;
    }
  }

  static String _coordToInput(Object? value) {
    if (value is! num) return '';
    // Avoid a trailing ".0" for whole-number coordinates.
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  static bool _looksLikePhone(String value) =>
      RegExp(r'^\+?[0-9][0-9\s\-()]{5,}$').hasMatch(value);
}

final tradieOnboardingProvider =
    StateNotifierProvider.autoDispose<
      TradieOnboardingNotifier,
      TradieOnboardingState
    >((ref) {
      return TradieOnboardingNotifier(ref.watch(profileRepositoryProvider));
    });
