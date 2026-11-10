import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/profile_repository.dart';
import '../theme/design_tokens.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/fixo_buttons.dart';
import '../widgets/fixo_cards.dart';
import '../widgets/fixo_states.dart';
import '../feedback/fixo_notice.dart';

import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
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
      FixoNotice.error(context, msg);
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
        FixoNotice.success(context, NoticeCopy.profileUpdated);
      }
    }
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    required bool isEditable,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final readOnlyBg = isDark
        ? Colors.white.withValues(alpha: Alpha.overlay)
        : DesignTokens.surfaceDisabled(false);
    final editableBg = DesignTokens.surfaceCard(isDark);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: isEditable ? editableBg : readOnlyBg,
      constraints: const BoxConstraints(minHeight: DesignTokens.heightInput),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide(
          color: isEditable
              ? DesignTokens.borderControl(isDark)
              : Colors.transparent,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide(
          color: isEditable
              ? DesignTokens.borderControl(isDark)
              : Colors.transparent,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: Alpha.tintStandard) : Colors.black.withValues(alpha: Alpha.tintStandard),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: const BorderSide(
          color: DesignTokens.amber,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileViewModelProvider);

    if (profileState.isLoading && profileState.profile == null) {
      return Scaffold(
        appBar: const FixoGradientAppBar(title: 'Profile', showBack: false),
        body: const FixoLoading(label: 'Loading profile…'),
      );
    }

    if (profileState.error != null && profileState.profile == null) {
      return Scaffold(
        appBar: const FixoGradientAppBar(title: 'Profile', showBack: false),
        body: FixoErrorState(
          message: 'Error: ${profileState.error}',
          onRetry: () =>
              ref.read(profileViewModelProvider.notifier).loadProfile(),
        ),
      );
    }

    final profile = profileState.profile;
    if (profile == null) {
      return Scaffold(
        appBar: const FixoGradientAppBar(title: 'Profile', showBack: false),
        body: const FixoEmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile not found',
        ),
      );
    }

    // Init once per profile load — never overwrite user edits in build.
    if (!_formInitialized) _initForms(profile);
    final isTradie =
        profile['role'] ==
        1; // UserRole: Homeowner=0, Tradie=1, Staff=2, Superadmin=3

    return Scaffold(
      appBar: FixoGradientAppBar(
        title: 'Profile',
        showBack: false,
        actions: [
          FixoAppBarAction(
            icon: _isEditing ? Icons.close_rounded : Icons.edit_outlined,
            tooltip: _isEditing ? 'Cancel editing' : 'Edit profile',
            onTap: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _formInitialized = false;
                  _initForms(profile);
                }
              });
            },
          ),
          FixoAppBarAction(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.s6),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DesignTokens.brand500,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${profile['firstName']?[0] ?? ''}${profile['lastName']?[0] ?? ''}',
                    style: const TextStyle(
                      fontFamily: DesignTokens.fontDisplay,
                      fontWeight: FW.semibold,
                      fontSize: DesignTokens.fontSizeDisplay,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s4),
              Center(
                child: StatusBadge(
                  label: isTradie ? 'Tradie' : 'Homeowner',
                  kind: FixoBadgeKind.waiting,
                  icon: isTradie ? Icons.handyman_outlined : Icons.home_outlined,
                ),
              ),
              const SizedBox(height: Space.s3),
              Center(
                child: TextButton.icon(
                  key: const Key('toggle_edit_mode_button'),
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                      if (!_isEditing) {
                        _formInitialized = false;
                        _initForms(profile);
                      }
                    });
                  },
                  icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded, size: 18),
                  label: Text(_isEditing ? 'Cancel Editing' : 'Edit Profile'),
                ),
              ),
              const SizedBox(height: Space.s6),

              TextFormField(
                controller: _firstNameCtrl,
                enabled: _isEditing,
                decoration: _inputDecoration(
                  context,
                  labelText: 'First Name',
                  isEditable: _isEditing,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: Space.s4),
              TextFormField(
                controller: _lastNameCtrl,
                enabled: _isEditing,
                decoration: _inputDecoration(
                  context,
                  labelText: 'Last Name',
                  isEditable: _isEditing,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: Space.s4),
              TextFormField(
                enabled: false,
                initialValue: profile['email'] ?? '',
                decoration: _inputDecoration(
                  context,
                  labelText: 'Email',
                  isEditable: false,
                ),
              ),
              const SizedBox(height: Space.s4),
              TextFormField(
                controller: _phoneCtrl,
                enabled: _isEditing,
                decoration: _inputDecoration(
                  context,
                  labelText: 'Phone Number',
                  isEditable: _isEditing,
                ),
              ),

              if (isTradie) ...[
                const SizedBox(height: Space.s7),
                Text(
                  'Tradie Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: Space.s4),
                TextFormField(
                  controller: _businessNameCtrl,
                  enabled: _isEditing,
                  decoration: _inputDecoration(
                    context,
                    labelText: 'Business Name',
                    isEditable: _isEditing,
                  ),
                ),
                const SizedBox(height: Space.s4),
                TextFormField(
                  controller: _tradeTypeCtrl,
                  enabled: _isEditing,
                  decoration: _inputDecoration(
                    context,
                    labelText: 'Trade Type',
                    isEditable: _isEditing,
                  ),
                ),
                const SizedBox(height: Space.s4),
                // Saves immediately via POST /api/profile/availability —
                // this switch never waits on form save.
                SwitchListTile(
                  title: const Text('Available for jobs'),
                  subtitle: const Text('Controls whether new leads reach you'),
                  value: _isAvailable,
                  onChanged: _availabilitySaving ? null : _setAvailability,
                ),
                const SizedBox(height: Space.s7),
                Text(
                  'Payout Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: Space.s1),
                Text(
                  _bankVerified
                      ? 'Verified — used for your weekly payout.'
                      : 'Used for your weekly payout. Only you can see this.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Space.s4),
                TextFormField(
                  controller: _bankNameCtrl,
                  enabled: _isEditing,
                  decoration: _inputDecoration(
                    context,
                    labelText: 'Bank Account Name',
                    isEditable: _isEditing,
                  ),
                ),
                const SizedBox(height: Space.s4),
                TextFormField(
                  controller: _bankNumberCtrl,
                  enabled: _isEditing,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    context,
                    labelText: 'Bank Account Number',
                    hintText: 'XX-XXXX-XXXXXXX-XX',
                    isEditable: _isEditing,
                  ),
                  validator: _bankNumberValidator,
                ),
                if (_isEditing && _bankVerified) ...[
                  const SizedBox(height: Space.s2),
                  Text(
                    'If you change your bank account number, we will re-verify it before your next payout.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],

              if (_isEditing) ...[
                const SizedBox(height: Space.s7),
                FixoPrimaryButton(
                  label: 'Save Changes',
                  isLoading: profileState.isLoading,
                  onPressed: profileState.isLoading ? null : _saveProfile,
                ),
              ],
              const SizedBox(height: Space.s2),
            ],
          ),
        ),
      ),
    );
  }
}
