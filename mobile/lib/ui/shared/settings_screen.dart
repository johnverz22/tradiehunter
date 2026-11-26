// ThSettingsScreen: v2 settings (migration plan 3.3, id `settings` — no v2
// mockup, tokens-only composition per D-4).
//
// Hand-owned port of views/settings_screen.dart. Same rows and actions:
// Account (Personal Details / tradie Payout Details / stub Payment Methods),
// Preferences (device-local Notifications toggle, Region from
// GET /api/config/locale, live Theme picker), Support stubs, a ghost Sign out
// (S-05: same label and weight as Profile, not a solid red block; key
// sign_out_button — also used by integration helpers) and the version label.
// themeModeProvider is imported from its viewmodels home (plan 2.11).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';

class ThSettingsScreen extends ConsumerStatefulWidget {
  const ThSettingsScreen({super.key});

  @override
  ConsumerState<ThSettingsScreen> createState() => _ThSettingsScreenState();
}

class _ThSettingsScreenState extends ConsumerState<ThSettingsScreen> {
  // No backend notifications/language setting exists — profile update is
  // PUT /api/profile (firstName/lastName/phone/tradie fields only).
  // This toggle is device-local until a backend preference is added.
  bool _notifications = true;

  void _stub(String label) {
    THNotice.info(context, NoticeCopy.stubUnavailable(label));
  }

  String _capitalize(ThemeMode mode) =>
      mode.name[0].toUpperCase() + mode.name.substring(1);

