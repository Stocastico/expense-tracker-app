import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.DB_PATH ?? path.join(__dirname, '..', 'data', 'expenses.db');

fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

const db = new Database(DB_PATH);

db.exec(`
  CREATE TABLE IF NOT EXISTS transactions (
    id   TEXT PRIMARY KEY,
    data TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS budgets (
    id   TEXT PRIMARY KEY,
    data TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );
`);

export default db;
