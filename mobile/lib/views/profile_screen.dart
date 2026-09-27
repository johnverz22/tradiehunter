import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/design_tokens.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/fixo_buttons.dart';
import '../widgets/fixo_cards.dart';
import '../widgets/fixo_states.dart';
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
  
  bool _isAvailable = true;
  bool _formInitialized = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _tradeTypeCtrl = TextEditingController();
    _businessNameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _tradeTypeCtrl.dispose();
    _businessNameCtrl.dispose();
    super.dispose();
  }

  void _initForms(Map<String, dynamic> profile) {
    _firstNameCtrl.text = profile['firstName'] ?? '';
    _lastNameCtrl.text = profile['lastName'] ?? '';
    _phoneCtrl.text = profile['phoneNumber'] ?? '';
    _tradeTypeCtrl.text = profile['tradeType'] ?? '';
    _businessNameCtrl.text = profile['businessName'] ?? '';
    _isAvailable = profile['isAvailable'] ?? true;
    _formInitialized = true;
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updateData = {
        'firstName': _firstNameCtrl.text,
        'lastName': _lastNameCtrl.text,
        'phoneNumber': _phoneCtrl.text,
        'tradeType': _tradeTypeCtrl.text.isNotEmpty ? _tradeTypeCtrl.text : null,
        'businessName': _businessNameCtrl.text.isNotEmpty ? _businessNameCtrl.text : null,
        'isAvailable': _isAvailable,
      };

      final success = await ref.read(profileViewModelProvider.notifier).updateProfile(updateData);
      if (success && mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileViewModelProvider);

    if (profileState.isLoading && profileState.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const FixoLoading(label: 'Loading profile…'),
      );
    }

    if (profileState.error != null && profileState.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
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
        appBar: AppBar(title: const Text('Profile')),
        body: const FixoEmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile not found',
        ),
      );
    }

    // Init once per profile load — never overwrite user edits in build.
    if (!_formInitialized) _initForms(profile);
    final isTradie = profile['role'] == 1; // UserRole: Homeowner=0, Tradie=1, Admin=2

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Cancel editing' : 'Edit profile',
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  // Reset form on cancel.
                  _formInitialized = false;
                  _initForms(profile);
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: StatusBadge(
                  label: isTradie ? 'Tradie' : 'Homeowner',
                  kind: FixoBadgeKind.neutral,
                ),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _firstNameCtrl,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameCtrl,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                enabled: false,
                initialValue: profile['email'] ?? '',
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              
              if (isTradie) ...[
                const SizedBox(height: 32),
                Text(
                  'Tradie Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _businessNameCtrl,
                  enabled: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tradeTypeCtrl,
                  enabled: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Trade Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Always interactive — tradies can toggle availability
                // without entering full edit mode. The value is included in
                // the save payload when saving other fields.
                SwitchListTile(
                  title: const Text('Available for jobs'),
                  value: _isAvailable,
                  onChanged: (val) => setState(() => _isAvailable = val),
                ),
              ],
              
              if (_isEditing) ...[
                const SizedBox(height: 32),
                FixoPrimaryButton(
                  label: 'Save Changes',
                  isLoading: profileState.isLoading,
                  onPressed: profileState.isLoading ? null : _saveProfile,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
