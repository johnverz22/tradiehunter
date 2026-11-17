# Components: TradieHunter Web Design System v1

> Implementation: `css/kit.css` (class names below). Runnable reference with every state: `mockups/system.html`. Screens: `mockups/index.html`. Names describe structure and purpose, not appearance. Max five variants per component.

## Inventory

| Level | Components |
|---|---|
| Atoms | Button, Icon button, Badge, Avatar, Tile, Label, Help and Error text, Spinner, Skeleton |
| Molecules | Field (label + control + help), Select, Textarea, Search, Choice (checkbox, radio, switch), Segmented, Tabs, Chip, Dropzone, Banner, Toast, Stat, Description list, Breadcrumb, Pagination, Menu |
| Organisms | Data table, Filter bar, Card, Modal, Stepper, Timeline, Empty state, Sidebar, Top bar |
| Templates | App shell, Page header, Queue page, Detail page, Sign-in |

## Specifications

| Component | Purpose | Variants (class) | States and behaviour | Accessibility |
|---|---|---|---|---|
| **Button** `.btn` | Trigger an action | `btn-accent` (the one commit action), `btn-primary`, `btn-secondary`, `btn-ghost`, `btn-danger`, `btn-danger-outline`. Sizes `btn-sm` 32, default 40, `btn-lg` 48. `btn-block` | hover (14% darker via ink mix), focus ring, disabled (`surface-alt`), `is-loading` (spinner, `aria-busy`, no pointer events) | Real `<button>`. Label says what happens ("Verify payment", not "Submit"). 44 px on coarse pointers |
| **Icon button** `.btn-icon` | Compact action | Same kinds and sizes | Same | `aria-label` required |
| **Field** `.form-row` > `.label` + `.field` | Text entry | `.field`, `.field-sm`, with `.input-icon` | default, hover, focus (2 px ring + border), invalid (`aria-invalid`, red border, `.error` with icon), disabled | `<label for>`, help and error linked with `aria-describedby`. Optional is marked with `.opt`; required is default. 16 px text on coarse pointers |
| **Select** `.select-wrap` > `.select` | Choose one of a list | Native `<select>` | Same as Field | Native semantics kept |
| **Textarea** `.textarea` | Multi-line text | none | Same as Field | Same |
| **Choice** `.check`, `.radio`, `.switch` in `.choice` | Binary and single choice | checkbox, radio, switch (`role="switch"`) | checked, disabled, focus | Whole `<label>` is the target |
| **Segmented** `.segmented` | Switch between 2–4 views of the same data | none | `aria-pressed` | Group has a label |
| **Tabs** `.tabs` | Switch panels | none | `aria-selected`, underline | `role="tablist"`, arrow-key roving |
| **Chip** `.chip` | Toggle a filter | none | `aria-pressed` | Button |
| **Badge** `.badge` | Short status or count | `badge-neutral` (default), `-info`, `-ok`, `-warn`, `-danger`; `dot`; `badge-lg` for page headers | static | Text carries the meaning; `forced-colors` adds a border |
| **Banner** `.banner` | Persistent inline message | `banner-info`, `-ok`, `-warn`, `-danger` | Optional action button; stays until cause is gone or dismissed | `role="alert"` for danger, `role="status"` otherwise. Icon + title + text |
| **Toast** `.toast` | Short confirmation | `toast-ok`, `-danger`, `-warn`, default info | Success and info auto-dismiss (3 s, matching mobile). Errors and warnings do not auto-dismiss (WCAG 2.2.1) and also appear inline | Live region; never the only place an error appears |
| **Empty state** `.empty` | Say what is empty and what to do | with or without action | static | Heading + text |
| **Skeleton**, **Spinner** | Loading | `.skeleton` rows, `.spinner` | shimmer disabled under reduced motion | Container gets `aria-busy` |
| **Card** `.card` | Group related content | `tone-accent` (needs attention), `tone-danger`, `flush` (table inside) | Optional `.card-head` with title and one action | Title is an `h2` |
| **Stat** `.card.stat` | One headline number | `attention` (accent border + warn hint). Link when it navigates | hover border | Link has a full label ("Pending verifications: 5") |
| **Description list** `.dl` | Label and value pairs | `.total` row for the sum, `.money`, `.mono` values | Stacks below 640 px | Real `<dl>` |
| **Data table** `.table-wrap` > `.table` | Scan and act on a list | `table--compact`; column kinds: text, link (+ sub line), status, money, mono, actions | sticky header, row hover, selected row, sortable header buttons with `aria-sort`. Scrolls inside its wrapper (min 640 px) | `<th scope="col">`; actions column has a visually hidden header; caption when the table is not under a heading |
| **Filter bar** `.filterbar` | Narrow a list | search + selects + chips | wraps | `role="search"` |
| **Pagination** `.pagination` | Move between pages | none | current page `aria-current`, prev disabled on first | Buttons have `aria-label` for Previous and Next |
| **Modal** `.scrim` > `.modal` | Confirm or collect input that blocks the page | `modal-sm` 400, default 560, `modal-lg` 720 | Opens with a short pop; bottom sheet below 640 px | `role="dialog"`, `aria-modal`, `aria-labelledby`; trap focus; Esc closes; return focus; destructive dialogs focus Cancel first |
| **Menu** `.menu` | Account and row menus | none | item hover | `role="menu"` / `menuitem`, arrow keys, Esc |
| **Stepper** `.stepper` | Job lifecycle | item states `done`, `current`, `halt`, todo. Vertical below 768 px | check icon for done, cross for halt | `<ol>`, `aria-current="step"` |
| **Timeline** `.timeline` | Status and audit history | item tones `done`, `warn`, `danger` | none | `<ol>` with `<time>` |
| **Avatar** `.avatar` | Identify a person | `-sm` 32, default 40, `-lg` 56 | none | Decorative; name appears beside it |
| **Sidebar** `.sidebar` | Primary navigation | full 240, `is-rail` 64, `is-drawer` | current page `aria-current="page"` + gold marker; counts as `.nav-count` | `aria-label="Admin navigation"`; rail keeps labels in the DOM |
| **Top bar** `.topbar` | Menu button (phone), theme switch | none | sticky, glass | Theme button has a label |
| **Sign-in** `.auth` | Staff entry | none | Aside hidden below 1024 px | One `h1` |

## Status map (web `StatusBadge`)

Source: `STATUS` in `ast/dsl.mjs`. Replaces the old green/amber/red/blue/gray/brand tones. Unknown statuses fall back to neutral.

| Tone | Statuses |
|---|---|
| `ok` | Booked, Active, Verified, Resolved |
| `info` | Requested, InProgress, Superadmin, Staff, Tradie |
| `warn` | AwaitingPayment, PaymentReview, AwaitingConfirmation, Unverified, Open |
| `danger` | Cancelled, Disputed, Escalated |
| `neutral` | Completed, Expired, Homeowner, Inactive, None |

## React contract (target props)

The app already has `Banner`, `ConfirmModal`, `DataTable`, `DescriptionList`, `FilterBar`, `InfoRow`, `JobProgressStepper`, `Modal`, `PageHeader`, `Pagination`, `StatCard`, `StatGrid`, `StatusBadge`, `ThemeToggle`. They keep their names and render the classes above. Missing and worth extracting when migrating (each appears 3+ times): `Button` (`kind`, `size`, `loading`, `icon`), `Field` (`label`, `help`, `error`, `optional`), `Badge` (`tone`, `dot`, `size`), `EmptyState`, `Toast`.
