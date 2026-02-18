import { MERCHANT_KEYWORDS } from '../store/defaults';
import type { Category } from '../types';

export function guessCategory(
  text: string,
  categories: Category[],
  type: 'expense' | 'income'
): string {
  const lower = text.toLowerCase();
  for (const [keyword, catId] of Object.entries(MERCHANT_KEYWORDS)) {
    if (lower.includes(keyword)) {
      const cat = categories.find(c => c.id === catId);
      if (cat && (cat.type === type || cat.type === 'both')) return catId;
    }
  }
  // Default fallback
  const defaults: Record<string, string> = { expense: 'other_exp', income: 'other_inc' };
  return defaults[type] ?? categories.find(c => c.type === type || c.type === 'both')?.id ?? '';
}

export function extractOcrData(text: string): {
  amount?: number;
  merchant?: string;
  date?: string;
  categoryHint?: string;
} {
  const result: { amount?: number; merchant?: string; date?: string; categoryHint?: string } = {};

  // Amount: look for currency patterns
  const amountMatches = text.match(/(?:total|amount|sum|€|\$|£|¥|due|pay)[:\s]*([0-9]+[.,][0-9]{2})/i)
    ?? text.match(/([0-9]+[.,][0-9]{2})/g);
  if (amountMatches) {
    const nums = (Array.isArray(amountMatches) ? amountMatches : [amountMatches[1]])
      .map(m => parseFloat(m.replace(',', '.')))
      .filter(n => n > 0);
    // Take the largest number as it's likely the total
    if (nums.length > 0) result.amount = Math.max(...nums);
  }

  // Date: various formats
  const dateMatch = text.match(
    /\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b/
    ) ?? text.match(/\b(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})\b/);
  if (dateMatch) {
    try {
      const [, a, b, c] = dateMatch;
      const year = c.length === 4 ? c : `20${c}`;
      const isoDate = `${year}-${b.padStart(2, '0')}-${a.padStart(2, '0')}`;
      const d = new Date(isoDate);
      if (!isNaN(d.getTime())) result.date = isoDate;
    } catch { /* ignore */ }
  }

  // Merchant: first meaningful line
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 2 && !/^[0-9\s]+$/.test(l));
  if (lines.length > 0) result.merchant = lines[0].substring(0, 50);

  // Category hint from full text
  const lower = text.toLowerCase();
  for (const [keyword] of Object.entries(MERCHANT_KEYWORDS)) {
    if (lower.includes(keyword)) { result.categoryHint = keyword; break; }
  }

  return result;
}
