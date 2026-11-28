# Brand pack v2: logos, app icons, email logo and the Lottie tradie lookup

> **Repo / branch:** `johnverz22/tradiehunter` @ `main`
> **Purpose:** Wire `tradiehunter-assets.zip` (house + hammer emblem, platform icon sets) and the **revised Lottie loader** (`tradiehunter_loader.json`, `tradiehunter_loader_dark.json`, usage guide) into `mobile/`, the logos/icons into `web/`, and the logo as a PNG into the backend email templates (image only). The magnifying glass in the tradie lookup (matching radar) is replaced by the Lottie.
> **Status:** Ready to implement. All decisions approved by the owner (section 3). **Prepared:** 2026-11-28 (revised for the updated Lottie loader and its usage guide)
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
| `animated/tradiehunter_loader.json`, `animated/tradiehunter_loader_dark.json`, `animated/README.md` (**revised files; they supersede the older loader inside the first zip**) | **Lottie for the tradie lookup**: light file, pre-coloured dark file, usage guide | no (admin only, no Lottie) | yes | no |
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
| F8 | **What the Lottie is** (per the revised usage guide): a looping 5.2 s build animation, 720x720 canvas with empty margin, 60 fps, 312 frames, about 212 KB, shape layers only. A hammer strikes six times (0.9, 1.4, 1.9, 2.4, 2.9, 3.4 s); each strike snaps a floating piece of the house logo into place; the finished logo holds from about 3.7 to 4.4 s (0.72 to 0.84 of the timeline), then the pieces drift apart and it loops. It replaces the whole `_Radar` (core + rings), not just the glyph. My earlier read of the first-zip file also found expanding ripple rings on each strike; the revised guide does not mention them, so confirm on device (V3). | usage guide; first-zip JSON |
| F9 | **Theming is built in.** The house outline is navy `#1E3A8A` and vanishes on dark surfaces; the guide supplies `tradiehunter_loader_dark.json` (white house, same timing). Mobile tokens in dark theme are `brand #8FA8F2` / `onBrand #0A101E` (`th_tokens.dart`), so no token is white and the same colour as the hammer would clash; **choose the file per theme and do not recolour at runtime**. (The guide's `HouseFill` colour delegate is untested on the Flutter `lottie` package, and it would need raw colours in widget code.) | `th_tokens.dart` 302-333; guide |
| F10 | `lottie` is **not** in `pubspec.yaml` (only `flutter_svg ^2.0.17`). Adding it needs sign-off per AGENTS.md; approved in D1. | `pubspec.yaml` |
| F11 | The iOS pack's `Contents.json` has 18 entries; the project's has 19 (extra `iphone 29x29 @1x`, an iOS 6 size). Pack filenames (`icon-iphone-60@3x.png`) differ from the project's (`Icon-App-60x60@3x.png`), so the folder is replaced as a whole, not file by file. | both `Contents.json` |
| F12 | Existing pin-brand files in `mobile/assets/brand/` (`wordmark-*`, `splash-logo*`, `app-icon-*`, `notification-icon-24*`) are unreferenced by Dart. Only `google-g.svg` is used (`auth_common.dart:90`). | `grep -rn "assets/brand" mobile/lib` |

## 3. Decisions (all approved by the owner)

1. **D1: dependency.** Add `lottie: ^3.1.0` to `mobile/pubspec.yaml`. Approved. No other new dependencies.
2. **D2: dark theme.** Use `tradiehunter_loader_dark.json` on the dark theme and `tradiehunter_loader.json` on the light theme. Approved; no light chip behind the animation and no runtime recolour.
3. **D3: email.** The logo is a PNG image, plus the existing live-text wordmark beside it so image blocking and plain-text twins keep working. Approved.
4. **D4: web.** No Lottie on web (admin only, no lookup screen). Approved.

Outcomes are recorded in section 9.

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

- [ ] **A1** Add `docs/design/brand/` with: `svg/logo.svg`, `svg/logo-white.svg`, `svg/logo-monochrome.svg`, `svg/logo-on-white.svg`, `animated/tradiehunter_loader.json`, `animated/tradiehunter_loader_dark.json`, `animated/README.md` (the revised usage guide), and a short `README.md` (the inventory in section 1 plus the colour rules). This is the re-export source when the art changes. Do not copy the platform folders here; they live in their targets. (S)

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

Source: the revised `animated/` files. Behaviour follows the usage guide's `TradieLoader` (loop while loading, then settle on the finished logo, never seeking backwards), adapted to repo rules.

- [ ] **M3.1 Assets + dependency.** Copy `tradiehunter_loader.json` and `tradiehunter_loader_dark.json` to `mobile/assets/lottie/`. `pubspec.yaml`: add `lottie: ^3.1.0` under `dependencies:` and `- assets/lottie/` under `flutter: assets:`. Run `flutter pub get`. (S)
- [ ] **M3.2 Tokens** in `th_tokens.dart`: `Sizes.tradieLoader` (start at 240, the same as `Sizes.radarDiameter`; the guide recommends 200 to 260 because the canvas has margin). Keep `Sizes.radarCore`/`radarCoreIcon` (still used by `_StatusPanel`, ~line 370 of `ho_radar_screen.dart`). The hold window (`0.72`, `0.84`) is a position in the composition, so it is a file-level const with a "timeline fraction, not a design token" comment, as `ho_radar_screen.dart` already does for ring counts. (S)
- [ ] **M3.3 Shared widget `ThTradieLoader`** in new `mobile/lib/ui/design/th_tradie_loader.dart`, exported like the other `th_*` files. Port the guide's `TradieLoader` with these changes:
  - **No colours in Dart.** Pick the asset by theme: `Theme.of(context).brightness == Brightness.dark` selects the `_dark.json` file (F9). Drop the guide's `LottieDelegates` / `ValueDelegate.color` block and its `Colors.white` / `Color(0xFF1E3A8A)`.
  - Size defaults to `Sizes.tradieLoader`; the hold fractions come from the file-level consts.
  - Keep `isLoading`, `onSettled`, the `AnimationController` driven by `composition.duration`, the "stop only inside the hold window and only when `!isLoading`" logic, and "resume looping when a new search starts".
  - **Reduced motion:** the guide checks `MediaQuery.of(context).disableAnimations` once in `onLoaded`. Use `MediaQuery.disableAnimationsOf(context)` and also react in `didChangeDependencies` (stop the controller and show the mid-hold frame when it turns on, resume when off), because `ho_matching_screen.dart` does this today.
  - If `isLoading` is already false when the composition loads, show the mid-hold frame instead of looping.
  - `errorBuilder` returns `ThBrandMark()` so a bad asset never breaks the screen.
  - Wrap in `RepaintBoundary` and `ExcludeSemantics` (decorative; the headline text beneath keeps the accessible name).
  - Fixed key `ValueKey('matching-radar')` on the loader at the radar call site.
  (M)
- [ ] **M3.4 Replace the radar.** In `ho_radar_screen.dart`: delete `_Radar`, `_ring`, `_kRadarRings`, `_kRingStartScale`, `_kRingPeakAlpha`, `_kRingStroke` and the `Icons.search` core; `_Searching` renders `ThTradieLoader(isLoading: true, key: const ValueKey('matching-radar'))`. The loader owns its animation and reduced-motion handling, so **remove the `radar` (`Animation<double>?`) parameter** from `ThRadarScreen` and `_Searching` (and fix its doc comment that mentions `THDurations.radarCycle`). `_Searching` is only mounted while searching, and the matched / no-tradie / failed states swap to `_StatusPanel`, so `onSettled` is not needed on this screen. (M)
- [ ] **M3.5 Clean up `ho_matching_screen.dart`.** The 2 s `_ctrl` existed only to feed `radar:`. Remove `_ctrl` (declaration line ~67, `initState` creation ~96, `didChangeDependencies` use ~107-110, `_ctrl.stop()` ~146, `dispose` ~393), `_animationsEnabled` (~77) and the `radar:` argument (~419), and drop `SingleTickerProviderStateMixin` if nothing else needs a ticker (verify with `grep -n "_ctrl\|_animationsEnabled\|vsync" mobile/lib/ui/homeowner/ho_matching_screen.dart`). Delete `THDurations.radarCycle` if it is then unused repo-wide. (S)
- [ ] **M3.6 Other searching visuals.** Run `grep -n "CircularProgressIndicator\|THSpinner" mobile/lib/ui/homeowner/ho_browse_tradies_screen.dart mobile/lib/ui/homeowner/ho_choose_tradie_screen.dart`. Where a full-area "finding tradies" loader is at least 120 px square, use `ThTradieLoader(isLoading: ..., onSettled: ...)` and use `onSettled` to fade the results in (the guide's intended use). Leave inline button spinners and text-field `Icons.search` (`ho_home_screen.dart:217`, `ho_categories_screen.dart:115`) untouched; a ripple/animation in an input reads as loading. Keep one `ThTradieLoader` instance in the tree per search (a new key restarts the controller). (S)
- [ ] **M3.7 Mockup.** Update the `ho_radar` frame (still `needs-design`) so design and code match. (S)

### M4 Tests

- [ ] **M4.1** `mobile/test/ui/phase4_ho_radar_test.dart`: remove the `radar:` argument (and the `_frame` const) from the `_pump` helper and the `ThRadarScreen` call.
  - "animated radar": finds `ValueKey('matching-radar')`, `find.byType(Lottie)` once, and `find.byIcon(Icons.search)` finds nothing. Use `await tester.pump()` (not `pumpAndSettle`; the loop never settles).
  - "reduced motion" (currently expects the static core and `Icons.search`, ~line 87): pump inside `MediaQuery(data: MediaQueryData(disableAnimations: true))`; expect `Lottie` present, no `Icons.search`, and that `await tester.pumpAndSettle()` completes (proves nothing is repeating).
  - Add a small test for `ThTradieLoader` itself: `isLoading` true then false calls `onSettled` once after the controller reaches the hold window (drive time with `tester.pump(Duration(...))`), and a bad asset path renders `ThBrandMark` without throwing.
  - Check `mobile/test/matching_flow_test.dart` (lines ~418, ~430) still passes.
  (M)
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
- [ ] **V3 Lookup on device** (the guide says the animation was checked in lottie-web only, not yet in the Flutter `lottie` package, so this check is required): open the matching radar in light, dark and with OS reduce-motion on. Confirm: no magnifier anywhere; the light theme uses the navy-house file and the dark theme the white-house file, both clearly visible; pieces snap in on each hammer strike and the loop restarts without a visible jump; with reduce-motion the finished logo is shown still; `ThTradieLoader` in a list screen stops on the finished logo (not mid-scatter) when `isLoading` flips to false and fires `onSettled`; no jank in profile mode. Note whether ripple rings are visible (F8) and tell the owner if they are not.
- [ ] **V4 Email:** B6 tests green; manual client matrix (B7).
- [ ] **V5 Size budget:** `web/dist` grows by under 150 KB (icons + mark SVGs); Flutter assets grow by about 430 KB (two Lottie files of about 212 KB each + two SVGs); email HTML grows by under 1 KB (the PNG is a separate MIME part).

## 8. Lottie facts the implementer needs (from the revised usage guide)

| Property | Value |
|---|---|
| Files | `tradiehunter_loader.json` (navy house), `tradiehunter_loader_dark.json` (white house, same timing and shapes) |
| Format | 720x720 transparent canvas with margin, 60 fps, 312 frames (5.2 s), about 212 KB each; shape layers and keyframes only |
| Timeline | 0-0.9 s pieces fade in; strikes at 0.9, 1.4, 1.9, 2.4, 2.9, 3.4 s; finished logo holds 3.7-4.4 s (0.72-0.84); 4.4-5.2 s pieces drift apart, loop restarts |
| Colours | House `#1E3A8A` (white in the dark file), hammer `#8FA8F2`, accent `#B45309`. Do not recolour at runtime (F9) |
| Controller | Duration comes from `composition.duration` in `onLoaded`; do not hard-code 5.2 s |
| Settle | Stop only while inside 0.72-0.84 and `isLoading` is false; never seek backwards (no flicker); fire `onSettled` once |
| Reduced motion | Show the mid-hold frame (0.78), no looping |
| Size | 200 to 260 logical px; the canvas margin leaves room for floating pieces |
| Pitfalls | Keep one widget instance per search (a new key restarts the controller); logo invisible on dark = wrong file for the theme |

## 9. Decisions and parked items

| Item | Outcome |
|---|---|
| D1 `lottie` dependency | **Approved** |
| D2 dark theme: separate dark file, no runtime recolour | **Approved** |
| D3 email: emblem PNG + live-text wordmark | **Approved** |
| D4 web Lottie | **Approved: none** (admin only) |
| `web/og-image.png`, `expo/*`, Play Store icon | not wired (admin private; Flutter app; upload the Play icon to Play Console by hand) |