  @override
  Widget build(BuildContext context) {
    return ThScope(
      themeMode: ref.watch(themeModeProvider),
      child: Builder(
        builder: (context) {
          final c = context.th;
          final themeMode = ref.watch(themeModeProvider);
          final localeAsync = ref.watch(localeConfigProvider);
          final isTradie =
              ref.watch(profileViewModelProvider).profile?['role'] == 1;

          Widget card(List<Widget> children) => Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: c.line),
            ),
            clipBehavior: Clip.antiAlias,
            // ListTile paints on the nearest Material — give it one inside
            // the decorated container so ink/tap effects stay visible.
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: children),
            ),
          );

          Widget divider() => Divider(height: 1, color: c.line);

          Widget sectionLabel(String label) => Padding(
            padding: const EdgeInsets.only(left: Space.s1, bottom: Space.s2),
            child: Text(
              label.toUpperCase(),
              style: THType.label.copyWith(color: c.textSoft),
            ),
          );

          Widget tile({
            required String label,
            String? subtitle,
            VoidCallback? onTap,
            bool showDivider = true,
          }) => Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Space.s4,
                ),
                minTileHeight: 56,
                title: Text(
                  label,
                  style: THType.button.copyWith(color: c.text),
                ),
                subtitle: subtitle == null
                    ? null
                    : Text(
                        subtitle,
                        style: THType.meta.copyWith(color: c.textSoft),
                      ),
                trailing: onTap == null
                    ? null
                    : Icon(Icons.chevron_right, color: c.textSoft),
                onTap: onTap,
              ),
              if (showDivider) divider(),
            ],
          );

          return Scaffold(
            backgroundColor: c.paper,
            appBar: const THAppBar(title: 'Settings'),
            body: ListView(
              padding: EdgeInsets.fromLTRB(
                Space.s6,
                Space.s2,
                Space.s6,
                thDockClearance(context),
              ),
              children: [
                sectionLabel('Account'),
                card([
                  tile(
                    label: 'Personal Details',
                    onTap: () => context.go('/profile'),
                  ),
                  // Tradie payout details live on the self-profile form (PUT
                  // /api/profile) — no separate settings endpoint exists.
                  if (isTradie)
                    tile(
                      label: 'Payout Details',
                      onTap: () => context.go('/profile'),
                    ),
                  // Payments are V1.1+ / out of MVP scope per MVP-SPEC — no
                  // backend endpoint exists. Row stays as an explicit
                  // coming-soon placeholder.
                  tile(
                    label: 'Payment Methods',
                    onTap: () => _stub('Payment methods (V1.1)'),
                    showDivider: false,
                  ),
                ]),
                const SizedBox(height: Space.s4),
                sectionLabel('Preferences'),
                card([
                  // Device-local toggle — no persistence exists on the
                  // backend or on-device (v1 behaviour preserved).
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Space.s4,
                    ),
                    minTileHeight: 56,
                    activeThumbColor: c.onBrand,
                    activeTrackColor: c.brand,
                    title: Text(
                      'Notifications',
                      style: THType.button.copyWith(
                        color: c.text,
                        fontSize: THType.button.fontSize,
                      ),
                    ),
                    subtitle: Text(
                      'On this device only',
                      style: THType.meta.copyWith(color: c.textSoft),
                    ),
                    value: _notifications,
                    onChanged: (v) => setState(() => _notifications = v),
                  ),
                  divider(),
                  localeAsync.when(
                    loading: () => tile(
                      label: 'Region',
                      subtitle: 'Loading…',
                      showDivider: true,
                    ),
                    error: (_, _) => tile(
                      label: 'Region',
                      subtitle: 'Unavailable offline',
                      onTap: () => _stub('Region'),
                    ),
                    data: (locale) {
                      final currency = regionLabel(locale);
                      final tz = locale?['defaultTimezone'] as String? ?? '';
                      final unit = locale?['distanceUnit'] as String? ?? 'km';
                      final subtitle = tz.isNotEmpty
                          ? '$currency · $tz · $unit'
                          : currency;
                      return tile(
                        label: 'Region',
                        subtitle: subtitle,
                        onTap: () => _showLocaleSheet(context, locale),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Space.s4,
                    ),
                    minTileHeight: 56,
                    title: Text(
                      'Theme',
                      style: THType.button.copyWith(
                        color: c.text,
                        fontSize: THType.button.fontSize,
                      ),
                    ),
                    subtitle: Text(
                      _capitalize(themeMode),
                      style: THType.meta.copyWith(color: c.textSoft),
                    ),
                    trailing: Icon(Icons.chevron_right, color: c.textSoft),
                    onTap: () => _showThemeSheet(context, ref, themeMode),
                  ),
                ]),
                const SizedBox(height: Space.s4),
                sectionLabel('Support'),
                card([
                  tile(label: 'Help Center', onTap: () => _stub('Help center')),
                  tile(
                    label: 'Terms',
                    onTap: () => _stub('Terms'),
                    showDivider: false,
                  ),
                ]),
                const SizedBox(height: Space.s7),
                THButton(
                  key: const Key('sign_out_button'),
                  label: 'Sign out',
                  kind: THButtonKind.ghost,
                  onPressed: () async {
                    await ref.read(authViewModelProvider.notifier).logout();
                    ref.invalidate(profileViewModelProvider);
                    if (context.mounted) context.go('/auth');
                  },
                ),
                const SizedBox(height: Space.s4),
                Center(
                  child: localeAsync.maybeWhen(
                    data: (locale) {
                      final appName =
                          (locale?['brand']
                                  as Map<String, dynamic>?)?['appName']
                              as String? ??
                          'TradieHunter';
                      return Text(
                        '$appName v1.0.0',
                        style: THType.meta.copyWith(
                          fontSize: THType.compact.fontSize,
                          color: c.textSoft,
                        ),
                      );
                    },
                    orElse: () => Text(
                      'TradieHunter v1.0.0',
                      style: THType.meta.copyWith(
                        fontSize: THType.compact.fontSize,
                        color: c.textSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
              padding: const EdgeInsets.fromLTRB(
                Space.s6,
                Space.s4,
                Space.s6,
                Space.s2,
              ),
              child: Text(
                'Theme',
                style: THType.title.copyWith(fontWeight: FW.semibold),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                minTileHeight: 48,
                title: Text(
                  _capitalize(mode),
                  style: THType.button.copyWith(color: ctx.th.text),
                ),
                trailing: mode == current
                    ? Icon(Icons.check, color: ctx.th.brand)
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

  void _showLocaleSheet(BuildContext context, Map<String, dynamic>? locale) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final c = ctx.th;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Region',
                  style: THType.title.copyWith(fontWeight: FW.semibold),
                ),
                const SizedBox(height: Space.s3),
                THKeyValue('Region', regionLabel(locale), divider: true),
                THKeyValue(
                  'Phone code',
                  '${locale?['phoneCountryCode'] ?? '+64'}',
                  divider: true,
                ),
                THKeyValue(
                  'Timezone',
                  '${locale?['defaultTimezone'] ?? 'Pacific/Auckland'}',
                  divider: true,
                ),
                THKeyValue(
                  'Distance',
                  '${locale?['distanceUnit'] ?? 'km'}',
                  divider: true,
                ),
                const SizedBox(height: Space.s2),
                Text(
                  'Set by GET /api/config/locale — read-only.',
                  style: THType.meta.copyWith(color: c.textSoft),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
