// ThProfileScreen: v2 self profile (migration plan 3.3, id `profile`).
//
// Hand-owned port of views/profile_screen.dart. Same edit-mode flow
// (app-bar pencil + body toggle, forms re-initialized on exit), same
// immediate-save availability switch (POST /api/profile/availability), same
// NZ bank-number validation, same payload keys on PUT /api/profile, same
// loading/error/empty states. Keys preserved: toggle_edit_mode_button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/profile_repository.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import '../feedback/th_state_view.dart';
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

  bool _isAvailable = true;
  bool _formInitialized = false;
  bool _availabilitySaving = false;
  bool _bankVerified = false;

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
    _isAvailable = profile['isAvailable'] ?? true;
    _bankVerified = profile['bankAccountVerified'] == true;
    _formInitialized = true;
  }

  // Availability is a standalone switch — it saves immediately through the
  // dedicated endpoint rather than waiting for a full form save.
  Future<void> _setAvailability(bool value) async {
    if (_availabilitySaving) return;
    setState(() {
      _isAvailable = value;
      _availabilitySaving = true;
    });
    try {
      await ref.read(profileRepositoryProvider).updateAvailability(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAvailable = !value);
      final msg = e is ProfileApiException
          ? e.message
          : 'Could not update availability.';
      THNotice.error(context, msg);
    } finally {
      if (mounted) setState(() => _availabilitySaving = false);
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
        'isAvailable': _isAvailable,
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

          final appBar = THAppBar(title: 'Profile', showBack: false);

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

          return Scaffold(
            backgroundColor: c.paper,
            appBar: THAppBar(
              title: 'Profile',
              showBack: false,
              actions: [
                THIconButton(
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
                  Sizes.dockClearance,
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
                      Center(
                        child: TextButton.icon(
                          key: const Key('toggle_edit_mode_button'),
                          onPressed: () => _toggleEditing(profile),
                          icon: Icon(
                            _isEditing
                                ? Icons.close_rounded
                                : Icons.edit_rounded,
                            size: Sizes.icon,
                          ),
                          label: Text(
                            _isEditing ? 'Cancel Editing' : 'Edit Profile',
                          ),
                        ),
                      ),
                      THTextField(
                        label: 'First Name',
                        controller: _firstNameCtrl,
                        enabled: _isEditing,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      THTextField(
                        label: 'Last Name',
                        controller: _lastNameCtrl,
                        enabled: _isEditing,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      THTextField(
                        label: 'Email',
                        controller: _emailCtrl,
                        enabled: false,
                      ),
                      THTextField(
                        label: 'Phone Number',
                        controller: _phoneCtrl,
                        enabled: _isEditing,
                      ),

                      if (isTradie) ...[
                        const SizedBox(height: Space.s3),
                        Text(
                          'Tradie Information',
                          style: THType.h2.copyWith(color: c.text),
                        ),
                        THTextField(
                          label: 'Business Name',
                          controller: _businessNameCtrl,
                          enabled: _isEditing,
                        ),
                        THTextField(
                          label: 'Trade Type',
                          controller: _tradeTypeCtrl,
                          enabled: _isEditing,
                        ),
                        // Saves immediately via POST /api/profile/availability —
                        // this switch never waits on form save.
                        InkWell(
                          onTap: _availabilitySaving
                              ? null
                              : () => _setAvailability(!_isAvailable),
                          borderRadius: BorderRadius.circular(Radii.control),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Space.s2,
                              horizontal: Space.s1,
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
                                  on: _isAvailable,
                                  onChanged: _availabilitySaving
                                      ? null
                                      : _setAvailability,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.s3),
                        Text(
                          'Payout Details',
                          style: THType.h2.copyWith(color: c.text),
                        ),
                        Text(
                          _bankVerified
                              ? 'Verified — used for your weekly payout.'
                              : 'Used for your weekly payout. Only you can see this.',
                          style: THType.meta.copyWith(color: c.textSoft),
                        ),
                        THTextField(
                          label: 'Bank Account Name',
                          controller: _bankNameCtrl,
                          enabled: _isEditing,
                        ),
                        THTextField(
                          label: 'Bank Account Number',
                          hint: 'XX-XXXX-XXXXXXX-XX',
                          controller: _bankNumberCtrl,
                          enabled: _isEditing,
                          keyboardType: TextInputType.number,
                          validator: _bankNumberValidator,
                        ),
                        if (_isEditing && _bankVerified)
                          Text(
                            'If you change your bank account number, we will re-verify it before your next payout.',
                            style: THType.meta.copyWith(color: c.textSoft),
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
