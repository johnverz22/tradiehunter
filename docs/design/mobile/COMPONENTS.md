# Components — TradieHunter Design System v2

> Extracted from `DESIGN_GUIDE.md §5–§7`. Widget implementations live in `flutter/th_widgets.dart`.

## Signature elements (§5)

| Element | Widget | Description |
|---|---|---|
| **Hero card** | `THHero` | Navy gradient, gold eyebrow label, one large figure. Used for the attention item, amount to pay, offer countdown, net earnings. |
| **Bottom dock** | `THDock` | full-bleed bottom bar (opaque, flush with the bottom edge, 1 px `line` top hairline, no radius or shadow). Homeowner: five equal slots, Home, Jobs, **Post job**, Chat, Profile; Post job is the in-line gold centre slot (48 px rounded-square tile with `THHuntGlyph` in `onAccent`, label "Post job" in `accentText`). Tradie: four equal slots, same bar. The bar pads itself by the home-indicator inset and is laid out *below* routed content (`Column(Expanded(child), THDock)`), never overlaid. 744 to 1023 px: bar stays full width, slots centred in a 560 px column. 1024 px and wider: left rail, with the same gold Post job tile and label at the top. Labels are clamped to 1.3× text scale (Semantics labels stay full); no other text scaling changes (P4-12 stays open). Semantics label stays `New request`, key `post_job_fab`. `THHuntGlyph` is a hunter's crosshair with a plus (ring, four ticks, plus). |
| **Sticky action bar** | `THStickyBar` | Glass-blurred bar above the home indicator. Decline/accept pairs or a single CTA. Always above the home indicator. |
| **Progress segments** | `THProgress` | Five segments for the job lifecycle: Posted, Requested, Booked, In progress, Complete. Green = done, gold = current. |
| **Timeline** | `THTimeline` | Vertical timeline for what-happens-next and job history. |

## Component library: AST node → Flutter widget (§6)

| AST node | Flutter widget | Key props |
|---|---|---|
| `col`, `row` | `Column`, `Row` (+ `Padding`, `Expanded`) | `gap`, `pad`, `align`, `justify`, `x` (fill) |
| `card` | `THCard` | `tone` accent or danger, `pad` |
| `hero` | `THHero` | children |
| `grid` | `THGrid` | `cols`, `gap` |
| `text` | `THText` | `s` style, `tone`, `align`, `size`, `bold` |
| `icon` | `THIcon` | `n`, `size`, `tone` |
| `btn` | `THButton` | `k` primary, accent, secondary, inverse, ghost, danger. `sz` sm. `ic`. `w` auto |
| `ibtn` | `THIconButton` | `ic`, `k`, `dot` |
| `badge` | `THBadge` | `k` brand, ok, accent, danger, glass. `ic` |
| `avatar` | `THAvatar` | `v` initials, `sz` sm/md/lg, `inv` |
| `field` | `THField` | `l` label, `v`, `ic`, `tr`, `h`, `ph` |
| `pills` | `THPills` | `items` with `on` and `ic` |
| `seg` | `THSegmented` | `items`, `on` |
| `kv` | `THKeyValue` | `b`, `strong`, `tone`, `badge`, `copy` (dividers are automatic between siblings) |
| `prog`, `dots` | `THProgress`, `THDots` | `steps`, `done`, `cur` |
| `timeline` | `THTimeline` | `items` with `s` done/cur/todo |
| `dash` | `THDashBox` | upload zone: `ic`, `v`, `sub` |
| `ring` | `THRing` | countdown: `v`, `sub`, `pct` |
| `sw` | `THSwitch` | `on` |
| `bubble` | `THBubble` | `mine`, `time` |
| `tile`, `illus`, `photos`, `map`, `bars`, `stars`, `otp` | `THTile`, `THIllustration`, `THPhotoStrip`, `THMapPlaceholder`, `THBars`, `THStars`, `THOtp` | see `ast/dsl.mjs` |
| `listrow`, `divider`, `wordmark` | `THListRow`, `THDivider`, `THWordmark` | `badge`, `dot` (unread), `flat` |
| `bar` (screen meta) | `THAppBar` | title, subtitle |
| `meta.sticky`, `meta.dock` | `THStickyBar`, `THDock` | role homeowner or tradie |

> [!NOTE]
> `THMapPlaceholder` and `THPhotoStrip` are stand-ins. Replace them with your map widget and `Image.network` when wiring data.

## v1 → v2 widget mapping

| v1 widget (`Fixo*`) | v2 widget (`TH*`) | Notes |
|---|---|---|
| `FixoPrimaryButton` (gold CTA) | `THButton(kind: ButtonKind.accent)` | One per screen only |
| `FixoPrimaryButton` (navy) | `THButton(kind: ButtonKind.primary)` | Secondary filled actions |
| `FixoGhostButton` | `THButton(kind: ButtonKind.ghost)` | |
| `FixoAppBar` | `THAppBar` | |
| `FixoCard` | `THCard` | |
| `THHeroBand` | `THHero` | Hero card with gradient |
| `THStatusStrip` / `StatusBadge` | `THBadge` or `THProgress` | |
| `StickyActionBar` | `THStickyBar` | |
| `FixoNotice.*` | `THNotice.*` | Renamed for v2 consistency (D-3 decision) |
| `CustomBottomNavBar` + FAB | `THDock` | HO gets FAB with `THHuntGlyph`; tradie does not |

## Feedback notices

All transient feedback uses `THNotice` (renamed from `FixoNotice` in v2 — D-3 resolved). No `ScaffoldMessenger.showSnackBar`.

| Tone | Method | Use | Auto-dismiss |
|---|---|---|---|
| info | `THNotice.info` | Neutral confirmations, copy actions | 3 s |
| success | `.success` | Completed actions | 3 s |
| warning | `.warning` | Non-blocking caution | 4 s |
| error | `.error` | Failed operation to retry | 5 s |
| push | `.push(title, body, onTap)` | Foreground FCM banner | 5 s |

## Screen inventory (31 screens, §7)

Each screen has a Flutter class in `flutter/screens/<id>_screen.dart` and a route in `thScreenRoutes`.

**Entry and shared (8):** `splash`, `onboarding`, `role_select`, `sign_in`, `verify_otp`, `chat`, `notifications`, `profile`.

**Homeowner (16):** `ho_home`, `ho_post_quick`, `ho_post_project`, `ho_quotes`, `ho_quote_detail`, `ho_choose_tradie`, `ho_tradie_profile`, `ho_request_sent`, `ho_job_booked`, `ho_extra_cost`, `ho_review_completion`, `ho_payment`, `ho_payment_status`, `ho_review`, `ho_dispute`, `ho_jobs`.

**Tradie (7):** `tr_home`, `tr_lead`, `tr_job`, `tr_extra_cost`, `tr_complete`, `tr_earnings`, `tr_onboarding`.

> [!NOTE]
> Admin screens, error/empty states, and skeleton loaders are **not in the v2 AST** — these are handled in a separate design pass (D-4 decision).

## Role differences (§8)

| | Homeowner | Tradie |
|---|---|---|
| Dock | Home, Jobs, **Post job** (in-line, centre), Chat, Profile | Home, Jobs, Chat, Profile |
| Home hero | Approve final amount | Online switch and net this week |
| Primary gold actions | Choose a tradie, Request, Approve, Upload receipt | Accept job, Check in, Send for approval |
| Money shown | Total to pay, extras awaiting approval | Rate locked, commission, amount received |
| Unique flows | Post, quotes, dispute, review | Lead, check-in, extra-cost request, complete, onboarding |
