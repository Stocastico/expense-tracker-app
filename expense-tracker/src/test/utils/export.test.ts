import { describe, it, expect, vi, beforeEach } from 'vitest';
import { exportToCSV, exportToJSON, importFromJSON } from '../../utils/export';
import type { Transaction, AppState } from '../../types';
import { DEFAULT_SETTINGS } from '../../store/defaults';

const makeTransaction = (overrides: Partial<Transaction> = {}): Transaction => ({
  id: 'tx1',
  type: 'expense',
  amount: 42.5,
  currency: 'USD',
  categoryId: 'food',
  description: 'Lunch',
  merchant: 'Cafe',
  date: '2024-01-15',
  tags: ['work', 'lunch'],
  notes: 'With colleagues',
  isRecurring: false,
  createdAt: '2024-01-15T12:00:00Z',
  updatedAt: '2024-01-15T12:00:00Z',
  ...overrides,
});

const categories = [{ id: 'food', name: 'Food & Dining' }];

// Capture content passed to Blob constructor using vi.stubGlobal
function captureBlobContent(fn: () => void): string {
  let captured = '';
  const OrigBlob = globalThis.Blob;
  vi.stubGlobal('Blob', class {
    constructor(parts?: BlobPart[]) {
      captured = (parts?.[0] as string) ?? '';
      return new OrigBlob(parts);
    }
  });
  fn();
  vi.unstubAllGlobals();
  return captured;
}

describe('exportToCSV', () => {
  beforeEach(() => vi.restoreAllMocks());

  it('triggers a download (anchor click)', () => {
    const clickSpy = vi.fn();
    vi.spyOn(document, 'createElement').mockImplementation((tag: string) => {
      if (tag === 'a') {
        const el = document.createElementNS('http://www.w3.org/1999/xhtml', 'a') as HTMLAnchorElement;
        Object.defineProperty(el, 'click', { value: clickSpy });
        return el;
      }
      return document.createElement(tag);
    });
    exportToCSV([makeTransaction()], categories);
    expect(clickSpy).toHaveBeenCalled();
  });

  it('includes CSV headers', () => {
    const csv = captureBlobContent(() => exportToCSV([makeTransaction()], categories));
    expect(csv).toContain('Date');
    expect(csv).toContain('Amount');
    expect(csv).toContain('Category');
  });

  it('includes transaction data in CSV rows', () => {
    const csv = captureBlobContent(() => exportToCSV([makeTransaction()], categories));
    expect(csv).toContain('Food & Dining');
    expect(csv).toContain('42.50');
    expect(csv).toContain('Lunch');
  });

  it('marks recurring transactions in CSV', () => {
    const csv = captureBlobContent(() =>
      exportToCSV([makeTransaction({ isRecurring: true, recurringFrequency: 'monthly' })], categories)
    );
    expect(csv).toContain('monthly');
  });

  it('marks non-recurring as "no"', () => {
    const csv = captureBlobContent(() => exportToCSV([makeTransaction({ isRecurring: false })], categories));
    expect(csv).toContain('"no"');
  });

  it('handles missing merchant and notes with empty strings', () => {
    const tx = makeTransaction({ merchant: undefined, notes: undefined });
    const csv = captureBlobContent(() => exportToCSV([tx], categories));
    expect(csv).toContain('Lunch');
  });

  it('uses categoryId as fallback when category not in map', () => {
    const tx = makeTransaction({ categoryId: 'unknown-cat' });
    const csv = captureBlobContent(() => exportToCSV([tx], categories));
    expect(csv).toContain('unknown-cat');
  });

  it('marks recurring with "yes" when frequency is not set', () => {
    const csv = captureBlobContent(() =>
      exportToCSV([makeTransaction({ isRecurring: true, recurringFrequency: undefined })], categories)
    );
    expect(csv).toContain('"yes"');
  });
});

describe('exportToJSON', () => {
  beforeEach(() => vi.restoreAllMocks());

  it('triggers a download', () => {
    const clickSpy = vi.fn();
    vi.spyOn(document, 'createElement').mockImplementation((tag: string) => {
      if (tag === 'a') {
        const el = document.createElementNS('http://www.w3.org/1999/xhtml', 'a') as HTMLAnchorElement;
        Object.defineProperty(el, 'click', { value: clickSpy });
        return el;
      }
      return document.createElement(tag);
    });
    exportToJSON({ transactions: [makeTransaction()], budgets: [], settings: DEFAULT_SETTINGS });
    expect(clickSpy).toHaveBeenCalled();
  });

  it('serialises full state as valid JSON', () => {
    const state: AppState = { transactions: [makeTransaction()], budgets: [], settings: DEFAULT_SETTINGS };
    const json = captureBlobContent(() => exportToJSON(state));
    const parsed = JSON.parse(json);
    expect(parsed.transactions).toHaveLength(1);
    expect(parsed.transactions[0].id).toBe('tx1');
  });
});

describe('importFromJSON', () => {
  it('parses a valid JSON backup file', async () => {
    const data = { transactions: [makeTransaction()], budgets: [], settings: DEFAULT_SETTINGS };
    const file = new File([JSON.stringify(data)], 'backup.json', { type: 'application/json' });
    const result = await importFromJSON(file);
    expect(result.transactions).toHaveLength(1);
  });

  it('rejects invalid JSON', async () => {
    const file = new File(['not json {{{'], 'bad.json', { type: 'application/json' });
    await expect(importFromJSON(file)).rejects.toThrow('Invalid JSON file');
  });
});
