# Brand assets integration: logos, app icons and the rippling-circles tradie lookup

> **Repo / branch:** `johnverz22/tradiehunter` @ `main`
> **Purpose:** Wire the new TradieHunter brand pack (`tradiehunter-assets.zip`, house + hammer emblem) into `web/`, `mobile/` and the backend email templates, and replace the magnifying glass in the tradie lookup (matching radar) with rippling circles taken from `tradiehunter-animated.svg`.
> **Status:** Not started. Decisions D1-D4 need owner answers before Phase M and Phase B. **Prepared:** 2026-11-28
> **Naming rule:** code identifiers stay `Fixo` (Dart package imports are `package:fixo/...`, backend namespace `FixoApi`); user-facing text is TradieHunter. Do not rename.
> **Convention:** `[ ]` todo, `[x]` done, `[~]` parked (add why). Size: S <= 1h, M <= half a day, L >= 1 day.
> **Relationship to other plans:** independent of `01`-`10`. Touches the same design-system surfaces as `06.1_web_design_system_migration_plan.md` (web kit sync) and `09_notification_coverage_plan.md` (email templates and goldens), so rebase on whichever lands first.
> **Note on the asset pack:** the implementer has `tradiehunter-assets.zip`. File names below are the names inside that zip. `mobi` in the request means the `mobile/` folder.

---

## 0. Read first

`AGENTS.md` (tokens only in mobile UI, web theme files are synced copies, ask before adding dependencies), `docs/DESIGN.md`, `docs/design/web/DESIGN_GUIDE.md`, `docs/OPERATIONS.md` section 1 (Email), `docs/TESTING.md`.

Code touched: `web/index.html`, `web/public/`, `web/src/features/branding/`, `web/src/layout/{SidebarNav,TopBar,MobileDrawer}.tsx`, `web/src/features/auth/AdminLogin.tsx`, `docs/design/web/css/kit.css`; `mobile/pubspec.yaml`, `mobile/assets/brand/`, `mobile/lib/ui/design/{th_widgets,th_tokens}.dart`, `mobile/lib/ui/homeowner/ho_radar_screen.dart`, `mobile/lib/ui/auth/{splash,sign_in,sign_up}_screen.dart`, `mobile/android/app/src/main/`, `mobile/ios/Runner/Assets.xcassets/`, `mobile/web/`; `backend/Email/Layouts/_EmailLayout.cshtml`, `backend/Services/SmtpEmailSender.cs`, `backend/Email/EmailTemplateRenderer.cs`, `backend/Controllers/EmailPreviewController.cs`, `backend/FixoApi.csproj`, `backend/FixoApi.Tests/Goldens/email/`.

## 1. Asset inventory: what goes where

