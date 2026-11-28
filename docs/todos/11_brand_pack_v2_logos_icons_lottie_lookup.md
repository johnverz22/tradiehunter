# Brand pack v2: logos, app icons, email logo and the Lottie tradie lookup

> **Repo / branch:** `johnverz22/tradiehunter` @ `main`
> **Purpose:** Wire `tradiehunter-assets.zip` (house + hammer emblem, platform icon sets, `tradiehunter_loader.json` Lottie) into `web/`, `mobile/` and the backend email templates (image only), and replace the magnifying glass in the tradie lookup (matching radar) with the Lottie's rippling circles.
> **Status:** Not started. Decisions D1-D4 (section 3) need owner answers; the defaults are safe to start with. **Prepared:** 2026-11-28
> **Naming rule:** code identifiers stay `Fixo` (`package:fixo/...`, namespace `FixoApi`); user-facing text is TradieHunter. Do not rename.
> **Convention:** `[ ]` todo, `[x]` done, `[~]` parked (add why). Size: S <= 1h, M <= half a day, L >= 1 day.
> **History:** this replaces an earlier draft of todo 11 that targeted a previous asset pack (different file names, SVG animation, no Lottie). That draft was removed; nothing else references it.

---

## 0. Read first

`AGENTS.md` (mobile tokens only, web theme files are synced copies, ask before adding a dependency), `docs/DESIGN.md`, `docs/OPERATIONS.md` section 1 (Email), `docs/TESTING.md`.

Code touched: `web/index.html`, `web/public/`, `web/src/features/branding/components/`, `web/src/layout/{SidebarNav,TopBar,MobileDrawer}.tsx`, `web/src/features/auth/AdminLogin.tsx`, `docs/design/web/css/kit.css`; `mobile/pubspec.yaml`, `mobile/assets/`, `mobile/lib/ui/design/{th_tokens,th_widgets}.dart`, `mobile/lib/ui/homeowner/{ho_radar_screen,ho_matching_screen}.dart`, `mobile/lib/ui/auth/{splash,sign_in,sign_up}_screen.dart`, `mobile/android/app/src/main/`, `mobile/ios/Runner/Assets.xcassets/`, `mobile/web/`, `mobile/test/ui/phase4_ho_radar_test.dart`; `backend/Email/Layouts/_EmailLayout.cshtml`, `backend/Email/{EmailModels,EmailTemplateRenderer}.cs`, `backend/Services/SmtpEmailSender.cs`, `backend/Options/BrandOptions.cs`, `backend/FixoApi.csproj`, `backend/FixoApi.Tests/Goldens/email/`.

## 1. Asset inventory: what goes where

Paths are inside the zip (`tradiehunter-assets/`).

| Asset | Use | web | mobile | email |
|---|---|---|---|---|
| `svg/logo.svg` | Emblem, colour (navy house `#1E3A8A`, light-blue hammer `#8FA8F2`, orange handle `#B45309`), transparent background | yes (light theme) | yes (light theme) | no |
| `svg/logo-white.svg` | All-white emblem for navy / dark surfaces | yes (dark theme, sidebar, hero) | yes (dark theme, splash) | **yes**, rendered to PNG (B1) |
| `svg/logo-monochrome.svg` | All-black emblem (`#000000`) | no | reference only | no |
| `svg/logo-on-white.svg` | Emblem on a white 512 square | no | no | no |
| `web/*` (favicons, `apple-touch-icon`, `android-chrome-*`, `maskable-icon-*`, `mstile`, `safari-pinned-tab.svg`, `site.webmanifest`, `browserconfig.xml`, `head-snippet.html`) | Browser and PWA icons | yes | `mobile/web/` (subset, M5) | no |
| `web/og-image.png` | Link-preview card | **skip** (admin is behind login) | no | no |
| `ios/AppIcon.appiconset/` | Full iOS set incl. `icon-marketing-1024.png` (verified RGB, no alpha) | no | yes | no |
| `android/res/` | `mipmap-*` legacy, round, adaptive foreground and monochrome; `mipmap-anydpi-v26/*.xml`; `drawable-*/ic_stat_notification.png`; `values/ic_launcher_background.xml` (`#FFFFFF`) | no | yes | no |
| `android/play-store-icon-512.png` | Play Console upload only | no | not in repo | no |
| `animated/tradiehunter_loader.json` (+ `animated/README.md`) | **Lottie for the tradie lookup** | no (D4) | yes | no |
| `expo/*` | Expo/React Native icons | no | **not used** (mobile is Flutter) | no |
| `brand-colors.css`, `README.md` | Reference | no | no | no |
| `.DS_Store`, `__MACOSX/` | **Never commit** | | | |

