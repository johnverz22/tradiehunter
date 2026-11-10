import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/design_tokens.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/locale_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'widgets/fixo_feedback.dart';
import 'widgets/fixo_rows.dart';
import '../widgets/fixo_buttons.dart';
import '../widgets/fixo_cards.dart';
import '../feedback/fixo_notice.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
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

/// GET /api/config/locale — the only locale source of truth on the backend.
/// Returns LocaleOptions {defaultCurrency, currencySymbol, phoneCountryCode,
/// defaultTimezone, distanceUnit}. No auth required.
/// Lives in `viewmodels/locale_viewmodel.dart` — the onboarding wizard
/// reads the currency symbol from it too.

/// Mockup 14-settings: grouped rows (Account / Preferences / Support),
/// brand-500 notification toggle, red outlined Log Out, version label.
/// Theme + logout wiring is live; locale row reads GET /api/config/locale.
/// Profile edits go through PUT /api/profile (no PATCH /api/users/me exists).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // No backend notifications/language setting exists — profile update is
  // PUT /api/profile (firstName/lastName/phone/tradie fields only).
  // This toggle is device-local until a backend preference is added.
  bool _notifications = true;

  void _stub(String label) {
    FixoNotice.info(context, NoticeCopy.stubUnavailable(label));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = theme.brightness == Brightness.dark;
    final localeAsync = ref.watch(localeConfigProvider);
    final isTradie = ref.watch(profileViewModelProvider).profile?['role'] == 1;

    return Scaffold(
      appBar: const FixoGradientAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s6, Space.s2, Space.s6, Space.s7),
        children: [
          FixoSectionLabel(label: 'Account', uppercase: true),
          FixoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Tile(
                  label: 'Personal Details',
                  onTap: () => context.go('/profile'),
                  showDivider: isTradie || true,
                ),
                // Tradie payout details live on the self-profile form (PUT
                // /api/profile) — no separate settings endpoint exists.
                if (isTradie)
                  _Tile(
                    label: 'Payout Details',
                    onTap: () => context.go('/profile'),
                    showDivider: true,
                  ),
                // Payments are V1.1+ / out of MVP scope per MVP-SPEC — no backend
                // endpoint exists. Row stays as an explicit coming-soon placeholder.
                _Tile(
                  label: 'Payment Methods',
                  onTap: () => _stub('Payment methods (V1.1)'),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s4),
          FixoSectionLabel(label: 'Preferences', uppercase: true),
          FixoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4),
                  minTileHeight: 56,
                  title: const Text('Notifications', style: TextStyle(fontSize: DesignTokens.fontSizeH3)),
                  subtitle: const Text(
                    'On this device only',
                    style: TextStyle(fontSize: DesignTokens.fontSizeCaption),
                  ),
                  value: _notifications,
                  activeThumbColor: DesignTokens.paperLight,
                  activeTrackColor: DesignTokens.brand500,
                  onChanged: (v) => setState(() => _notifications = v),
                ),
                _divider(isDark),
                localeAsync.when(
                  loading: () => const ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: Space.s4),
                    minTileHeight: 56,
                    title: Text('Region', style: TextStyle(fontSize: DesignTokens.fontSizeH3)),
                    subtitle: Text('Loading…'),
                  ),
                  error: (_, _) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4),
                    minTileHeight: 56,
                    title: const Text('Region', style: TextStyle(fontSize: DesignTokens.fontSizeH3)),
                    subtitle: const Text('Unavailable offline'),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurface.withValues(alpha: Alpha.borderMid),
                    ),
                    onTap: () => _stub('Region'),
                  ),
                  data: (locale) {
                    final currency = regionLabel(locale);
                    final tz = locale?['defaultTimezone'] as String? ?? '';
                    final unit = locale?['distanceUnit'] as String? ?? 'km';
                    final subtitle = tz.isNotEmpty
                        ? '$currency · $tz · $unit'
                        : currency;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4),
                      minTileHeight: 56,
                      title: const Text('Region', style: TextStyle(fontSize: DesignTokens.fontSizeH3)),
                      subtitle: Text(subtitle),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface.withValues(alpha: Alpha.borderMid),
                      ),
                      onTap: () => _showLocaleSheet(context, locale),
                    );
                  },
                ),
                _divider(isDark),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4),
                  minTileHeight: 56,
                  title: const Text('Theme', style: TextStyle(fontSize: DesignTokens.fontSizeH3)),
                  subtitle: Text(
                    themeMode.name[0].toUpperCase() + themeMode.name.substring(1),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: Alpha.borderMid),
                  ),
                  onTap: () => _showThemeSheet(context, ref, themeMode),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s4),
          FixoSectionLabel(label: 'Support', uppercase: true),
          FixoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Tile(label: 'Help Center', onTap: () => _stub('Help center')),
                _Tile(
                  label: 'Terms',
                  onTap: () => _stub('Terms'),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s7),
          SizedBox(
            width: double.infinity,
            height: DesignTokens.heightSecondary,
            child: TextButton.icon(
              key: const Key('sign_out_button'),
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: DesignTokens.inkDanger(isDark),
              ),
              onPressed: () async {
                await ref.read(authViewModelProvider.notifier).logout();
                ref.invalidate(profileViewModelProvider);
                if (context.mounted) context.go('/auth');
              },
              style: TextButton.styleFrom(
                backgroundColor: isDark
                    ? DesignTokens.inkDanger(isDark).withValues(alpha: Alpha.tintAccent)
                    : DesignTokens.red.withValues(alpha: Alpha.tintStandard),
                foregroundColor: DesignTokens.inkDanger(isDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusControl,
                  ),
                ),
              ),
              label: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FW.semibold),
              ),
            ),
          ),
          const SizedBox(height: Space.s4),
          Center(
            child: localeAsync.maybeWhen(
              data: (locale) {
                final appName =
                    (locale?['brand'] as Map<String, dynamic>?)?['appName']
                        as String? ??
                    'TradieHunter';
                return Text(
                  '$appName v1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: Alpha.shadow),
                  ),
                );
              },
              orElse: () => Text(
                'TradieHunter v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: Alpha.shadow),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.navClearance),
        ],
      ),
    );
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s6, Space.s4, Space.s6, Space.s2),
              child: Text(
                'Theme',
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FW.semibold),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                minTileHeight: 48,
                title: Text(
                  mode.name[0].toUpperCase() + mode.name.substring(1),
                ),
                trailing: mode == current
                    ? Icon(Icons.check, color: DesignTokens.brand500)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
    height: 1,
    color: isDark ? DesignTokens.paperLineDark : DesignTokens.paperLineLight,
  );

  void _showLocaleSheet(BuildContext context, Map<String, dynamic>? locale) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: FixoPadding.page,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Region',
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FW.semibold),
              ),
              const SizedBox(height: Space.s3),
              FixoSummaryRow(label: 'Region', value: regionLabel(locale)),
              FixoSummaryRow(label: 'Phone code', value: '${locale?['phoneCountryCode'] ?? '+64'}'),
              FixoSummaryRow(label: 'Timezone', value: '${locale?['defaultTimezone'] ?? 'Pacific/Auckland'}'),
              FixoSummaryRow(label: 'Distance', value: '${locale?['distanceUnit'] ?? 'km'}'),
              const SizedBox(height: Space.s2),
              Text(
                'Set by GET /api/config/locale — read-only.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}


class _Tile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool showDivider;
  const _Tile({
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4),
          minTileHeight: 56,
          title: Text(label, style: const TextStyle(fontSize: DesignTokens.fontSizeH3)),
          trailing: Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurface.withValues(alpha: Alpha.borderMid),
          ),
          onTap: onTap,
        ),
        if (showDivider)
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
