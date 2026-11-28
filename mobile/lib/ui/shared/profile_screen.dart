// ThProfileScreen: v2 self profile (migration plan 3.3, id `profile`).
//
// Hand-owned v2 profile composition. Personal details opens the preserved
// edit form as a separate view; writes still use the existing API and payload.
// The tradie availability switch still saves immediately, and NZ bank-number
// validation and loading/error/empty states are retained.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/incoming_offer_coordinator.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import 'th_tab_app_bar.dart';
import '../feedback/th_notice.dart';
import '../feedback/th_state_view.dart';
import '../tradie/tr_home_mapper.dart' show trNeedsOfflineConfirm;
import '../tradie/tr_home_parts.dart' show showTrGoOfflineSheet;
import '../tradie/tr_profile_summary.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';

class ThProfileScreen extends ConsumerStatefulWidget {
  const ThProfileScreen({super.key});

  @override
  ConsumerState<ThProfileScreen> createState() => _ThProfileScreenState();
}

class _ThProfileScreenState extends ConsumerState<ThProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _tradeTypeCtrl;
  late TextEditingController _businessNameCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _bankNumberCtrl;

  bool _formInitialized = false;
  bool _availabilitySaving = false;
  bool _bankVerified = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _tradeTypeCtrl = TextEditingController();
    _businessNameCtrl = TextEditingController();
    _bankNameCtrl = TextEditingController();
    _bankNumberCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _tradeTypeCtrl.dispose();
    _businessNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankNumberCtrl.dispose();
    super.dispose();
  }

  void _initForms(Map<String, dynamic> profile) {
    _firstNameCtrl.text = profile['firstName'] ?? '';
    _lastNameCtrl.text = profile['lastName'] ?? '';
    _phoneCtrl.text = profile['phoneNumber'] ?? '';
    _emailCtrl.text = profile['email'] ?? '';
    _tradeTypeCtrl.text = profile['tradeType'] ?? '';
    _businessNameCtrl.text = profile['businessName'] ?? '';
    _bankNameCtrl.text = profile['bankAccountName'] ?? '';
    _bankNumberCtrl.text = profile['bankAccountNumber'] ?? '';
    _bankVerified = profile['bankAccountVerified'] == true;
    _formInitialized = true;
  }

  // Availability is a standalone switch. It goes through the same view model
  // call as the home screen switch (POST /api/profile/availability), so both
  // screens read and write one source of truth. Going offline with leads or
  // booked work asks first, exactly like home.
  Future<void> _setAvailability(bool value) async {
    if (_availabilitySaving) return;
    if (!value && trNeedsOfflineConfirm(ref.read(jobsViewModelProvider).jobs)) {
      final confirmed = await showTrGoOfflineSheet(
        context,
        themeMode: ref.read(themeModeProvider),
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _availabilitySaving = true);
    var failed = false;
    try {
      final notifier = ref.read(profileViewModelProvider.notifier);
      final errorBefore = ref.read(profileViewModelProvider).error;
      await notifier.updateAvailability(value);
      if (!mounted) return;
      // The view model swallows exceptions into state.error: compare.
      final errorAfter = ref.read(profileViewModelProvider).error;
      failed = errorAfter != null && errorAfter != errorBefore;
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _availabilitySaving = false);
    if (failed) {
      THNotice.error(
        context,
        NoticeCopy.statusUpdateFailed,
        onRetry: () => unawaited(_setAvailability(value)),
      );
    }
  }

  String? _bankNumberValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{2}-\d{4}-\d{7}-\d{2,3}$').hasMatch(v)) {
      return 'Format: XX-XXXX-XXXXXXX-XX';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updateData = {
        'firstName': _firstNameCtrl.text,
        'lastName': _lastNameCtrl.text,
        'phoneNumber': _phoneCtrl.text,
        'tradeType': _tradeTypeCtrl.text.isNotEmpty
            ? _tradeTypeCtrl.text
            : null,
        'businessName': _businessNameCtrl.text.isNotEmpty
            ? _businessNameCtrl.text
            : null,
        'bankAccountName': _bankNameCtrl.text.trim().isNotEmpty
            ? _bankNameCtrl.text.trim()
            : null,
        'bankAccountNumber': _bankNumberCtrl.text.trim().isNotEmpty
            ? _bankNumberCtrl.text.trim()
            : null,
        'isAvailable':
            ref.read(profileViewModelProvider).profile?['isAvailable'] ?? true,
      };

      final success = await ref
          .read(profileViewModelProvider.notifier)
          .updateProfile(updateData);
      if (success && mounted) {
        setState(() {
          _isEditing = false;
        });
        THNotice.success(context, NoticeCopy.profileUpdated);
      }
    }
  }

  void _toggleEditing(Map<String, dynamic> profile) {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _formInitialized = false;
        _initForms(profile);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          final profileState = ref.watch(profileViewModelProvider);

          final appBar = ThTabAppBar(title: 'Profile');

          if (profileState.isLoading && profileState.profile == null) {
            return Scaffold(
              backgroundColor: c.paper,
              appBar: appBar,
              body: Center(
                child: ThStateView.loading(label: 'Loading profile…'),
              ),
            );
          }

          if (profileState.error != null && profileState.profile == null) {
            return Scaffold(
              backgroundColor: c.paper,
              appBar: appBar,
              body: Center(
                child: ThStateView.error(
                  message: 'Error: ${profileState.error}',
                  onRetry: () =>
                      ref.read(profileViewModelProvider.notifier).loadProfile(),
                ),
              ),
            );
          }

          final profile = profileState.profile;
          if (profile == null) {
            return Scaffold(
              backgroundColor: c.paper,
              appBar: appBar,
              body: Center(
                child: ThStateView.empty(
                  icon: Icons.person_off_outlined,
                  title: 'Profile not found',
                ),
              ),
            );
          }

          // Init once per profile load — never overwrite user edits in build.
          if (!_formInitialized) _initForms(profile);
          final isTradie =
              profile['role'] ==
              1; // UserRole: Homeowner=0, Tradie=1, Staff=2, Superadmin=3
          final isAvailable = profile['isAvailable'] as bool? ?? true;
          Widget valueRow(String label, String value, {bool divider = false}) =>
              THKeyValue(label, value, divider: divider);

          if (!_showDetails) {
            final themeMode = ref.watch(themeModeProvider);
            final firstName = profile['firstName'] as String? ?? '';
            final lastName = profile['lastName'] as String? ?? '';
            final initials =
                '${firstName.isEmpty ? '' : firstName[0]}'
                '${lastName.isEmpty ? '' : lastName[0]}';

            Widget row({
              required IconData icon,
              required String title,
              required VoidCallback onTap,
              String? subtitle,
              bool divider = true,
            }) => Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.s4,
                  ),
                  minTileHeight: Sizes.tapMin,
                  leading: Icon(icon, color: c.textSoft),
                  title: Text(
                    title,
                    style: THType.button.copyWith(color: c.text),
                  ),
                  subtitle: subtitle == null
                      ? null
                      : Text(
                          subtitle,
                          style: THType.meta.copyWith(color: c.textSoft),
                        ),
                  trailing: Icon(Icons.chevron_right, color: c.textSoft),
                  onTap: onTap,
                ),
                if (divider) Divider(height: 1, color: c.line),
              ],
            );

            Widget card(List<Widget> children) => Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: c.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: Column(children: children),
              ),
            );

            return Scaffold(
              backgroundColor: c.paper,
              appBar: ThTabAppBar(
                title: 'Profile',
                actions: [
                  THIconButton(
                    icon: Icons.settings_outlined,
                    semanticLabel: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
              body: SafeArea(
                bottom: false,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    Sizes.gutter,
                    Space.s3,
                    Sizes.gutter,
                    thDockClearance(context),
                  ),
                  children: [
                    Column(
                      children: [
                        THAvatar(initials, size: THAvatarSize.lg),
                        const SizedBox(height: Space.s2),
                        Text(
                          '$firstName $lastName'.trim(),
                          style: THType.h2.copyWith(color: c.text),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Space.s1),
                        Text(
                          profile['email'] as String? ?? '',
                          style: THType.meta.copyWith(color: c.textSoft),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Space.s2),
                        THBadge(
                          isTradie ? 'Tradie' : 'Homeowner',
                          kind: THBadgeKind.accent,
                          icon: isTradie
                              ? Icons.handyman_outlined
                              : Icons.home_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.s4),
                    card([
                      row(
                        icon: Icons.person_rounded,
                        title: 'Personal details',
                        onTap: () => setState(() => _showDetails = true),
                      ),
                      if (isTradie)
                        KeyedSubtree(
                          key: const Key('profile_earnings_row'),
                          child: row(
                            icon: Icons.payments_rounded,
                            title: 'Earnings',
                            onTap: () => context.push('/tradie/earnings'),
                          ),
                        ),
                      if (isTradie) ...[
                        KeyedSubtree(
                          key: const Key('profile_rating_row'),
                          child: row(
                            icon: Icons.star_rounded,
                            title: 'Rating',
                            subtitle: trRatingLabel(
                              profile['averageRating'],
                              profile['reviewCount'],
                            ),
                            onTap: () =>
                                context.push('/tradie/${profile['id']}'),
                          ),
                        ),
                        KeyedSubtree(
                          key: const Key('profile_rates_row'),
                          child: row(
                            icon: Icons.sell_rounded,
                            title: 'Services and rates',
                            subtitle: trSummaryOr(
                              ref.watch(trProfileRatesProvider),
                              trRatesSummary,
                            ),
                            onTap: () => context.push('/tradie/onboarding'),
                          ),
                        ),
                        KeyedSubtree(
                          key: const Key('profile_credentials_row'),
                          child: row(
                            icon: Icons.verified_user_rounded,
                            title: 'Credentials',
                            subtitle: trSummaryOr(
                              ref.watch(trProfileCredentialsProvider),
                              trCredentialsSummary,
                            ),
                            onTap: () => context.push('/tradie/onboarding'),
                          ),
                        ),
                      ],
                      row(
                        icon: Icons.credit_card_rounded,
                        title: 'Payments and receipts',
                        subtitle: isTradie
                            ? 'Earnings and payouts'
                            : 'Payment status and receipts by job',
                        onTap: () => isTradie
                            ? context.push('/tradie/earnings')
                            : context.go('/jobs'),
                      ),
                      row(
                        icon: Icons.notifications_rounded,
                        title: 'Notifications',
                        onTap: () => context.push('/notifications'),
                        divider: false,
                      ),
                    ]),
                    const SizedBox(height: Space.s4),
                    card([
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Space.s4,
                        ),
                        minTileHeight: Sizes.tapMin,
                        secondary: Icon(
                          Icons.dark_mode_rounded,
                          color: c.textSoft,
                        ),
                        title: Text(
                          'Dark mode',
                          style: THType.button.copyWith(color: c.text),
                        ),
                        value: themeMode == ThemeMode.dark,
                        onChanged: (enabled) => ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(
                              enabled ? ThemeMode.dark : ThemeMode.light,
                            ),
                      ),
                      Divider(height: 1, color: c.line),
                      row(
                        icon: Icons.help_outline_rounded,
                        title: 'Help and support',
                        onTap: () => context.push('/settings'),
                        divider: false,
                      ),
                    ]),
                    const SizedBox(height: Space.s4),
                    THButton(
                      key: const Key('sign_out_button'),
                      label: 'Sign out',
                      kind: THButtonKind.ghost,
                      onPressed: () async {
                        ref
                            .read(incomingOfferCoordinatorProvider.notifier)
                            .stop();
                        await ref.read(authViewModelProvider.notifier).logout();
                        ref.invalidate(profileViewModelProvider);
                        if (context.mounted) context.go('/auth');
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: c.paper,
            appBar: THAppBar(
              title: 'Personal details',
              leading: THIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: 'Back to profile',
                onPressed: () {
                  if (_isEditing) _toggleEditing(profile);
                  setState(() => _showDetails = false);
                },
              ),
              actions: [
                THIconButton(
                  key: const Key('toggle_edit_mode_button'),
                  icon: _isEditing ? Icons.close_rounded : Icons.edit_outlined,
                  semanticLabel: _isEditing ? 'Cancel editing' : 'Edit profile',
                  onPressed: () => _toggleEditing(profile),
                ),
                THIconButton(
                  icon: Icons.settings_outlined,
                  semanticLabel: 'Settings',
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Sizes.gutter,
                  Space.s1_5,
                  Sizes.gutter,
                  thDockClearance(context),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Space.s4,
                    children: [
                      Center(
                        child: THAvatar(
                          '${profile['firstName']?[0] ?? ''}${profile['lastName']?[0] ?? ''}',
                          size: THAvatarSize.lg,
                        ),
                      ),
                      Center(
                        child: THBadge(
                          isTradie ? 'Tradie' : 'Homeowner',
                          kind: THBadgeKind.accent,
                          icon: isTradie
                              ? Icons.handyman_outlined
                              : Icons.home_outlined,
                        ),
                      ),
                      THCard(
                        key: const Key('details_personal_card'),
                        children: [
                          const THText('Personal', style: THTextStyle.title),
                          const SizedBox(height: Space.s2),
                          if (_isEditing) ...[
                            Column(
                              spacing: Space.s3,
                              children: [
                                THTextField(
                                  label: 'First Name',
                                  controller: _firstNameCtrl,
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                THTextField(
                                  label: 'Last Name',
                                  controller: _lastNameCtrl,
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                THTextField(
                                  label: 'Phone Number',
                                  controller: _phoneCtrl,
                                ),
                              ],
                            ),
                          ] else ...[
                            valueRow('First Name', _firstNameCtrl.text),
                            valueRow(
                              'Last Name',
                              _lastNameCtrl.text,
                              divider: true,
                            ),
                            valueRow('Email', _emailCtrl.text, divider: true),
                            valueRow(
                              'Phone Number',
                              _phoneCtrl.text,
                              divider: true,
                            ),
                          ],
                        ],
                      ),
                      if (isTradie) ...[
                        THCard(
                          key: const Key('details_tradie_card'),
                          children: [
                            const THText(
                              'Tradie Information',
                              style: THTextStyle.title,
                            ),
                            const SizedBox(height: Space.s2),
                            if (_isEditing) ...[
                              Column(
                                spacing: Space.s3,
                                children: [
                                  THTextField(
                                    label: 'Business Name',
                                    controller: _businessNameCtrl,
                                  ),
                                  THTextField(
                                    label: 'Trade Type',
                                    controller: _tradeTypeCtrl,
                                  ),
                                ],
                              ),
                            ] else ...[
                              valueRow('Business Name', _businessNameCtrl.text),
                              valueRow(
                                'Trade Type',
                                _tradeTypeCtrl.text,
                                divider: true,
                              ),
                            ],
                            const SizedBox(height: Space.s2),
                            Divider(height: 1, color: c.line),
                            // Same source of truth as the home switch: the
                            // profile view model (saves immediately).
                            InkWell(
                              key: const Key('details_availability_row'),
                              onTap: _availabilitySaving
                                  ? null
                                  : () => _setAvailability(!isAvailable),
                              borderRadius: BorderRadius.circular(
                                Radii.control,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: Space.s2,
                                ),
                                child: Row(
                                  spacing: Space.s3,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        spacing: Space.s1,
                                        children: [
                                          Text(
                                            'Available for jobs',
                                            style: THType.button.copyWith(
                                              color: c.text,
                                            ),
                                          ),
                                          Text(
                                            'Controls whether new leads reach you',
                                            style: THType.meta.copyWith(
                                              color: c.textSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    THSwitch(
                                      key: const Key('details_availability'),
                                      on: isAvailable,
                                      onChanged: _availabilitySaving
                                          ? null
                                          : _setAvailability,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        THCard(
                          key: const Key('details_payout_card'),
                          children: [
                            const THText(
                              'Payout Details',
                              style: THTextStyle.title,
                            ),
                            const SizedBox(height: Space.s1),
                            THText(
                              _bankVerified
                                  ? 'Verified — used for your weekly payout.'
                                  : 'Used for your weekly payout. Only you can see this.',
                              style: THTextStyle.meta,
                              tone: THTone.soft,
                            ),
                            const SizedBox(height: Space.s2),
                            if (_isEditing) ...[
                              Column(
                                spacing: Space.s3,
                                children: [
                                  THTextField(
                                    label: 'Bank Account Name',
                                    controller: _bankNameCtrl,
                                  ),
                                  THTextField(
                                    label: 'Bank Account Number',
                                    hint: 'XX-XXXX-XXXXXXX-XX',
                                    controller: _bankNumberCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: _bankNumberValidator,
                                  ),
                                ],
                              ),
                            ] else ...[
                              valueRow('Bank Account Name', _bankNameCtrl.text),
                              valueRow(
                                'Bank Account Number',
                                _bankNumberCtrl.text,
                                divider: true,
                              ),
                            ],
                            if (_isEditing && _bankVerified) ...[
                              const SizedBox(height: Space.s2),
                              THText(
                                'If you change your bank account number, we will re-verify it before your next payout.',
                                style: THTextStyle.meta,
                                tone: THTone.soft,
                              ),
                            ],
                          ],
                        ),
                      ],

                      if (_isEditing) ...[
                        const SizedBox(height: Space.s3),
                        THButton(
                          label: 'Save Changes',
                          loading: profileState.isLoading,
                          onPressed: profileState.isLoading
                              ? null
                              : _saveProfile,
                        ),
                      ],
                      const SizedBox(height: Space.s2),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
