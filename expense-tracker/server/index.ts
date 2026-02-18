import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import db from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = Number(process.env.PORT ?? 3001);

app.use(cors());
app.use(express.json());

// ─── Health ──────────────────────────────────────────────────────────────────

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

// ─── Transactions ─────────────────────────────────────────────────────────────

app.get('/api/transactions', (_req, res) => {
  const rows = db.prepare('SELECT data FROM transactions').all() as { data: string }[];
  res.json(rows.map(r => JSON.parse(r.data)));
});

app.post('/api/transactions', (req, res) => {
  const items: unknown[] = Array.isArray(req.body) ? req.body : [req.body];
  const insert = db.prepare('INSERT OR REPLACE INTO transactions (id, data) VALUES (?, ?)');
  const insertAll = db.transaction((txs: Array<{ id: string }>) => {
    for (const tx of txs) insert.run(tx.id, JSON.stringify(tx));
  });
  insertAll(items as Array<{ id: string }>);
  res.json({ ok: true, count: items.length });
});

app.put('/api/transactions/:id', (req, res) => {
  const row = db.prepare('SELECT data FROM transactions WHERE id = ?').get(req.params.id) as { data: string } | undefined;
  if (!row) { res.status(404).json({ error: 'Not found' }); return; }
  const existing = JSON.parse(row.data);
  const updated = { ...existing, ...req.body, updatedAt: new Date().toISOString() };
  db.prepare('UPDATE transactions SET data = ? WHERE id = ?').run(JSON.stringify(updated), req.params.id);
  res.json(updated);
});

app.delete('/api/transactions/:id', (req, res) => {
  const deleteAll = req.query.deleteAll === 'true';
  db.prepare('DELETE FROM transactions WHERE id = ?').run(req.params.id);
  if (deleteAll) {
    // Delete all recurring instances that reference this parent
    const rows = db.prepare('SELECT id, data FROM transactions').all() as { id: string; data: string }[];
    const del = db.prepare('DELETE FROM transactions WHERE id = ?');
    const delRelated = db.transaction(() => {
      for (const r of rows) {
        const tx = JSON.parse(r.data);
        if (tx.recurringParentId === req.params.id) del.run(r.id);
      }
    });
    delRelated();
  }
  res.json({ ok: true });
});

// ─── Budgets ──────────────────────────────────────────────────────────────────

app.get('/api/budgets', (_req, res) => {
  const rows = db.prepare('SELECT data FROM budgets').all() as { data: string }[];
  res.json(rows.map(r => JSON.parse(r.data)));
});

app.post('/api/budgets', (req, res) => {
  const b = req.body as { id: string };
  db.prepare('INSERT OR REPLACE INTO budgets (id, data) VALUES (?, ?)').run(b.id, JSON.stringify(b));
  res.json(b);
});

app.delete('/api/budgets/:id', (req, res) => {
  db.prepare('DELETE FROM budgets WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

// ─── Settings ─────────────────────────────────────────────────────────────────

app.get('/api/settings', (_req, res) => {
  const row = db.prepare("SELECT value FROM settings WHERE key = 'app'").get() as { value: string } | undefined;
  res.json(row ? JSON.parse(row.value) : {});
});

app.put('/api/settings', (req, res) => {
  db.prepare("INSERT OR REPLACE INTO settings (key, value) VALUES ('app', ?)").run(JSON.stringify(req.body));
  res.json(req.body);
});

// ─── Sync (mobile app upload) ─────────────────────────────────────────────────

app.post('/api/sync', (req, res) => {
  const { transactions = [] } = req.body as { transactions: Array<{ id: string }> };
  const insert = db.prepare('INSERT OR REPLACE INTO transactions (id, data) VALUES (?, ?)');
  const insertAll = db.transaction(() => {
    for (const tx of transactions) insert.run(tx.id, JSON.stringify(tx));
  });
  insertAll();
  res.json({ ok: true, uploaded: transactions.length });
});

// ─── Static files (production) ────────────────────────────────────────────────

const distPath = path.join(__dirname, '..', 'dist');
app.use(express.static(distPath));
app.get('*', (_req, res) => {
  res.sendFile(path.join(distPath, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Expense Tracker server running on http://0.0.0.0:${PORT}`);
});
