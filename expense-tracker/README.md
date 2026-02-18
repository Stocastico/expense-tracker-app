# Expense Tracker

A responsive personal finance Progressive Web App (PWA) built with React, TypeScript, and Vite. Track your income and expenses, set budgets, scan receipts with OCR, and gain insights through rich analytics — all stored locally on your device with no backend required.

## Features

- **Manual transactions** — Add one-off or recurring expenses and income
- **Receipt scanning** — Use your camera or upload an image; Tesseract.js OCR extracts the amount, merchant, date, and category
- **Smart category detection** — Automatically guesses the category from the merchant name (e.g. "Uber" → Transport)
- **Multi-currency** — 15 currencies with automatic formatting
- **Analytics** — Monthly bar chart, net balance trend line, per-category pie chart, spending predictions, and savings rate tracker
- **Budgets** — Set monthly/yearly spending limits per category with progress bars and alerts
- **Search & filter** — Filter by type, category, month; sort by date or amount
- **Export / Import** — Download data as CSV or JSON; restore from a JSON backup
- **Dark mode** — Toggle in Settings
- **PWA** — Install on iOS/Android home screen for a native-like experience
- **Offline-first** — All data stored in `localStorage`; no server needed

---

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| Node.js | 18 |
| npm | 9 |

---

## Quick start (development)

```bash
# 1. Clone the repository
git clone https://github.com/Stocastico/Claude-code-experiments.git
cd Claude-code-experiments/expense-tracker

# 2. Install dependencies
npm install

# 3. Start the dev server
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser. The page hot-reloads on every save.

---

## Running tests

```bash
# Run all tests once
npm run test:run

# Run tests in interactive watch mode
npm test

# Generate a coverage report (HTML + text)
npm run coverage
```

Coverage report is written to `coverage/index.html`. All thresholds are set at **85 %** (statements, branches, functions, lines).

---

## Building for production

```bash
npm run build
```

The compiled app is emitted to `dist/`. The build includes:
- Code splitting and tree-shaking
- PWA service worker (Workbox) for offline support
- `manifest.webmanifest` for install prompts

### Preview the production build locally

```bash
npm run preview
```

Opens a local server at [http://localhost:4173](http://localhost:4173) that serves the production bundle.

---

## Persistent local deployment

Because the app stores all data in the browser's `localStorage`, data is automatically persisted between sessions in the same browser profile. No database or server is needed.

### Option 1 — Run the production build with a static file server (recommended)

```bash
# Build once
npm run build

# Serve with any static server, e.g. serve (Node.js)
npx serve dist

# Or with Python
python3 -m http.server 8080 --directory dist
```

Navigate to [http://localhost:8080](http://localhost:8080) (or the port printed by the server).

### Option 2 — Docker (self-contained deployment)

Create a `Dockerfile` inside `expense-tracker/`:

```dockerfile
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Build and run:

```bash
docker build -t expense-tracker .
docker run -p 8080:80 expense-tracker
```

Open [http://localhost:8080](http://localhost:8080).

> **Data persistence with Docker**: Because data lives in the browser's `localStorage`, it persists across container restarts as long as you use the same browser profile. There is no server-side state to mount.

### Option 3 — Free static hosting (GitHub Pages / Netlify / Vercel)

Run `npm run build`, then deploy the `dist/` folder to any static hosting provider.

---

## Installing as a PWA on iOS

1. Open the app in **Safari** on your iPhone or iPad.
2. Tap the **Share** button (box with arrow).
3. Choose **Add to Home Screen**.
4. The app will appear as a native-like icon and launch in standalone mode.

On Android, Chrome will show an **"Add to Home Screen"** banner automatically.

---

## Project structure

```
expense-tracker/
├── public/              # Static assets (icons)
├── src/
│   ├── components/
│   │   ├── layout/      # AppLayout (navigation shell)
│   │   ├── transactions/ # TransactionForm, TransactionItem
│   │   └── ui/          # Reusable primitives: Button, Card, Input, Modal, …
│   ├── pages/           # DashboardPage, TransactionsPage, AnalyticsPage,
│   │                    #   BudgetsPage, SettingsPage
│   ├── store/           # useStore (state), StoreContext, storage, defaults
│   ├── types/           # TypeScript interfaces
│   ├── utils/           # money, dates, stats, export, smartCategory helpers
│   └── test/            # Vitest test suites mirroring the src/ tree
├── vite.config.ts       # Vite + Tailwind + PWA + Vitest config
└── package.json
```

---

## Tech stack

| Layer | Library |
|-------|---------|
| UI framework | React 18 |
| Language | TypeScript (strict) |
| Bundler | Vite 6 |
| Styling | Tailwind CSS v4 |
| Charts | Recharts |
| OCR | Tesseract.js (dynamic import) |
| Icons | Lucide React |
| Dates | date-fns |
| PWA | vite-plugin-pwa (Workbox) |
| Testing | Vitest + @testing-library/react |
| Coverage | @vitest/coverage-v8 |

---

## Data export & backup

- **Settings → Export as CSV** — downloads all transactions in spreadsheet-compatible format.
- **Settings → Export as JSON** — full backup including budgets and settings.
- **Settings → Import from JSON** — restore from a previous JSON backup.

---

## License

MIT
