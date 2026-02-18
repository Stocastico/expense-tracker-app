import type { Transaction, AccountId } from '../types';
import { v4 as uuidv4 } from 'uuid';

export interface ParsedEntry {
  date: string;       // YYYY-MM-DD
  description: string;
  amount: number;     // positive = expense (debit), negative = credit/income
  merchant?: string;
}

// ─── PDF text extraction ───────────────────────────────────────────────────

/* c8 ignore start */
export async function extractPdfText(file: File): Promise<string> {
  const { getDocument, GlobalWorkerOptions } = await import('pdfjs-dist');
  // Use a local worker bundled by Vite
  GlobalWorkerOptions.workerSrc = new URL(
    'pdfjs-dist/build/pdf.worker.min.mjs',
    import.meta.url,
  ).toString();

  const arrayBuffer = await file.arrayBuffer();
  const pdf = await getDocument({ data: arrayBuffer }).promise;
  const parts: string[] = [];
  for (let i = 1; i <= pdf.numPages; i++) {
    const page = await pdf.getPage(i);
    const content = await page.getTextContent();
    const pageText = content.items
      .map((item: { str?: string }) => item.str ?? '')
      .join(' ');
    parts.push(pageText);
  }
  return parts.join('\n');
}
/* c8 ignore stop */

// ─── Heuristic transaction parser ─────────────────────────────────────────

// Matches dates in formats: DD/MM/YYYY, MM/DD/YYYY, DD.MM.YYYY, DD MMM YYYY, YYYY-MM-DD
const DATE_RE =
  /\b(\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4}|\d{4}-\d{2}-\d{2}|\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})/gi;

// Matches currency amounts like 1,234.56  or  1.234,56  or  1234.56
const AMOUNT_RE = /\b(\d{1,3}(?:[.,]\d{3})*[.,]\d{2}|\d+\.\d{2})\b/g;

const MONTH_MAP: Record<string, string> = {
  jan: '01', feb: '02', mar: '03', apr: '04', may: '05', jun: '06',
  jul: '07', aug: '08', sep: '09', oct: '10', nov: '11', dec: '12',
};

function parseDate(raw: string): string | null {
  raw = raw.trim();

  // YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;

  // DD MMM YYYY or D MMM YYYY
  const wordMatch = raw.match(/^(\d{1,2})\s+([A-Za-z]{3})\w*\s+(\d{2,4})$/);
  if (wordMatch) {
    const [, d, m, y] = wordMatch;
    const month = MONTH_MAP[m.toLowerCase().slice(0, 3)];
    if (!month) return null;
    const year = y.length === 2 ? `20${y}` : y;
    return `${year}-${month}-${d.padStart(2, '0')}`;
  }

  // DD/MM/YYYY or MM/DD/YYYY (assume DD/MM for European cards)
  const numMatch = raw.match(/^(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})$/);
  if (numMatch) {
    const [, a, b, y] = numMatch;
    const year = y.length === 2 ? `20${y}` : y;
    // Heuristic: if first number > 12, it must be the day
    const [day, month] = Number(a) > 12 ? [a, b] : [b, a];
    return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
  }

  return null;
}

function parseAmount(raw: string): number {
  // Normalise: remove thousands separators, convert comma decimal to dot
  const cleaned = raw
    .replace(/\.(?=\d{3}(?:[.,]|$))/g, '')  // remove dot thousands sep
    .replace(',', '.');                        // comma → dot decimal
  return parseFloat(cleaned);
}

export function parsePdfText(text: string): ParsedEntry[] {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
  const entries: ParsedEntry[] = [];

  for (const line of lines) {
    // Find all dates on this line
    const dates = [...line.matchAll(DATE_RE)].map(m => parseDate(m[0])).filter(Boolean) as string[];
    if (dates.length === 0) continue;

    // Find all amounts on this line
    const amounts = [...line.matchAll(AMOUNT_RE)].map(m => parseAmount(m[0])).filter(n => !isNaN(n) && n > 0);
    if (amounts.length === 0) continue;

    const date = dates[0];
    // Take the last amount (often the transaction amount in statement layouts)
    const amount = amounts[amounts.length - 1];

    // Build description: everything between first date and first amount that isn't numeric noise
    const desc = line
      .replace(DATE_RE, '')
      .replace(AMOUNT_RE, '')
      .replace(/\s{2,}/g, ' ')
      .trim();

    if (!desc || desc.length < 2) continue;

    entries.push({ date, description: desc, amount, merchant: desc.split(/\s+/).slice(0, 3).join(' ') });
  }

  return entries;
}

// ─── Convert parsed entries to Transaction objects ─────────────────────────

export function entriesToTransactions(
  entries: ParsedEntry[],
  options: { currency: string; accountId: AccountId; categoryId: string },
): Transaction[] {
  const now = new Date().toISOString();
  return entries.map(e => ({
    id: uuidv4(),
    type: e.amount >= 0 ? 'expense' : 'income',
    amount: Math.abs(e.amount),
    currency: options.currency,
    categoryId: options.categoryId,
    description: e.description,
    merchant: e.merchant,
    date: e.date,
    tags: [],
    isRecurring: false,
    accountId: options.accountId,
    createdAt: now,
    updatedAt: now,
  }));
}
