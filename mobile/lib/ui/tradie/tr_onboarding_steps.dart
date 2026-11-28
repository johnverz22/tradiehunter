import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../models/tradie_onboarding.dart';
import '../../viewmodels/tradie_onboarding_viewmodel.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../shared/th_address_lookup.dart';
import 'tr_onboarding_mapper.dart';

class TrOnboardingControllers {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final radius = TextEditingController();
  final bankAccountName = TextEditingController();
  final bankAccountNumber = TextEditingController();
  final Map<int, TextEditingController> rates = {};

  TextEditingController rateFor(TradieOnboardingState state, int serviceId) =>
      rates.putIfAbsent(
        serviceId,
        () => TextEditingController(text: state.rateInputs[serviceId] ?? ''),
      );

  void hydrate(TradieOnboardingState state) {
    firstName.text = state.firstName;
    lastName.text = state.lastName;
    phone.text = state.phone;
    radius.text = state.serviceRadiusKm.toStringAsFixed(0);
    bankAccountName.text = state.bankAccountName;
    bankAccountNumber.text = state.bankAccountNumber;
  }

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    radius.dispose();
    bankAccountName.dispose();
    bankAccountNumber.dispose();
    for (final c in rates.values) {
      c.dispose();
    }
  }
}

class TrOnboardingStep0Work extends StatelessWidget {
  const TrOnboardingStep0Work({
    super.key,
    required this.state,
    required this.notifier,
    required this.controllers,
  });

  final TradieOnboardingState state;
  final TradieOnboardingNotifier notifier;
  final TrOnboardingControllers controllers;

  @override
  Widget build(BuildContext context) {
    final errors = state.fieldErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        if (state.step1Error != null)
          THCard(
            padding: Space.s3,
            children: [
              THText(
                state.step1Error!,
                style: THTextStyle.meta,
                tone: THTone.danger,
              ),
            ],
          ),
        _SectionCard(
          title: 'Your details',
          children: [
            _OnboardingTextField(
              label: 'First name',
              controller: controllers.firstName,
              errorText: errors['firstName'],
              onChanged: notifier.setFirstName,
            ),
            _OnboardingTextField(
              label: 'Last name',
              controller: controllers.lastName,
              errorText: errors['lastName'],
              onChanged: notifier.setLastName,
            ),
            _OnboardingTextField(
              label: 'Phone',
              controller: controllers.phone,
              errorText: errors['phone'],
              keyboardType: TextInputType.phone,
              onChanged: notifier.setPhone,
            ),
            ThAddressLookup(
              value: state.address,
              fieldKey: const Key('tradie_address_search_field'),
              eyebrow: 'WHERE DO YOU WORK FROM?',
              label: 'BASE ADDRESS',
              hint: 'Start with the street number and road name',
              helper: 'Select a result so we can match jobs near you.',
              selectedLabel: 'Base address selected',
              selected: state.addressResolved,
              errorText: errors['address'],
              onChanged: notifier.setAddress,
              onSelected: (address, _) =>
                  notifier.selectAddress(address.address),
            ),
            _OnboardingTextField(
              label: 'Service radius (km)',
              controller: controllers.radius,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final parsed = Decimal.tryParse(v.trim());
                if (parsed != null) {
                  notifier.setServiceRadiusKm(parsed);
                }
              },
            ),
          ],
        ),
        THCard(
          padding: Space.s4,
          children: [
            const THText('Weekly availability', style: THTextStyle.title),
            const SizedBox(height: Space.s3),
            for (final day in trOnboardingSortedDays(state.schedule)) ...[
              _DayRow(
                day: day,
                name: trOnboardingDayNames[day] ?? 'Day $day',
                slot: state.schedule[day],
                errorText: errors['day:$day'],
                onToggle: (enabled) => notifier.setDayEnabled(day, enabled),
              ),
              if (day != 0) const SizedBox(height: Space.s2),
            ],
          ],
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.name,
    required this.slot,
    required this.errorText,
    required this.onToggle,
  });

  final int day;
  final String name;
  final TradieScheduleSlot? slot;
  final String? errorText;
  final ValueChanged<bool> onToggle;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final enabled = slot != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: THText(
                name,
                style: THTextStyle.body,
                tone: enabled ? THTone.base : THTone.soft,
              ),
            ),
            if (enabled)
              THText(
                '${_fmt(slot!.start)} – ${_fmt(slot!.end)}',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            const SizedBox(width: Space.s2),
            Switch.adaptive(
              key: Key('day_$day'),
              value: enabled,
              onChanged: onToggle,
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s1),
            child: THText(
              errorText!,
              style: THTextStyle.meta,
              tone: THTone.danger,
            ),
          ),
      ],
    );
  }
}

class TrOnboardingStep1Trades extends StatelessWidget {
  const TrOnboardingStep1Trades({
    super.key,
    required this.state,
    required this.notifier,
    required this.controllers,
  });

  final TradieOnboardingState state;
  final TradieOnboardingNotifier notifier;
  final TrOnboardingControllers controllers;

  static const List<String> _tradeCategories = [
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Painting',
    'Landscaping',
    'Cleaning',
    'Handyman',
  ];

