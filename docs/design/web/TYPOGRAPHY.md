# Typography: TradieHunter Web Design System v1

> Source of truth: `tokens/tokens.json`. Generated: `--ty-*` shorthands and `.t-*` classes in `tokens/tokens.css`; `t-*` utilities in `tokens/theme.css`.

## Families

- **Lexend** (display): headings, controls, labels, big numbers. Same as mobile.
- **Source Sans 3** (body): reading text, table cells, money in tables (tabular figures).
- **System monospace** (`ui-monospace, SFMono-Regular, Menlo, Consolas`): ids, references, timestamps. Web only; mobile has no monospace.

Fallback for the first two is `system-ui, sans-serif`.

## Scale

| Class | Font | Size / weight / line | Use |
|---|---|---|---|
| `t-display` | Lexend | 32 / 600 / 1.2, -0.4 | Sign-in headline |
| `t-h1` | Lexend | 24 / 600 / 1.2, -0.2 | Page title (one per page) |
| `t-h2` | Lexend | 20 / 600 / 1.25 | Dialog title, section heading |
| `t-title` | Lexend | 16 / 600 / 1.3 | Card title, banner title |
| `t-button` | Lexend | 14 / 600 / 1.2 | Buttons, nav items, tabs, chips |
| `t-label` | Lexend | 12 / 600 / 1.3, +0.2 | Field labels, table headers. Sentence case, not all caps |
| `t-stat` | Lexend | 28 / 600 / 1.15, -0.3 | Stat card figure |
| `t-body` | Source Sans 3 | 15 / 400 / 1.5 | Paragraphs, field text |
| `t-body-sm` | Source Sans 3 | 14 / 400 / 1.45 | Table cells, dialog text, descriptions |
| `t-meta` | Source Sans 3 | 13 / 400 / 1.4 | Sub-lines, help, captions |
| `t-money` | Source Sans 3 | 14 / 600 / 1.45, tabular | Amounts in tables and lists |
| `t-mono` | Monospace | 13 / 400 / 1.4 | Ids, references, timestamps |

Field text rises to 16 px on coarse pointers so iOS does not zoom on focus. Minimum text size is 12 px.

## Loading fonts

The mockups link Google Fonts: `Lexend` 400–800 and `Source Sans 3` 400–700. For the app, either keep that `<link>` in `web/index.html` (current behaviour) or self-host woff2 files; self-hosting is not decided (see DESIGN_GUIDE §12). Family names must stay exactly `Lexend` and `Source Sans 3`.