## 2. Findings (verified against `main`)

| # | Finding | Evidence |
|---|---|---|
| F1 | **Palette matches the design system.** Logo hexes `#1E3A8A`, `#8FA8F2`, `#B45309` equal the brand token, dark-theme brand and accent already used by web tokens, `th_tokens.dart` and the email layout. No token retune needed. | `brand-colors.css`; `_EmailLayout.cshtml` line 73 |
| F2 | `web/public/favicon.svg` is still the Vite starter bolt (`#863bff`). No PNG favicon, no apple-touch icon. | `web/public/favicon.svg`, `web/index.html` |
| F3 | The emblem appears nowhere in UI. Web (`BrandWordmark.tsx`), mobile (`THWordmark`, `th_widgets.dart:2025`) and email all use a text wordmark. | files cited |
| F4 | Android has only `mipmap-*/ic_launcher.png`: no round icon, no `mipmap-anydpi-v26` adaptive/monochrome icon, no notification small icon (`firebase_messaging` is a dependency but the manifest has no `default_notification_icon`). iOS icon set exists but predates this pack; `launch_background.xml` is plain white. | `mobile/android/app/src/main/res`, `AndroidManifest.xml` |
| F5 | `mobile/web/manifest.json` is the Flutter default (`"A new Flutter project."`, `#0175C2`). | `mobile/web/manifest.json` |
| F6 | **Email:** header is text only (`th-header` `<td>`, navy `#1E3A8A` gradient). `BrandOptions.EmailLogoUrl` exists but is deprecated and unused; no CDN exists. `SmtpEmailSender` builds `new BodyBuilder { TextBody, HtmlBody }` (line 415) with no `LinkedResources`. Gmail/Outlook do not render SVG, so the logo must be PNG. 10 golden snapshots (`Goldens/email/*.html`) will change. | `SmtpEmailSender.cs`, `BrandOptions.cs`, goldens |
| F7 | **Lookup today:** `_Radar` in `ho_radar_screen.dart` draws 3 expanding rings (`_kRadarRings`, one colour) around a filled `Sizes.radarCore` circle holding `Icons.search`. `ho_matching_screen.dart` drives it with `_ctrl` (**2 s** `AnimationController`, hard-coded `Duration(seconds: 2)`), passed as `radar: _animationsEnabled ? _ctrl : null`. `null` means reduced motion. `THDurations.radarCycle` (2000 ms) is defined but unused. | files cited |
| F8 | **What the Lottie really is.** `tradiehunter_loader.json` (212 KB, 720x720, 60 fps, 312 frames = 5.2 s, no external assets) is a **build animation**: a house assembles piece by piece, a hammer strikes 6 times (frames 54, 84, 114, 144, 174, 204), and each strike emits expanding rings (`fx` layer: 19 ring groups in light blue `#8FA8F2`, orange `#B45309` and gold, plus flash discs and sparks). The last strike adds a large ring (about 584 px of the 720 canvas). Rings run frames 54-261; the assembled logo is on screen from about 3.7 s to 4.4 s (progress 0.71-0.85). So the ripples are **part of** the Lottie; it replaces the whole `_Radar` (core + rings), not just the magnifier. | JSON inspected |
| F9 | The house fill in the Lottie is navy `#1E3A8A`. On the dark theme's dark surface this has low contrast (see D2 and M3.5). | Lottie fills |
| F10 | `lottie` is **not** in `pubspec.yaml` (only `flutter_svg ^2.0.17`). Adding it needs owner sign-off per AGENTS.md; the request to use the Lottie is that sign-off, recorded in D1. | `pubspec.yaml` |
| F11 | The iOS pack's `Contents.json` has 18 entries; the project's has 19 (extra `iphone 29x29 @1x`, an iOS 6 size). Pack filenames (`icon-iphone-60@3x.png`) differ from the project's (`Icon-App-60x60@3x.png`), so the folder is replaced as a whole, not file by file. | both `Contents.json` |
| F12 | Existing pin-brand files in `mobile/assets/brand/` (`wordmark-*`, `splash-logo*`, `app-icon-*`, `notification-icon-24*`) are unreferenced by Dart. Only `google-g.svg` is used (`auth_common.dart:90`). | `grep -rn "assets/brand" mobile/lib` |

