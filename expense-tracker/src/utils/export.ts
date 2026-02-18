import type { Transaction, AppState } from '../types';
import { formatDate } from './dates';

export function exportToCSV(transactions: Transaction[], categories: { id: string; name: string }[]): void {
  const catMap = Object.fromEntries(categories.map(c => [c.id, c.name]));
  const headers = ['Date', 'Type', 'Amount', 'Currency', 'Category', 'Merchant', 'Description', 'Tags', 'Notes', 'Recurring'];
  const rows = transactions.map(t => [
    formatDate(t.date, 'yyyy-MM-dd'),
    t.type,
    t.amount.toFixed(2),
    t.currency,
    catMap[t.categoryId] ?? t.categoryId,
    t.merchant ?? '',
    t.description,
    t.tags.join(';'),
    t.notes ?? '',
    t.isRecurring ? t.recurringFrequency ?? 'yes' : 'no',
  ]);
  const csv = [headers, ...rows].map(r => r.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')).join('\n');
  download(csv, 'expenses.csv', 'text/csv');
}

export function exportToJSON(state: AppState): void {
  const json = JSON.stringify(state, null, 2);
  download(json, 'expenses.json', 'application/json');
}

export function importFromJSON(file: File): Promise<Partial<AppState>> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = e => {
      try { resolve(JSON.parse(e.target?.result as string)); }
      catch { reject(new Error('Invalid JSON file')); }
    };
    reader.onerror = () => reject(new Error('Failed to read file'));
    reader.readAsText(file);
  });
}

function download(content: string, filename: string, mimeType: string): void {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
