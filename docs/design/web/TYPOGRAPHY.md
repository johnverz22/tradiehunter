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

## Fonts are self-hosted

`fonts/` holds the woff2 files and the generated `fonts/fonts.css` (`@font-face` rules, `font-display: swap`, `unicode-range`). No request goes to a font CDN.

| Family | Weights | Subsets |
|---|---|---|
| Lexend | 400, 500, 600, 700, 800 | latin, latin-ext |
| Source Sans 3 | 400, 500, 600, 700 | latin, latin-ext |

`latin-ext` is required, not optional: Māori macrons (ā ē ī ō ū) are U+0100 and above and exist only in those files. The browser fetches a subset only when a character from it appears. Files come from `@fontsource/lexend` 5.3.0 and `@fontsource/source-sans-3` 5.3.1 (SIL OFL 1.1; licences beside the files). They were copied once; there is no npm dependency. To update, replace the woff2 files from a newer release and rebuild.

The family names must stay exactly `Lexend` and `Source Sans 3`. In the app, copy `fonts/` to `web/public/fonts/` (or `web/src/assets/fonts/`) and import `fonts.css` before `tokens.css`. Mobile bundles its own ttf files separately (`mobile/assets/fonts/v2/`).