## 3. Decisions to confirm first (defaults are recommendations)

1. **D1: dependency.** Add `lottie: ^3.1.0` to `mobile/pubspec.yaml` (per the pack's README). Default: **yes**, this is the explicit request. No other new dependencies; icons are copied from the pack, not generated.
2. **D2: dark theme lookup.** The navy house has weak contrast on dark surfaces (F9). Default: render the Lottie directly in light theme; in dark theme place it on a circular light surface (M3.5). Confirm on device first; if it reads fine, drop the chip.
3. **D3: email wordmark.** "Image only" is read as: the email carries the logo as a PNG image (no SVG, no Lottie, no web fonts for the mark). Default: PNG emblem **plus the existing live-text wordmark** next to it, so image blocking and plain-text twins keep working. If the owner wants the text removed too, that needs a rendered lockup PNG (the pack has none) and a text alternative.
4. **D4: web Lottie.** Web is admin only and has no tradie-lookup screen. Default: **no Lottie on web.** (Adding one would need `lottie-react` and a sign-off.)

Record outcomes in section 9.

## 4. Rules for the implementing model

- Copy files byte-for-byte from the zip. Do not re-export, recolour or re-trace them.
- **Never commit** `.DS_Store`, `__MACOSX/`, `expo/`, `web/og-image.png` (D-skip), or the zip itself.
- Web theme files are synced copies: author CSS in `docs/design/web/css/kit.css`, then `npm run design:sync` in `web/`. Never edit `web/src/theme/*`.
- Mobile: no raw numbers or `Color(0x...)` in widget files (AGENTS.md). New sizes and durations go in `th_tokens.dart` (`Sizes`, `THDurations`); the Lottie keeps its own artwork colours.
- Honour reduced motion. Keep `ValueKey('matching-radar')` on the animated lookup and all existing `Semantics`/`Key`s.
- The emblem next to a text wordmark is decorative: `alt=""` (web, email), `excludeFromSemantics`/`excludeSemantics` (mobile). The text keeps the accessible name.
- Both themes (light and dark) are required for every in-app use.
- Update docs in the same PR via the `docs-sync` skill.

## Phase A: Canonical copy of the source art

- [ ] **A1** Add `docs/design/brand/` with: `svg/logo.svg`, `svg/logo-white.svg`, `svg/logo-monochrome.svg`, `svg/logo-on-white.svg`, `animated/tradiehunter_loader.json`, `animated/README.md`, and a short `README.md` (the inventory in section 1 plus the colour rules). This is the re-export source when the art changes. Do not copy the platform folders here; they live in their targets. (S)

## Phase W: Web (`web/`, admin dashboard)

- [ ] **W1 Browser icons.** Copy into `web/public/` (overwriting the Vite `favicon.svg`): `favicon.svg`, `favicon.ico`, `favicon-16x16.png`, `favicon-32x32.png`, `favicon-48x48.png`, `apple-touch-icon.png`, `android-chrome-192x192.png`, `android-chrome-512x512.png`, `maskable-icon-192x192.png`, `maskable-icon-512x512.png`, `mstile-150x150.png`, `safari-pinned-tab.svg`, `site.webmanifest`, `browserconfig.xml`. (S)
- [ ] **W2 `index.html`.** Replace the single `<link rel="icon" type="image/svg+xml" href="/favicon.svg" />` with the pack's `head-snippet.html` **minus the `og:image` line** (D-skip). Keep the existing `theme-color` `#1E3A8A` (the snippet's value is identical, so do not duplicate it). Result:
  ```html
  <link rel="icon" href="/favicon.ico" sizes="48x48" />
  <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
  <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
  <link rel="mask-icon" href="/safari-pinned-tab.svg" color="#1E3A8A" />
  <link rel="manifest" href="/site.webmanifest" />
  <meta name="msapplication-config" content="/browserconfig.xml" />
  ```
  Check `web/Dockerfile`/nginx config serves `.webmanifest` with a JSON content type and that `public/` files are not behind the auth proxy. (S)
