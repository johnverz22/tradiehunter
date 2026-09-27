import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/design_tokens.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('theme_mode') ?? 0;
    state = ThemeMode.values[index];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }
}

/// Mockup 14-settings: grouped rows (Account / Preferences / Support),
/// brand-500 notification toggle, red outlined Log Out, version label.
/// Theme + logout wiring is live; other rows are TODO(backend) stubs.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // TODO(backend): load/save via PATCH /api/users/me {notifications, language}.
  bool _notifications = true;

  void _stub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          _GroupLabel('Account'),
          _Tile(
              label: 'Personal Details',
              // /profile lives inside the ShellRoute while /settings is a
              // root-level route pushed on top of it. Pushing /profile here
              // would mount a second ShellRoute with the same navigator key
              // (-> '!keyReservation.contains(key)' crash). Pop back to the
              // underlying profile instead; fall back to go() for deep-links.
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/profile');
                }
              }),
          // TODO(backend): payments are V1.1+ / out of MVP scope.
          _Tile(
              label: 'Payment Methods',
              onTap: () => _stub('Payment methods')),
          const SizedBox(height: 16),
          _GroupLabel('Preferences'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notifications',
                style: TextStyle(fontSize: 16)),
            value: _notifications,
            activeThumbColor: DesignTokens.paperLight,
            activeTrackColor: DesignTokens.brand500,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          _divider(isDark),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Language',
                style: TextStyle(fontSize: 16)),
            subtitle: const Text('English'),
            trailing: Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            // TODO(backend): options from GET /api/config/locale.
            onTap: () => _stub('Language'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title:
                const Text('Theme', style: TextStyle(fontSize: 16)),
            subtitle: Text(themeMode.name[0].toUpperCase() +
                themeMode.name.substring(1)),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              onChanged: (m) {
                if (m != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(m);
                }
              },
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GroupLabel('Support'),
          _Tile(label: 'Help Center', onTap: () => _stub('Help center')),
          _Tile(label: 'Terms', onTap: () => _stub('Terms')),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () async {
                await ref.read(authViewModelProvider.notifier).logout();
                ref.invalidate(profileViewModelProvider);
                if (context.mounted) context.go('/auth');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignTokens.red,
                side: const BorderSide(color: DesignTokens.red),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radius),
                ),
              ),
              child: const Text('Log Out',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.4))),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 1,
        color:
            isDark ? DesignTokens.paperLineDark : DesignTokens.paperLineLight,
      );
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title:
              Text(label, style: const TextStyle(fontSize: 16)),
          trailing: Icon(Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          onTap: onTap,
        ),
        Divider(
          height: 1,
          color: isDark
              ? DesignTokens.paperLineDark
              : DesignTokens.paperLineLight,
        ),
      ],
    );
  }
}