  @override
  Widget build(BuildContext context) {
    final errors = state.fieldErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        if (state.step2Error != null)
          THCard(
            padding: Space.s3,
            children: [
              THText(
                state.step2Error!,
                style: THTextStyle.meta,
                tone: THTone.danger,
              ),
            ],
          ),
        _SectionCard(
          title: 'Primary trade',
          children: [
            Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              children: [
                for (final cat in _tradeCategories)
                  ChoiceChip(
                    label: Text(cat),
                    selected: state.tradeType == cat,
                    onSelected: (_) => notifier.setTradeType(cat),
                  ),
              ],
            ),
            if (errors['tradeType'] != null)
              THText(
                errors['tradeType']!,
                style: THTextStyle.meta,
                tone: THTone.danger,
              ),
          ],
        ),
        THText('Services and hourly rates', style: THTextStyle.title),
        if (errors['services'] != null)
          THText(
            errors['services']!,
            style: THTextStyle.meta,
            tone: THTone.danger,
          ),
        for (final service in state.catalog)
          _ServiceRateCard(
            service: service,
            selected: state.rates.containsKey(service.id),
            controller: controllers.rateFor(state, service.id),
            errorText: errors['rate:${service.id}'],
            onToggle: () => notifier.toggleService(service),
            onRateChanged: (v) => notifier.setRateInput(service, v),
          ),
      ],
    );
  }
}

class _ServiceRateCard extends StatelessWidget {
  const _ServiceRateCard({
    required this.service,
    required this.selected,
    required this.controller,
    required this.errorText,
    required this.onToggle,
    required this.onRateChanged,
  });

  final TradieService service;
  final bool selected;
  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onToggle;
  final ValueChanged<String> onRateChanged;

  @override
  Widget build(BuildContext context) {
    return THCard(
      padding: Space.s3,
      children: [
        Row(
          children: [
            Checkbox(value: selected, onChanged: (_) => onToggle()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  THText(service.name, style: THTextStyle.body),
                  if (service.category.isNotEmpty)
                    THText(
                      service.category,
                      style: THTextStyle.meta,
                      tone: THTone.soft,
                    ),
                ],
              ),
            ),
          ],
        ),
        if (selected) ...[
          const SizedBox(height: Space.s2),
          _OnboardingTextField(
            label: 'Hourly rate (\$)',
            controller: controller,
            errorText: errorText,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onRateChanged,
          ),
        ],
      ],
    );
  }
}

class TrOnboardingStep2Verification extends StatelessWidget {
  const TrOnboardingStep2Verification({
    super.key,
    required this.state,
    required this.onUploadTap,
  });

  final TradieOnboardingState state;
  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        if (state.step3Error != null)
          THCard(
            padding: Space.s3,
            children: [
              THText(
                state.step3Error!,
                style: THTextStyle.meta,
                tone: THTone.danger,
              ),
            ],
          ),
        THText('Documents', style: THTextStyle.title),
        if (state.credentials.isNotEmpty)
          THCard(
            padding: Space.s1,
            children: [
              for (var i = 0; i < state.credentials.length; i++)
                THListRow(
                  icon: Icons.description_rounded,
                  title: state.credentials[i].originalFileName,
                  subtitle: state.credentials[i].type,
                  badge: trCredentialStatusLabel(state.credentials[i].status),
                  flat: true,
                  divider: i > 0,
                ),
            ],
          )
        else
          THCard(
            padding: Space.s3_5,
            children: [
              THText(
                'Upload your trade licence or public liability insurance to build trust with homeowners.',
                style: THTextStyle.meta,
                tone: THTone.soft,
              ),
            ],
          ),
        GestureDetector(
          key: const Key('upload_document_button'),
          onTap: state.uploadingFileName == null ? onUploadTap : null,
          child: THDashBox(
            icon: Icons.upload_rounded,
            title: state.uploadingFileName != null
                ? 'Uploading ${state.uploadingFileName}…'
                : 'Add another document',
            subtitle: 'PDF or photo, up to 10 MB',
          ),
        ),
        THCard(
          padding: Space.s3_5,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.s2_5,
              children: [
                THIcon(
                  Icons.info_outline_rounded,
                  size: Sizes.iconSm,
                  tone: THTone.brand,
                ),
                Expanded(
                  child: THText(
                    'No call-out fee is charged by TradieHunter. Your rate is shown to homeowners including GST if you are registered.',
                    style: THTextStyle.meta,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class TrOnboardingStep3Payout extends StatelessWidget {
  const TrOnboardingStep3Payout({
    super.key,
    required this.state,
    required this.notifier,
    required this.controllers,
  });

  final TradieOnboardingState state;
  final TradieOnboardingNotifier notifier;
  final TrOnboardingControllers controllers;

  @override
  Widget build(BuildContext context) {
    final errors = state.fieldErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s3,
      children: [
        if (state.step4Error != null)
          THCard(
            padding: Space.s3,
            children: [
              THText(
                state.step4Error!,
                style: THTextStyle.meta,
                tone: THTone.danger,
              ),
            ],
          ),
        _SectionCard(
          title: 'Payout details',
          children: [
            _OnboardingTextField(
              label: 'Account holder name',
              controller: controllers.bankAccountName,
              onChanged: notifier.setBankAccountName,
            ),
            _OnboardingTextField(
              label: 'NZ bank account number',
              hintText: '00-0000-0000000-00',
              controller: controllers.bankAccountNumber,
              errorText: errors['bankAccountNumber'],
              onChanged: notifier.setBankAccountNumber,
            ),
          ],
        ),
      ],
    );
  }
}

/// Titled card that groups a step's fields, matching the cards used on the
/// other screens.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return THCard(
      children: [
        THText(title, style: THTextStyle.title),
        const SizedBox(height: Space.s3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s3,
          children: children,
        ),
      ],
    );
  }
}

class _OnboardingTextField extends StatelessWidget {
  const _OnboardingTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.errorText,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
      ),
    );
  }
}