- [ ] **W3 Emblem files for the shell.** Copy `svg/logo.svg` and `svg/logo-white.svg` to `web/public/brand/` as `logo.svg` and `logo-white.svg`. (S)
- [ ] **W4 `BrandMark` component.** `web/src/features/branding/components/BrandMark.tsx`, two images, fixed size (no layout shift):
  ```tsx
  export const BrandMark: React.FC<{ size?: number; className?: string }> = ({ size = 28, className }) => (
    <span className={['brand-mark', className].filter(Boolean).join(' ')} aria-hidden="true">
      <img className="brand-mark-light" src="/brand/logo.svg" width={size} height={size} alt="" />
      <img className="brand-mark-dark" src="/brand/logo-white.svg" width={size} height={size} alt="" />
    </span>
  );
  ```
  (S)
- [ ] **W5 Kit CSS** (in `docs/design/web/css/kit.css`, then `npm run design:sync`). Show the white emblem on dark contexts **and** in dark theme (the navy house has no contrast there). Mirror how `.wordmark` is scoped (`.sidebar`, `.hero`, `.on-dark`; see `web/src/theme/components.css`, generated):
  ```css
  .brand-mark { display: inline-flex; flex: none; }
  .brand-mark-dark { display: none; }
  .on-dark .brand-mark-light, .sidebar .brand-mark-light, .hero .brand-mark-light,
  :root[data-theme="dark"] .brand-mark-light { display: none; }
  .on-dark .brand-mark-dark, .sidebar .brand-mark-dark, .hero .brand-mark-dark,
  :root[data-theme="dark"] .brand-mark-dark { display: inline; }
  ```
  (M)
- [ ] **W6 Place the lockup.** `BrandMark` before `BrandWordmark` in `SidebarNav.tsx`, `MobileDrawer.tsx`, `AdminLogin.tsx` (hero and card) and `TopBar.tsx` (phone only, size 24). `BrandWordmark` text stays (it follows the white-label `appName`). In the collapsed rail, show `BrandMark` alone. White-label caveat: the emblem is fixed TradieHunter art; if `brand.appName` is ever overridden to another product, hide the mark (`appName !== 'TradieHunter'`). (M)
- [ ] **W7 Docs.** `docs/design/web/COMPONENTS.md`: add `BrandMark`. (S)

## Phase M: Mobile (`mobile/`, Flutter)

### M1 In-app emblem

- [ ] **M1.1** Copy `svg/logo.svg` and `svg/logo-white.svg` to `mobile/assets/brand/logo/` and add `- assets/brand/logo/` to `pubspec.yaml` (`assets:` is not recursive). (S)
- [ ] **M1.2** Add `ThBrandMark({double? size, bool onDark = false})` to `th_widgets.dart` using `SvgPicture.asset` (already a dependency). Use `logo-white.svg` when `onDark` is true **or** the theme is dark, else `logo.svg`. Default size from a new `Sizes.brandMark` token; `excludeFromSemantics: true`. (M)
- [ ] **M1.3** Place it: `splash_screen.dart` (`ThBrandMark(onDark: true)` centred above the large wordmark; the existing pulsing rings stay), `sign_in_screen.dart` / `sign_up_screen.dart` (small mark left of `THWordmark()`). No copy or order changes. Update the matching mockup frames (`splash`, `sign_in`, `sign_up`) under `docs/design/mobile/` and rebuild PNGs so `scripts/check-mockup-pngs.py` stays green. (M)

