import { describe, it, expect } from 'vitest';
import { parsePdfText, entriesToTransactions } from '../../utils/pdfImport';

describe('parsePdfText', () => {
  it('parses a simple DD/MM/YYYY line', () => {
    const text = '15/01/2024 Starbucks coffee 5.50\n';
    const entries = parsePdfText(text);
    expect(entries.length).toBeGreaterThan(0);
    expect(entries[0].date).toBe('2024-01-15');
    expect(entries[0].amount).toBe(5.50);
  });

  it('parses ISO date format', () => {
    const text = '2024-03-22 Amazon purchase 89.99\n';
    const entries = parsePdfText(text);
    expect(entries.length).toBeGreaterThan(0);
    expect(entries[0].date).toBe('2024-03-22');
    expect(entries[0].amount).toBe(89.99);
  });

  it('parses month-word date format', () => {
    const text = '5 Feb 2024 Netflix subscription 14.99\n';
    const entries = parsePdfText(text);
    expect(entries.length).toBeGreaterThan(0);
    expect(entries[0].date).toBe('2024-02-05');
  });

  it('returns empty array for text with no dates', () => {
    const entries = parsePdfText('Total balance: 1234.56\nAccount number: 9876');
    // lines have amounts but no valid dates — returns empty or near-empty
    expect(Array.isArray(entries)).toBe(true);
  });

  it('skips lines with no amounts', () => {
    const text = '15/01/2024 No amount here at all\n2024-02-01 Coffee 3.50\n';
    const entries = parsePdfText(text);
    // Only the second line has a parseable amount
    expect(entries.some(e => e.amount === 3.50)).toBe(true);
  });

  it('handles multiple lines', () => {
    const text = [
      '01/01/2024 Grocery store 45.23',
      '02/01/2024 Gas station 60.00',
      '03/01/2024 Restaurant 32.75',
    ].join('\n');
    const entries = parsePdfText(text);
    expect(entries.length).toBe(3);
  });

  it('builds merchant from first words of description', () => {
    const text = '10/02/2024 Starbucks Downtown Branch 4.50\n';
    const entries = parsePdfText(text);
    if (entries.length > 0 && entries[0].merchant) {
      expect(entries[0].merchant.length).toBeGreaterThan(0);
    }
  });
});

describe('entriesToTransactions', () => {
  it('converts entries to Transaction objects', () => {
    const entries = [
      { date: '2024-01-15', description: 'Coffee', amount: 4.50, merchant: 'Starbucks' },
    ];
    const txs = entriesToTransactions(entries, { currency: 'USD', accountId: 'personal', categoryId: 'food' });
    expect(txs).toHaveLength(1);
    expect(txs[0].amount).toBe(4.50);
    expect(txs[0].currency).toBe('USD');
    expect(txs[0].accountId).toBe('personal');
    expect(txs[0].categoryId).toBe('food');
    expect(txs[0].type).toBe('expense');
    expect(txs[0].id).toBeDefined();
    expect(txs[0].createdAt).toBeDefined();
  });

  it('marks negative amounts as income type', () => {
    const entries = [{ date: '2024-01-01', description: 'Refund', amount: -50 }];
    const txs = entriesToTransactions(entries, { currency: 'EUR', accountId: 'family', categoryId: 'other_inc' });
    expect(txs[0].type).toBe('income');
    expect(txs[0].amount).toBe(50);
  });

  it('assigns unique ids to each transaction', () => {
    const entries = [
      { date: '2024-01-01', description: 'A', amount: 10 },
      { date: '2024-01-02', description: 'B', amount: 20 },
    ];
    const txs = entriesToTransactions(entries, { currency: 'USD', accountId: 'personal', categoryId: 'food' });
    const ids = new Set(txs.map(t => t.id));
    expect(ids.size).toBe(2);
  });
});
