import { describe, it, expect } from 'vitest';
import { formatCurrency, getCurrencySymbol, parseMoney } from '../../utils/money';

describe('formatCurrency', () => {
  it('formats USD correctly', () => {
    const result = formatCurrency(1234.56, 'USD');
    expect(result).toContain('1,234.56');
  });

  it('formats EUR correctly', () => {
    const result = formatCurrency(99.99, 'EUR');
    expect(result).toContain('99.99');
  });

  it('formats zero', () => {
    const result = formatCurrency(0, 'USD');
    expect(result).toContain('0');
  });

  it('formats negative amounts', () => {
    const result = formatCurrency(-50, 'USD');
    expect(result).toContain('50');
  });

  it('falls back gracefully for unknown currency code', () => {
    // Unknown 3-letter code might throw in Intl — should fall back
    const result = formatCurrency(100, 'XYZ');
    expect(result).toBeTruthy();
    expect(result).toContain('100');
  });
});

describe('getCurrencySymbol', () => {
  it('returns $ for USD', () => {
    expect(getCurrencySymbol('USD')).toBe('$');
  });

  it('returns € for EUR', () => {
    expect(getCurrencySymbol('EUR')).toBe('€');
  });

  it('returns £ for GBP', () => {
    expect(getCurrencySymbol('GBP')).toBe('£');
  });

  it('falls back to the code for unknown currency', () => {
    expect(getCurrencySymbol('ZZZ')).toBe('ZZZ');
  });
});

describe('parseMoney', () => {
  it('parses a plain number string', () => {
    expect(parseMoney('42.50')).toBe(42.5);
  });

  it('parses a string with currency symbol', () => {
    expect(parseMoney('$1,234.56')).toBe(1234.56);
  });

  it('handles comma as decimal separator', () => {
    expect(parseMoney('1234,56')).toBe(1234.56);
  });

  it('returns 0 for empty string', () => {
    expect(parseMoney('')).toBe(0);
  });

  it('returns 0 for non-numeric string', () => {
    expect(parseMoney('abc')).toBe(0);
  });

  it('parses negative values', () => {
    expect(parseMoney('-50.00')).toBe(-50);
  });
});