### M2 Native app icons

- [ ] **M2.0 Recon.** View current `mipmap-xxxhdpi/ic_launcher.png`, `Icon-App-1024x1024@1x.png`, `LaunchImage*.png` and `launch_background.xml` and note whether they carry the old pin art. (S)
- [ ] **M2.1 iOS.** Replace the whole `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/` with the pack's `ios/AppIcon.appiconset/` (PNGs **and** its `Contents.json`; delete the old `Icon-App-*` files, F11). Gate: `identify -format '%[channels]' icon-marketing-1024.png` prints `srgb` (no alpha) or App Store Connect rejects it. Open in Xcode: no "unassigned child" warnings. (S)
- [ ] **M2.2 Android.** Merge the pack's `android/res/` into `mobile/android/app/src/main/res/`:
  - `mipmap-{mdpi..xxxhdpi}/`: `ic_launcher.png`, `ic_launcher_round.png`, `ic_launcher_foreground.png`, `ic_launcher_monochrome.png` (replaces the old `ic_launcher.png`).
  - `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml` (adaptive; background `@color/ic_launcher_background`, foreground and monochrome from `@mipmap/...`).
  - `values/ic_launcher_background.xml` (`#FFFFFF`; does not clash with `styles.xml`).
  - `drawable-{mdpi..xxxhdpi}/ic_stat_notification.png`.
  In `AndroidManifest.xml` add `android:roundIcon="@mipmap/ic_launcher_round"` on `<application>` and, inside it, next to the Flutter meta-data:
  ```xml
  <meta-data android:name="com.google.firebase.messaging.default_notification_icon"
             android:resource="@drawable/ic_stat_notification" />
  <meta-data android:name="com.google.firebase.messaging.default_notification_color"
             android:resource="@color/th_brand" />
  ```
  and add `<color name="th_brand">#1E3A8A</color>` to a new `values/colors.xml` (same value as the brand token; native resource, so it cannot read Dart tokens). (M)
- [ ] **M2.3 Launch screen.** Only if M2.0 shows old pin art in `launch_background.xml` / `drawable-v21` / `LaunchImage*.png`: keep the existing background colour (no flash into the Flutter splash) and centre the white emblem on navy to match the Flutter splash. Otherwise leave alone. (S)

### M3 Lottie tradie lookup (replaces the magnifying glass)

- [ ] **M3.1 Asset + dependency.** Copy `animated/tradiehunter_loader.json` to `mobile/assets/lottie/tradiehunter_loader.json`. `pubspec.yaml`: add `lottie: ^3.1.0` under `dependencies:` and `- assets/lottie/` under `flutter: assets:`. Run `flutter pub get`. (S)
- [ ] **M3.2 Tokens** in `th_tokens.dart`:
  - `THDurations.lookupLoop = Duration(milliseconds: 5200)` (the composition length: 312 frames at 60 fps).
  - `Sizes.lookupLottie` (start at `Sizes.radarDiameter`, 240; raise to about 280 if the house reads small, since the largest ring is about 81% of the canvas).
  - A file-level const in `ho_radar_screen.dart`: `_kLookupRestProgress = 0.78` (assembled logo, per the pack README: 0.71-0.85) with a "position in the composition, not a design token" comment.
  Keep `Sizes.radarCore`/`radarCoreIcon`: `_StatusPanel` (~line 370 of `ho_radar_screen.dart`) still uses them. Retire `THDurations.radarCycle` (unused) or repoint its doc to `lookupLoop`. (S)
