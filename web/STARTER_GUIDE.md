# Web starter guide (React)

Run these yourself — not pre-generated.

```bash
cd web
npm create vite@latest app -- --template react-ts
cd app
npm install

# Core packages
npm install react-router-dom @microsoft/signalr axios
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

## Suggested project split (once scaffolded)
```
app/src/
├── routes/
│   ├── homeowner/     # Post a Job, Matches/Requests, Chat + Status, Profile
│   ├── tradie/        # Incoming Requests, Dashboard, Profile
│   └── admin/         # Users, Jobs, Disputes
├── components/        # Shared: TradieCard, JobStatusStepper, Badge, Button
├── lib/
│   ├── api.ts          # axios client against the .NET REST API
│   └── signalr.ts      # SignalR connection setup, shared by chat/status/match hooks
├── theme/              # Port design-system.html tokens here (--hue etc.) as CSS or Tailwind config
└── App.tsx             # Role-based route gating from the JWT claim
```

## First things to wire up
1. Auth flow calling the .NET Identity/JWT endpoints; store the token and decode the role claim for routing.
2. A single SignalR connection shared across chat, job-status, and match-notification listeners — don't open one connection per feature.
3. Port `../docs/design/design-system.html`'s CSS variables (`--brand-900` through `--brand-100`, `--amber`, spacing scale) into your Tailwind config or a global stylesheet before building screens, so components use tokens from day one.

Read `../docs/MVP-SPEC.md` for the screen list and `../docs/ARCHITECTURE.md` for the API contract this app talks to.