| Asset (in zip) | Use | web | mobile | email |
|---|---|---|---|---|
| `mark.svg` | Emblem on light surfaces (navy ring, light-blue house, orange handle) | yes | yes | no |
| `logo-reversed.svg` | All-white emblem for navy / dark surfaces and dark theme | yes | yes | **yes** (rendered to PNG, B1) |
| `logo-mono.svg` | `currentColor` emblem; source for the Android notification icon | no | yes | no |
| `favicon.svg`, `favicon-16/32/64.png` | Browser tabs | yes (`favicon.svg`, `-32`) | `mobile/web` (`-64`) | no |
| `apple-touch-icon-180.png` | iOS home-screen bookmark | yes | `mobile/web` | no |
| `android-chrome-192/512.png`, `maskable-192.png`, `app-icon-maskable-512.png` | PWA / Flutter web icons | no (admin, not a PWA) | `mobile/web/icons` | no |
| `app-icon-maskable-1024.png` | **iOS App Store icon source** (verified fully opaque) | no | yes | no |
| `app-icon-1024.png` | Legacy Android launcher icons only (it has transparent rounded corners, so it is **not** valid for iOS) | no | yes | no |
| `mark.svg` (padded) | Android adaptive foreground | no | yes | no |
| `tradiehunter-animated.svg` | Source of the ripple motion; optional hero on web | optional | reference only | no |
| `manifest.webmanifest` | Template for `mobile/web/manifest.json` | no | yes | no |
| `logo-horizontal*`, `logo-stacked*`, `social-cover*`, `build-poster-1024.png`, `logo-512/1024.png`, `mark-512.png` | Marketing / docs. Not wired in this plan (the horizontal and stacked SVGs use `<text>` in Arial, so rendering depends on the viewer's fonts) | no | no | no |
| `tradiehunter-original.svg` (1.17 MB), `.DS_Store`, `__MACOSX/` | **Never commit** | | | |

## 2. Findings (what is true today)

| # | Finding | Evidence |
|---|---|---|
| F1 | `web/public/favicon.svg` is the Vite starter bolt (purple `#863bff`), not a TradieHunter icon. No PNG favicon, no apple-touch icon. | `web/public/favicon.svg`, `web/index.html` |
| F2 | The emblem appears nowhere in UI. Web, mobile and email all render a **text** wordmark ("Tradie" + gold "Hunter"). The old pin-style files in `mobile/assets/brand/` (`wordmark-*`, `splash-logo`, `app-icon-android-*`) are not referenced by any Dart code except `google-g.svg`. | `BrandWordmark.tsx`, `THWordmark` (`th_widgets.dart:2025`), `_EmailLayout.cshtml` header |
| F3 | **Palette mismatch.** Logo art uses navy `#0B2E86`, light blue `#7D9CEE`, orange `#D45D00`. The design system uses brand `#1E3A8A`, accent `#B45309`, hero gold `#FFD495` (`web/src/theme/tokens.css`, `th_tokens.dart`, email layout). | see D1 |
| F4 | Mobile: Android has only legacy `mipmap-*/ic_launcher.png` (no `mipmap-anydpi-v26` adaptive icon, no monochrome layer) and **no notification small icon** is wired (no `default_notification_icon` meta-data). iOS `AppIcon.appiconset` has the full size set. Existing launcher art predates this pack (confirm visually in M0). | `android/app/src/main/res`, `AndroidManifest.xml` |
| F5 | `mobile/web/manifest.json` is still the Flutter default (`"A new Flutter project"`, `#0175C2`); `mobile/web/index.html` points at old icons. | `mobile/web/` |
| F6 | **Email:** header is a text wordmark; `Brand:EmailLogoUrl` is deprecated and no CDN exists (OPERATIONS 1, item 3 struck through). Gmail and Outlook do not render SVG, so email needs a PNG. `SmtpEmailSender` builds a `BodyBuilder` with `TextBody`/`HtmlBody` only (no `LinkedResources`). 10 golden snapshots will change. | `SmtpEmailSender.cs:415`, `Goldens/email/` |
| F7 | **Lookup today:** `_Radar` in `ho_radar_screen.dart` draws 3 expanding rings (`c.brand`, one colour) around a filled core holding `Icons.search` (line 264). `splash_screen.dart` already has `_ThPulsingRings`. Other `search` icons are text-field affordances (`ho_home_screen.dart:217`, `ho_categories_screen.dart:115`) or empty states. | files cited |
| F8 | **Animation runtime support differs.** The SVG animates with SMIL `<animate>`; browsers play it (also inside `<img>`), **`flutter_svg` does not**, email cannot. So mobile needs a native port; web can use the SVG motion or an equivalent CSS version. | `pubspec.yaml` has `flutter_svg ^2.0.17` only |
| F9 | Pack hygiene: `tradiehunter-animated.svg` is 84,255 bytes of which ~7.7 KB is a `<metadata><c2pa:manifest>` block (76,519 bytes without it). The pack's `index.html` references `tradiehunter-build-animation.svg` / `-build-poster.svg`, which do not exist (real names: `tradiehunter-animated.svg`, `build-poster-1024.png`). | zip contents |
| F10 | AGENTS.md names the mobile token file `lib/theme/design_tokens.dart` and lists `FW`, `Alpha`, `Tracking`; the real file is `mobile/lib/ui/design/th_tokens.dart` and has `Space`, `Radii`, `Sizes`, `THDurations`, `THMotion`, `THColors` (no `Alpha` class). | repo |

### What the ripples are (from `tradiehunter-animated.svg`)

The SVG's rings are emitted at each hammer strike. Per strike: a **light-blue** ring (`#7D9CEE`, r 14 to 160, stroke 8 to 0, opacity 0.9 to 0) and a smaller **orange** ring (`#D45D00`, r 8 to 105, stroke 4 to 0, opacity 0.9 to 0) starting ~0.1 s later, plus a brief cream flash disc. The orange ring's reach is ~0.66 of the blue ring's. The lookup ripple reproduces that two-ring pattern, nothing else from the animation (no hammer, no house build).

## 3. Decisions to confirm first (defaults are recommendations)

1. **D1: colours.** Recommended: **do not retune the design system.** Logo files are fixed artwork and keep their own hexes. Chrome colours (`theme-color`, manifest `theme_color`, email header band, in-app ripple) keep using tokens (`#1E3A8A` / accent). Both navies only sit side by side on light surfaces, where the difference is subtle; on navy and dark surfaces the all-white reversed mark is used. Alternative (token retune to `#0B2E86` / `#D45D00`) touches `docs/design/**`, every mockup and email goldens, so it needs its own plan.
2. **D2: lookup scope.** Recommended: replace the magnifier only in **searching / waiting visuals** (the matching radar, and any tradie-list loading spinner found in M4.4). Keep `Icons.search` in text inputs (`home_search`, "Find a service") and keep empty-state glyphs; a ripple in an input would read as a loading state.
3. **D3: email logo delivery.** Recommended: **inline CID attachment** of an embedded PNG (no hosting, works in Gmail/Outlook/Apple Mail), with `Brand:EmailLogoUrl` (currently deprecated) revived as an optional override for a hosted HTTPS PNG once a CDN exists. Alternative: host only; blocked until infra provides a URL.
4. **D4: new dependencies.** Recommended: **none.** Native icon generation uses ImageMagick (`convert`) in a one-off script, not `flutter_launcher_icons`; the ripple is a `CustomPainter`, not Rive/Lottie. If the owner prefers `flutter_launcher_icons` (dev dependency), AGENTS.md requires sign-off first.

Record outcomes in section 9.

## 4. Rules for the implementing model

- **One source of truth.** Curated assets live in `docs/design/brand/`; `web/`, `mobile/` and `backend/` hold **copies** produced by `scripts/brand-sync.mjs` (same pattern as `web/scripts/sync-design.mjs`). Never hand-edit a copy; never hand-copy files.
- Web kit CSS is authored in `docs/design/web/css/kit.css` then `npm run design:sync` in `web/`. Do not edit `web/src/theme/*`.
- Mobile: no raw numbers or `Color(0x...)` in widget files. SVG/PNG artwork keeps its own colours; the ripple widget uses `context.th.*` and new `Sizes` tokens added to `th_tokens.dart`. Light and dark themes both required. Keep the existing key `ValueKey('matching-radar')` and all `Semantics`/`Key`s.
- Honour reduced motion everywhere (web `prefers-reduced-motion`, mobile `THMotion` / the existing `_animationsEnabled`).
- Marks next to a text wordmark are decorative: `alt=""` / `excludeSemantics`. The text keeps the accessible name.
- Never inline the 76 KB animated SVG into a bundle or a template.
- Do not add the pack's `.DS_Store`, `__MACOSX/` or `tradiehunter-original.svg` anywhere.
- Update docs in the same PR via the `docs-sync` skill (`docs/OPERATIONS.md`, `docs/design/web/COMPONENTS.md`, `docs/DESIGN.md`).

## Phase A: Canonical assets and sync script (do first)

- [ ] **A1** Create `docs/design/brand/` with: `mark.svg`, `mark-reversed.svg` (copy of `logo-reversed.svg`), `mark-mono.svg` (copy of `logo-mono.svg`), `favicon.svg`, `favicon-32.png`, `favicon-64.png`, `apple-touch-icon.png` (from `apple-touch-icon-180.png`), `android-chrome-192.png`, `android-chrome-512.png`, `maskable-192.png`, `app-icon-maskable-512.png`, `app-icon-maskable-1024.png`, `app-icon-1024.png`, `logo-horizontal.svg`, `logo-stacked.svg`, `tradiehunter-animated.svg` (stripped, A2), `README.md` (this inventory + colour rules). Optionally add the pack's `index.html` as `preview.html` after fixing the two wrong `src` names (F9). (S)
- [ ] **A2** Strip provenance metadata from the animated SVG before committing: `python3 -c "import re,sys;s=open(sys.argv[1]).read();open(sys.argv[2],'w').write(re.sub(r'<metadata>.*?</metadata>','',s,flags=re.S))" in.svg docs/design/brand/tradiehunter-animated.svg`. Expect ~76.5 KB. Open it in a browser and confirm the animation still plays. (S)
- [ ] **A3** Add `scripts/brand-sync.mjs` with a `pairs` table and `--check` (exit 1 on drift), mirroring `web/scripts/sync-design.mjs`. Pairs: the copies listed in Phases W, M and B (web `public/`, mobile `assets/brand/logo/` and `web/`, `backend/Email/Assets/`). Add root `package.json` scripts `brand:sync` and `brand:check`. Run `brand:check` in the same CI job as `design:check`. (M)

## Phase W: Web (`web/`, admin dashboard)

Web has no tradie-lookup screen (admin only). It gets the icons, the emblem in the shell, and a reusable `RippleLoader` for async states.

- [ ] **W1 Favicon and touch icon.** Sync to `web/public/`: `favicon.svg` (replaces the Vite bolt), `favicon-32.png`, `apple-touch-icon.png`. In `web/index.html` keep the SVG `<link rel="icon">` and add
  `<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png" />` and `<link rel="apple-touch-icon" href="/apple-touch-icon.png" />`. Leave `theme-color` `#1E3A8A` (D1). (S)
- [ ] **W2 Emblem files.** Sync `mark.svg` and `mark-reversed.svg` to `web/public/brand/`. (S)
- [ ] **W3 `BrandMark` component.** Add `web/src/features/branding/components/BrandMark.tsx` rendering two images, `alt=""`, fixed `width`/`height` (no layout shift):
  ```tsx
  export const BrandMark: React.FC<{ size?: number; className?: string }> = ({ size = 28, className }) => (
    <span className={['brand-mark', className].filter(Boolean).join(' ')} aria-hidden="true">
      <img className="brand-mark-light" src="/brand/mark.svg" width={size} height={size} alt="" />
      <img className="brand-mark-dark" src="/brand/mark-reversed.svg" width={size} height={size} alt="" />
    </span>
  );
  ```
  (S)
- [ ] **W4 Kit CSS** (in `docs/design/web/css/kit.css`, then `npm run design:sync`). Show the reversed mark on dark contexts **and** in dark theme (the navy ring has no contrast on dark surfaces), mirroring the `.wordmark` rules:
  ```css
  .brand-mark { display: inline-flex; flex: none; }
  .brand-mark-dark { display: none; }
  .on-dark .brand-mark-light, .sidebar .brand-mark-light, .hero .brand-mark-light,
  :root[data-theme="dark"] .brand-mark-light { display: none; }
  .on-dark .brand-mark-dark, .sidebar .brand-mark-dark, .hero .brand-mark-dark,
  :root[data-theme="dark"] .brand-mark-dark { display: inline; }
  ```
  Verify the `.sidebar` selectors against how `.wordmark` is scoped (`web/src/theme/components.css` lines ~72-75, generated from `kit.css`) and that `.is-rail` still shows the compact mark: replace the `.monogram` glyph with `<BrandMark />`. (M)
- [ ] **W5 Place the lockup.** `BrandMark` + `BrandWordmark` in `SidebarNav.tsx`, `MobileDrawer.tsx`, `AdminLogin.tsx` (hero and card), and `TopBar.tsx` (`phone-only`, mark at 24). Keep `BrandWordmark` text (it follows `useBrandConfig` white-label name). (M)
- [ ] **W6 `RippleLoader`** (spec in section 8.1): component + kit CSS, used as the in-flight state for the search-driven lists in `UserListPage.tsx` and `JobListPage.tsx` (when `isFetching` and a query is set) and as the route-suspense fallback if one exists (grep `Suspense` in `App.tsx`). Keep the lucide `Search` icon in the input (D2). (M)
- [ ] **W7 (optional) Animated hero.** Sync `tradiehunter-animated.svg` to `web/public/brand/` and use it as a decorative `<img alt="">` (height ~320) on the login hero only, `loading="lazy"`; SMIL plays inside `<img>`. Park `[~]` if it crowds the hero. (S)
- [ ] **W8 Docs.** `docs/design/web/COMPONENTS.md`: add `BrandMark` and `RippleLoader`. (S)

## Phase M: Mobile (`mobile/`, Flutter)

- [ ] **M0 Recon.** View the current launcher art (`mipmap-xxxhdpi/ic_launcher.png`, `AppIcon.appiconset/Icon-App-1024x1024@1x.png`, `LaunchImage*.png`, `drawable/launch_background.xml`) and note whether they match the old pin brand. Confirm the `assets/brand/` pin files are unused: `grep -rn "assets/brand" mobile/lib` should only hit `google-g.svg`. (S)
- [ ] **M1 In-app marks.** Sync `mark.svg` and `mark-reversed.svg` to `mobile/assets/brand/logo/` and add `- assets/brand/logo/` to `pubspec.yaml` (`assets:` is not recursive). Add `ThBrandMark({double size, bool onDark})` to `th_widgets.dart` using `SvgPicture.asset` (already a dependency). It chooses `mark-reversed.svg` when `onDark` is true **or** the theme is dark. Size from a new `Sizes.brandMark*` token. `excludeSemantics: true`. (M)
- [ ] **M2 Place the mark.** `splash_screen.dart`: `ThBrandMark(onDark: true)` centred above the large wordmark (rings stay). `sign_in_screen.dart` / `sign_up_screen.dart`: small mark left of `THWordmark()`. Do not change copy or layout order otherwise. Update the matching mockup frames (`splash`, `sign_in`, `sign_up`) in `docs/design/mobile/ast/screens.mjs` and rebuild PNGs so `scripts/check-mockup-pngs.py` stays green. (M)
- [ ] **M3 Native icons** (one-off script `scripts/brand-native-icons.sh`, outputs are committed; requires ImageMagick `convert` with SVG support, or `rsvg-convert`):
  - **iOS** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`: source `app-icon-maskable-1024.png`, `convert src -resize NxN -alpha off out.png` for these existing filenames/px: 20@1x 20, 20@2x 40, 20@3x 60, 29@1x 29, 29@2x 58, 29@3x 87, 40@1x 40, 40@2x 80, 40@3x 120, 60@2x 120, 60@3x 180, 76@1x 76, 76@2x 152, 83.5@2x 167, 1024 1024. Gate: `identify -format '%[channels]' Icon-App-1024x1024@1x.png` prints `srgb` (no alpha) or the App Store rejects it. `Contents.json` stays unchanged.
  - **Android legacy** `res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`: source `app-icon-1024.png`, 48 / 72 / 96 / 144 / 192 px.
  - **Android adaptive:** add `res/mipmap-anydpi-v26/ic_launcher.xml` (`<adaptive-icon>` with `@color/ic_launcher_background` = `#FFFFFF`, `@drawable/ic_launcher_foreground`, and `<monochrome android:drawable="@drawable/ic_launcher_monochrome"/>`). Foreground PNGs in `drawable-{mdpi..xxxhdpi}` at 108 / 162 / 216 / 324 / 432 px, rendered from `mark.svg` scaled to ~56% of the canvas and centred (keeps it inside the 72dp safe zone); monochrome from `mark-mono.svg` fills `#000`. Do **not** use the maskable PNG as the foreground (the mask would crop it).
  - **Notification icon:** render `mark-mono.svg` with `currentColor` replaced by `#FFFFFF` to `res/drawable-{mdpi..xxxhdpi}/ic_stat_tradiehunter.png` at 24 / 36 / 48 / 72 / 96 px; in `AndroidManifest.xml` add `com.google.firebase.messaging.default_notification_icon` (`@drawable/ic_stat_tradiehunter`) and `default_notification_color` (a `@color` equal to the brand token). (L)
- [ ] **M3b Native launch screens.** Keep the solid hero-navy background so there is no flash into the Flutter splash; centre the reversed mark PNG on `drawable/launch_background.xml` and `LaunchImage*.png` only if M0 shows they currently carry the old pin. (S)
- [ ] **M3c Flutter web.** Replace `mobile/web/icons/Icon-192.png` (`android-chrome-192`), `Icon-512.png` (`android-chrome-512`), `Icon-maskable-192.png` (`maskable-192`), `Icon-maskable-512.png` (`app-icon-maskable-512`), `favicon.png` (`favicon-64`). Rewrite `mobile/web/manifest.json` from the pack's `manifest.webmanifest`: real `description`, keep `name`/`short_name` TradieHunter, `theme_color` per D1, paths as `icons/...`. `index.html`: `apple-touch-icon` stays `icons/Icon-192.png`. (S)
- [ ] **M4 Ripple replaces the magnifier** (spec in section 8.2):
  - [ ] **M4.1** Add to `th_tokens.dart` `Sizes`: `rippleCore`, `rippleStrokeBrand`, `rippleStrokeAccent`. Reuse `Sizes.radarDiameter` (240) and `THDurations.radarCycle` (2000 ms). Ring alpha peaks, ring counts and phase offsets stay file-level consts in `th_ripple.dart` with a "count/ratio, not a design token" comment, exactly as `ho_radar_screen.dart` does today (there is no `Alpha` class in `th_tokens.dart`).
  - [ ] **M4.2** Add `ThRipple` (`StatelessWidget` + `CustomPainter`) to `lib/ui/design/` (new file `th_ripple.dart`, exported like the other `th_*` files).
  - [ ] **M4.3** In `ho_radar_screen.dart`, delete `_kRadarRings`, `_kRingStartScale`, `_kRingPeakAlpha`, `_kRingStroke`, `_Radar._ring` and the `Icons.search` core; `_Searching` renders `ThRipple(animation: radar)`. Keep `RepaintBoundary` and the `matching-radar` key. **Keep** `Sizes.radarCore` / `radarCoreIcon`: `_StatusPanel` (same file, ~line 370) still uses them.
  - [ ] **M4.4** Find other searching visuals: `grep -n "CircularProgressIndicator\|THSpinner" mobile/lib/ui/homeowner/ho_browse_tradies_screen.dart mobile/lib/ui/homeowner/ho_choose_tradie_screen.dart`. Swap a spinner for `ThRipple` only where the screen is "finding tradies" and the area is at least 120 px square; leave inline button spinners alone (D2).
  - [ ] **M4.5** Update the `ho_radar` mockup frame (the file header says it is `needs-design`) so design and code match.
- [ ] **M5 Tests.** Find the radar/matching tests: `grep -rln "matching-radar" mobile/test mobile/integration_test mobile/patrol_test .maestro`. Update them: radar still found by key, **no** `Icons.search` descendant, reduced-motion path renders static rings (`animation == null`). Add a golden or `matchesGoldenFile` only if the repo already uses goldens for this screen. (M)
- [ ] **M6 Cleanup.** After M1-M5, delete unreferenced old pin assets in `mobile/assets/brand/` (`wordmark-*`, `splash-logo*`, `app-icon-*` pin versions, `png/` duplicates) only if `grep -rn "<filename>" mobile .maestro docs` shows no use; remove the `assets/brand/png/` pubspec line if the folder is emptied. Keep `google-g.svg` and the `map-pin-*.svg` files. (S)

## Phase B: Backend email templates

SVG is not usable in Gmail/Outlook, so the email emblem is a **PNG**, and the wordmark stays live text (Lexend with Arial fallback, as today) so dark mode, image-blocking and plain-text twins keep working.

- [ ] **B1 Render the email emblem.** From `docs/design/brand/mark-reversed.svg` (all white) produce `backend/Email/Assets/th-mark-reversed.png` at **96x96** (displayed at 48x48, 2x). Add a `scripts/brand-sync.mjs` rule or note the command (`convert -background none -density 384 mark-reversed.svg -resize 96x96 th-mark-reversed.png`). Keep it under 8 KB (`pngquant`/`oxipng` if needed). (S)
- [ ] **B2 Embed the asset.** `FixoApi.csproj` next to the existing `<EmbeddedResource Include="Email\**\*.cshtml" />` add `<EmbeddedResource Include="Email\Assets\*.png" />`. Add `Email/EmailAssets.cs` exposing `byte[] Mark` loaded once from the assembly manifest. (S)
- [ ] **B3 Layout.** In `_EmailLayout.cshtml` replace the single header `<span>` with a two-cell, Outlook-safe lockup inside the existing `th-header` `<td>` (keep `bgcolor`, gradient and radius as is):
  ```html
  <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
    <td style="padding-right:12px;" valign="middle">
      <img src="@Model.MarkSrc" width="40" height="40" alt="" style="display:block; border:0; outline:none; text-decoration:none; width:40px; height:40px;" />
    </td>
    <td valign="middle">@* existing wordmark <span>, unchanged *@</td>
  </tr></table>
  ```
  `alt=""` because the adjacent text carries the name; with images blocked the header still reads "TradieHunter". Add `MarkSrc` (string) to `EmailLayoutModel` (`EmailModels.cs`). (M)
- [ ] **B4 Resolve `MarkSrc`.** In `EmailTemplateRenderer`: if `Brand:EmailLogoUrl` is set use it (revive the option, update the XML doc in `BrandOptions.cs`; D3); otherwise `cid:th-mark`. Add a render option for previews that substitutes a `data:image/png;base64,...` URI (browsers cannot resolve `cid:`). `EmailPreviewController` passes that option. (M)
- [ ] **B5 Attach the CID.** In `SmtpEmailSender` (the `BodyBuilder` at ~line 415), when the rendered HTML contains `cid:th-mark`, add `var img = body.LinkedResources.Add("th-mark.png", EmailAssets.Mark); img.ContentId = "th-mark";` so MailKit builds `multipart/related`. The text part stays first in `multipart/alternative`. Legacy plain-text sends are unchanged. (S)
- [ ] **B6 Tests.** In `EmailTemplateRendererTests`/`EmailCopyInvariantTests`: header contains an `<img ... width="40" height="40" alt="">` and the wordmark text; `MarkSrc` is `cid:th-mark` by default and the override URL when configured; a `SmtpEmailSender` message-build test asserts one linked resource with `ContentId == "th-mark"` and `image/png`. Regenerate the 10 goldens in `Goldens/email/` with the `UPDATE_` env var documented in the golden test, review the diff is **header only**, commit. Run inside the container: `docker compose run --rm --entrypoint /bin/bash api -c "dotnet test backend/FixoApi.Tests"`. (M)
- [ ] **B7 Docs and manual check.** `docs/OPERATIONS.md` section 1: header now emblem PNG (CID) + text wordmark, `Brand:EmailLogoUrl` is an optional override again, add `th-mark` to the client matrix (Gmail web/iOS/Android, Outlook 2016 + web, Apple Mail light/dark, Yahoo). Open `GET /api/admin/email-preview/Otp` in the browser and send one real mail through MailHog to confirm the inline image displays. (S)

## Phase V: Verification (run before merging each phase)

- [ ] **V1 Drift:** `node scripts/brand-sync.mjs --check`, `npm run design:check`, `npm run design:legacy` (in `web/`), `npm run build` (web).
- [ ] **V2 Web:** `scripts/web/render-probe.py` asserts `img.brand-mark-light`/`-dark` in the shell and login; screenshot sidebar in light, dark, rail and phone widths; Playwright specs in `web/e2e` still pass (the wordmark text is unchanged).
- [ ] **V3 Mobile:** `flutter analyze`, `flutter test` from `mobile/`; run the app on an Android 13+ emulator (adaptive + themed icon, notification icon via an FCM test message) and an iOS simulator (icon, no-alpha check); open the matching radar in light, dark and with reduced motion (OS setting) and confirm: no magnifier, rings expand and fade, no jank (RepaintBoundary kept).
- [ ] **V4 Email:** B6 tests green; manual client matrix (B7).
- [ ] **V5 Size budget:** `web/dist` grows by under 120 KB (assets + CSS); email HTML grows by under 1 KB (the PNG is a separate part).

## 8. Ripple specification

### 8.1 Web `RippleLoader`

Inline SVG, one cycle = 2 s, ring geometry from the animated SVG, colours from kit variables (`--brand`, `--accent`), so it follows light/dark themes.

```tsx
export const RippleLoader: React.FC<{ size?: number; label?: string }> = ({ size = 96, label = 'Searching' }) => (
  <span className="ripple-loader" role="status" aria-label={label} style={{ width: size, height: size }}>
    <svg viewBox="0 0 200 200" aria-hidden="true">
      <circle className="rl-core" cx="100" cy="100" r="7" />
      <circle className="rl-ring rl-a" cx="100" cy="100" r="92" />
      <circle className="rl-ring rl-a rl-late" cx="100" cy="100" r="92" />
      <circle className="rl-ring rl-b" cx="100" cy="100" r="61" />
    </svg>
  </span>
);
```

```css
.ripple-loader { display: inline-flex; }
.ripple-loader svg { width: 100%; height: 100%; overflow: visible; }
.rl-core { fill: var(--brand); }
.rl-ring { fill: none; opacity: 0; transform-box: fill-box; transform-origin: center;
  vector-effect: non-scaling-stroke; animation: rl-expand 2s ease-out infinite; }
.rl-a { stroke: var(--brand); stroke-width: 3; }
.rl-b { stroke: var(--accent); stroke-width: 2; animation-delay: .2s; }
.rl-late { animation-delay: 1s; }
@keyframes rl-expand { 0% { transform: scale(.08); opacity: .9; } 100% { transform: scale(1); opacity: 0; } }
@media (prefers-reduced-motion: reduce) {
  .rl-ring { animation: none; opacity: .35; }
  .rl-b, .rl-late { display: none; }
}
```

Notes: `vector-effect: non-scaling-stroke` keeps the stroke constant while the ring scales (Safari does not animate the SVG `r` attribute reliably). `role="status"` plus a visible label nearby, never a bare spinner.

### 8.2 Mobile `ThRipple` (replaces `Icons.search` core in `_Radar`)

Geometry: one small solid core (`c.brand`) emits 3 **brand** rings (offsets 0, 1/3, 2/3 of the cycle, reach = full diameter) and 2 **accent** rings (`c.accent`, offsets 0.1 and 0.6, reach 0.66 x diameter, thinner), each fading from its peak alpha to 0 as it expands. Reduced motion (`animation == null`): the core plus 3 static concentric rings at 35% / 20% / 10% alpha.

```dart
class ThRipple extends StatelessWidget {
  const ThRipple({super.key, required this.animation});
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: Sizes.radarDiameter,
        child: CustomPaint(
          key: const ValueKey('matching-radar'),
          painter: _RipplePainter(animation, brand: c.brand, accent: c.accent),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t, {required this.brand, required this.accent}) : super(repaint: t);
  final Animation<double>? t;
  final Color brand;
  final Color accent;

  void _ring(Canvas canvas, Offset o, double reach, double phase, Color color, double peak, double stroke) {
    final p = ((t?.value ?? 0) + phase) % 1;
    final r = Sizes.rippleCore + (reach - Sizes.rippleCore) * Curves.easeOut.transform(p);
    canvas.drawCircle(o, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * (1 - p) + 0.5   // stroke thins as it expands, as in the SVG
      ..color = color.withValues(alpha: peak * (1 - p)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final o = size.center(Offset.zero);
    final reach = size.width / 2;
    if (t == null) { /* static rings at the 35/20/10% alphas, then core */ }
    else {
      for (var i = 0; i < 3; i++) { _ring(canvas, o, reach, i / 3, brand, _kBrandPeak, Sizes.rippleStrokeBrand); }
      for (final ph in const [0.1, 0.6]) { _ring(canvas, o, reach * 0.66, ph, accent, _kAccentPeak, Sizes.rippleStrokeAccent); }
    }
    canvas.drawCircle(o, Sizes.rippleCore, Paint()..color = brand);
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.brand != brand || old.accent != accent || old.t != t;
}
```

The literals above (`0.66`, `0.1`, `0.6`, `0.5`, `i / 3`, `35/20/10`) are illustrative: lift them into named tokens or file-level consts with a "count/ratio, not a design token" comment the way `ho_radar_screen.dart` does today. `_kBrandPeak` / `_kAccentPeak` (about 0.9 and 0.9 in the SVG; use the existing radar's 0.45 for the brand ring if 0.9 looks heavy on device) are file-level consts. Core is the **only** solid element: no glyph, no icon.

## 9. Decisions and parked items

| Item | Outcome |
|---|---|
| D1 colours (artwork vs tokens) | _pending_ (recommended: keep tokens, artwork unchanged) |
| D2 lookup scope | _pending_ (recommended: searching visuals only, keep input glyphs) |
| D3 email logo delivery | _pending_ (recommended: CID default, hosted override) |
| D4 dependencies | _pending_ (recommended: none) |
| W7 animated login hero | optional; park if it crowds the hero |
| Token retune to `#0B2E86` / `#D45D00` | out of scope; separate plan if D1 is reversed |