- [ ] **M3.3 Drive it at the right speed.** In `ho_matching_screen.dart`, `_ctrl` is `Duration(seconds: 2)`. Played through Lottie that would run the 5.2 s animation 2.6x too fast. Change it to `THDurations.lookupLoop`. Nothing else uses `_ctrl` besides the `radar:` argument (verify with grep); `didChangeDependencies` already does `_ctrl.repeat()` / `stop()` from `MediaQuery.disableAnimationsOf`. (S)
- [ ] **M3.4 Replace `_Radar`.** In `ho_radar_screen.dart` delete `_kRadarRings`, `_kRingStartScale`, `_kRingPeakAlpha`, `_kRingStroke`, `_Radar._ring` and the `Icons.search` core. `_Searching` renders a new `_LookupAnimation(animation: radar)`:
  ```dart
  class _LookupAnimation extends StatelessWidget {
    const _LookupAnimation({required this.animation});

    /// Null means reduced motion: show the assembled logo, no movement.
    final Animation<double>? animation;

    @override
    Widget build(BuildContext context) {
      final anim = animation;
      return RepaintBoundary(
        child: SizedBox.square(
          dimension: Sizes.lookupLottie,
          child: Lottie.asset(
            'assets/lottie/tradiehunter_loader.json',
            key: anim == null ? null : const ValueKey('matching-radar'),
            controller: anim ?? const AlwaysStoppedAnimation(_kLookupRestProgress),
            fit: BoxFit.contain,
            // A bad or missing asset must never break the matching screen.
            errorBuilder: (_, __, ___) => const ThBrandMark(),
          ),
        ),
      );
    }
  }
  ```
  Keep the `Semantics`/headline text beneath as is. The animation is decorative: wrap it in `ExcludeSemantics`. Lottie's `controller` takes an `Animation<double>`, so the existing `radar` parameter works unchanged; confirm against the version `pub get` resolves, and if it is typed `AnimationController`, pass `_ctrl` down as that type instead of `Animation<double>`. (M)
- [ ] **M3.5 Dark theme (D2).** On a dark theme, wrap the Lottie in a circle filled with a light surface token (`c.onBrand` or the closest existing light token; no raw colour) sized `Sizes.lookupLottie`, so the navy house stays readable. Skip if the on-device check (V3) shows it already reads well. (S)
- [ ] **M3.6 Other searching visuals (D2 scope).** Run `grep -n "CircularProgressIndicator\|THSpinner" mobile/lib/ui/homeowner/ho_browse_tradies_screen.dart mobile/lib/ui/homeowner/ho_choose_tradie_screen.dart`. Use the Lottie only where a full-area "finding tradies" loader is at least 120 px square; leave inline button spinners and text-field `Icons.search` (`ho_home_screen.dart:217`, `ho_categories_screen.dart:115`) untouched, since a ripple in an input would read as loading. (S)
- [ ] **M3.7 Mockup.** Update the `ho_radar` frame (still `needs-design`) so design and code match. (S)

### M4 Tests

- [ ] **M4.1** `mobile/test/ui/phase4_ho_radar_test.dart`:
  - "animated radar": still finds `ValueKey('matching-radar')`; add `expect(find.byType(Lottie), findsOneWidget)` and `expect(find.byIcon(Icons.search), findsNothing)`. Use `await tester.pump()` (not `pumpAndSettle`) so the repeating animation does not hang; the file already feeds `AlwaysStoppedAnimation(0.3)`.
  - "reduced motion" (currently expects the static core and `Icons.search`, line 87): change to `findsNothing` for `matching-radar`, `findsNothing` for `Icons.search`, and `findsOneWidget` for `Lottie` (static frame).
  - Add one test that a failing asset falls back to `ThBrandMark` without throwing (override the bundle or use a wrong path via a test seam; keep it small).
  Also check `mobile/test/matching_flow_test.dart` (lines 418, 430) still passes. (M)
- [ ] **M4.2** Grep `integration_test`, `patrol_test`, `.maestro` for `matching-radar` or `Icons.search` in the matching flow and update. (S)

### M5 Flutter web shell

- [ ] **M5.1** Replace `mobile/web/icons/Icon-192.png` (`android-chrome-192x192.png`), `Icon-512.png` (`android-chrome-512x512.png`), `Icon-maskable-192.png` (`maskable-icon-192x192.png`), `Icon-maskable-512.png` (`maskable-icon-512x512.png`) and `mobile/web/favicon.png` (`favicon-48x48.png`). Rewrite `mobile/web/manifest.json` colours to `#1E3A8A` / `#FFFFFF` and replace the `"A new Flutter project."` description. (S)

