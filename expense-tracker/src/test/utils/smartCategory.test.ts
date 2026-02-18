import { describe, it, expect } from 'vitest';
import { guessCategory, extractOcrData } from '../../utils/smartCategory';
import { DEFAULT_CATEGORIES } from '../../store/defaults';

describe('guessCategory', () => {
  it('guesses food from "restaurant" keyword', () => {
    expect(guessCategory('restaurant bill', DEFAULT_CATEGORIES, 'expense')).toBe('food');
  });

  it('guesses transport from "uber" keyword', () => {
    expect(guessCategory('Uber ride home', DEFAULT_CATEGORIES, 'expense')).toBe('transport');
  });

  it('guesses groceries from "walmart" keyword', () => {
    expect(guessCategory('walmart groceries', DEFAULT_CATEGORIES, 'expense')).toBe('groceries');
  });

  it('guesses subscriptions from "netflix" keyword', () => {
    expect(guessCategory('Netflix subscription', DEFAULT_CATEGORIES, 'expense')).toBe('subscriptions');
  });

  it('falls back to other_exp for unrecognised expense', () => {
    expect(guessCategory('mystery purchase xyzabc', DEFAULT_CATEGORIES, 'expense')).toBe('other_exp');
  });

  it('falls back to other_inc for unrecognised income', () => {
    expect(guessCategory('random income source', DEFAULT_CATEGORIES, 'income')).toBe('other_inc');
  });

  it('is case-insensitive', () => {
    expect(guessCategory('CAFE COFFEE', DEFAULT_CATEGORIES, 'expense')).toBe('food');
  });
});

describe('extractOcrData', () => {
  it('extracts an amount from a total line', () => {
    const result = extractOcrData('Total: $42.50\nDate: 01/15/2024');
    expect(result.amount).toBe(42.50);
  });

  it('extracts amount from plain number when no label', () => {
    const result = extractOcrData('Some item 12.99\nAnother 5.00');
    expect(result.amount).toBeGreaterThan(0);
  });

  it('extracts a date in DD/MM/YY format', () => {
    const result = extractOcrData('15/01/24\nMerchant name\nTotal 20.00');
    expect(result.date).toBeTruthy();
  });

  it('extracts merchant from first meaningful line', () => {
    const result = extractOcrData('Starbucks Coffee\nDate 2024-03-01\nTotal 5.50');
    expect(result.merchant).toBe('Starbucks Coffee');
  });

  it('provides a category hint for known keywords', () => {
    const result = extractOcrData('Uber Technologies Inc\nTotal $18.00');
    expect(result.categoryHint).toBe('uber');
  });

  it('handles empty text gracefully', () => {
    const result = extractOcrData('');
    expect(result.amount).toBeUndefined();
    expect(result.merchant).toBeUndefined();
    expect(result.date).toBeUndefined();
  });

  it('picks the largest number as the total amount', () => {
    // Receipt with item subtotals and a final total
    const result = extractOcrData('Item 1 5.00\nItem 2 3.50\nTotal 8.50');
    expect(result.amount).toBe(8.50);
  });
});