### M6 Cleanup

- [ ] **M6.1** After M1-M5, delete unreferenced old pin assets in `mobile/assets/brand/` (F12) only where `grep -rn "<filename>" mobile .maestro docs` shows no use; drop the `assets/brand/png/` pubspec line if the folder empties. Keep `google-g.svg` and `map-pin-*.svg`. (S)

## Phase B: Backend email templates (image only)

SVG and Lottie cannot be used in Gmail/Outlook, so the email logo is a **PNG**. The pack has no PNG of the white emblem on a transparent background, so render one.

- [ ] **B1 Render the PNG.** From `svg/logo-white.svg` produce `backend/Email/Assets/th-mark.png`, **96x96** (displayed at 40x40, 2x for retina), transparent background. Verified: renders to about 2.6 KB and reads clearly on the `#1E3A8A` header. Command (needs librsvg; the container's ImageMagick has no SVG delegate):
  ```bash
  rsvg-convert -w 96 -h 96 svg/logo-white.svg -o backend/Email/Assets/th-mark.png
  # or: python3 -c "import cairosvg;cairosvg.svg2png(url='svg/logo-white.svg',write_to='backend/Email/Assets/th-mark.png',output_width=96,output_height=96)"
  ```
  Keep it under 8 KB. Do not commit a 4x version; there is only one email size. (S)
- [ ] **B2 Embed it.** `FixoApi.csproj`, next to `<EmbeddedResource Include="Email\**\*.cshtml" />`, add `<EmbeddedResource Include="Email\Assets\*.png" />`. Add `Email/EmailAssets.cs` exposing `static byte[] Mark`, read once from the assembly manifest. (S)
- [ ] **B3 Layout.** In `_EmailLayout.cshtml`, replace the lone wordmark `<span>` inside the existing `th-header` `<td>` (keep `bgcolor`, gradient, padding and radius) with an Outlook-safe two-cell lockup:
  ```html
  <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
    <td style="padding-right:12px;" valign="middle">
      <img src="@Model.MarkSrc" width="40" height="40" alt="" style="display:block; border:0; outline:none; text-decoration:none; width:40px; height:40px;" />
    </td>
    <td valign="middle">@* existing wordmark <span>, unchanged *@</td>
  </tr></table>
  ```
  `alt=""` because the adjacent text carries the name; with images blocked the header still reads "TradieHunter" (D3). Add `MarkSrc` (`string`) to `EmailLayoutModel` in `EmailModels.cs`. The header stays navy in light and dark clients, so one white PNG serves both. (M)
- [ ] **B4 Resolve `MarkSrc`.** In `EmailTemplateRenderer`: if `Brand:EmailLogoUrl` is set use it (revive the option and fix its XML doc in `BrandOptions.cs`; it must be an HTTPS **PNG**), else `cid:th-mark`. Add a render option for previews that substitutes a `data:image/png;base64,...` URI, since browsers cannot resolve `cid:`; `EmailPreviewController` passes it. (M)
- [ ] **B5 Attach the CID.** In `SmtpEmailSender` at the `BodyBuilder` (line ~415): when `rendered.Html` contains `cid:th-mark`, add
  ```csharp
  var img = body.LinkedResources.Add("th-mark.png", EmailAssets.Mark);
  img.ContentId = "th-mark";
  ```
  so MailKit emits `multipart/related`. The text part stays first inside `multipart/alternative`. The legacy plain-text branch (`string.IsNullOrWhiteSpace(rendered.Html)`) is unchanged. (S)
- [ ] **B6 Tests.** In the renderer/copy tests: header contains `<img ... width="40" height="40" alt="">` and the wordmark text; `MarkSrc` is `cid:th-mark` by default and the override URL when configured. A `SmtpEmailSender` message-build test asserts exactly one linked resource with `ContentId == "th-mark"` and `image/png`. Regenerate the 10 goldens with `UPDATE_EMAIL_GOLDENS=1` (see `EmailGoldenSnapshotTests.cs`), confirm the diff is **header only**, commit. Run inside the container: `docker compose run --rm --entrypoint /bin/bash api -c "dotnet test backend/FixoApi.Tests"`. (M)
- [ ] **B7 Docs and manual check.** `docs/OPERATIONS.md` section 1: header is now emblem PNG (CID) + text wordmark; `Brand:EmailLogoUrl` is an optional override again; add `th-mark` to the client matrix (Gmail web/iOS/Android, Outlook 2016 + web, Apple Mail light/dark, Yahoo). Open `GET /api/admin/email-preview/Otp` and send one real mail through MailHog to confirm the inline image shows. (S)

## Phase V: Verification (before merging each phase)

- [ ] **V1 Web:** `npm run design:check`, `npm run design:legacy`, `npm run build` in `web/`; `scripts/web/render-probe.py` finds `img.brand-mark-light`/`-dark` in the shell and login; screenshot sidebar in light, dark, rail and phone widths; Playwright specs in `web/e2e` pass (wordmark text unchanged). Check the tab icon and `/site.webmanifest` load (no 404s).
- [ ] **V2 Mobile build:** `flutter pub get`, `flutter analyze`, `flutter test` in `mobile/`. Android 13+ emulator: adaptive and themed (monochrome) icon, round icon, notification icon via an FCM test message. iOS simulator: icon renders; no-alpha gate from M2.1.
- [ ] **V3 Lookup on device:** open the matching radar in light, dark and with OS reduce-motion on. Confirm: no magnifier anywhere; house assembles and rings ripple at about 5 s per loop with no jump at the loop point; the Lottie never draws outside its box; dark theme shows the navy house clearly (else M3.5); reduce-motion shows the still assembled logo; no jank (profile mode, `RepaintBoundary` kept). If the first 0.9 s (building, no ripples) feels slow for a waiting screen, note it for the owner (see section 9, loop option).
- [ ] **V4 Email:** B6 tests green; manual client matrix (B7).
- [ ] **V5 Size budget:** `web/dist` grows by under 150 KB (icons + mark SVGs); Flutter assets grow by about 220 KB (Lottie 212 KB + two SVGs); email HTML grows by under 1 KB (the PNG is a separate MIME part).

## 8. Lottie facts the implementer needs

| Property | Value |
|---|---|
| File | `tradiehunter_loader.json`, 212,095 bytes, Lottie 5.7.0, 720x720, 60 fps, frames 0-312 (5.2 s) |
| Layers | `fx` (rings, flash, sparks), `hammer`, `piece0`-`piece4` (house). No images or fonts |
| Ripples | Rings per strike (light blue, orange, gold) at about 0.9 s, 1.4 s, 1.9 s, 2.4 s, 2.9 s and 3.4 s; the last strike adds a wide ring that finishes at about 4.35 s |
| Rest frame | Assembled logo at progress 0.71-0.85; use 0.78 for the static state |
| Controller | Duration must equal `THDurations.lookupLoop` (5200 ms) or the speed is wrong (M3.3) |
| Loop | `_ctrl.repeat()` restarts at frame 0 (house scattered). If a hard cut at the loop point shows in V3, ask for a second export that loops seamlessly; the pack README offers this |
| Colours | Own artwork (`#8FA8F2`, `#B45309`, `#1E3A8A`, plus gold and bright-orange flash/spark tones); do not recolour with `ValueDelegate` (generic `Fill`/`Stroke` names would recolour everything) |

## 9. Decisions and parked items

| Item | Outcome |
|---|---|
| D1 `lottie` dependency | _pending_ (default: approved by the request) |
| D2 dark-theme lookup chip | _pending_ (default: decide after V3) |
| D3 email: emblem PNG + live-text wordmark | _pending_ (default: yes) |
| D4 web Lottie | _pending_ (default: none; admin has no lookup screen) |
| Ripple-only Lottie (no house/hammer) | _not requested_; ask the designer if V3 finds the 0.9 s build too busy for a waiting screen |
| `web/og-image.png`, `expo/*`, play-store icon | not wired (admin private; Flutter app; upload to Play Console by hand) |
