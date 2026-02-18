import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { today, formatDate, monthKey, monthLabel, isInMonth, lastNMonths } from '../../utils/dates';

describe('today', () => {
  it('returns a date in YYYY-MM-DD format', () => {
    const result = today();
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('returns the current date', () => {
    const now = new Date();
    const expected = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    expect(today()).toBe(expected);
  });
});

describe('formatDate', () => {
  it('formats with default format', () => {
    expect(formatDate('2024-01-15')).toBe('Jan 15, 2024');
  });

  it('formats with custom format', () => {
    expect(formatDate('2024-06-01', 'yyyy-MM-dd')).toBe('2024-06-01');
  });

  it('formats with MMM d format', () => {
    expect(formatDate('2024-12-25', 'MMM d')).toBe('Dec 25');
  });

  it('returns the original string on invalid date', () => {
    expect(formatDate('not-a-date')).toBe('not-a-date');
  });
});

describe('monthKey', () => {
  it('returns YYYY-MM from a full date string', () => {
    expect(monthKey('2024-03-15')).toBe('2024-03');
  });

  it('returns empty string for invalid date', () => {
    expect(monthKey('invalid')).toBe('');
  });
});

describe('monthLabel', () => {
  it('returns human-readable month from key', () => {
    expect(monthLabel('2024-01')).toBe('Jan 2024');
  });

  it('returns key on invalid input', () => {
    expect(monthLabel('bad')).toBe('bad');
  });
});

describe('isInMonth', () => {
  it('returns true when date is in the given month', () => {
    expect(isInMonth('2024-03-15', 2024, 2)).toBe(true);
  });

  it('returns false when date is in a different month', () => {
    expect(isInMonth('2024-04-01', 2024, 2)).toBe(false);
  });

  it('returns false for invalid date string', () => {
    expect(isInMonth('invalid', 2024, 2)).toBe(false);
  });
});

describe('lastNMonths', () => {
  it('returns an array of N month keys', () => {
    const result = lastNMonths(3);
    expect(result).toHaveLength(3);
    result.forEach(m => expect(m).toMatch(/^\d{4}-\d{2}$/));
  });

  it('last element is the current month', () => {
    const result = lastNMonths(6);
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    expect(result[result.length - 1]).toBe(currentMonth);
  });

  it('array is in chronological order', () => {
    const result = lastNMonths(4);
    for (let i = 1; i < result.length; i++) {
      expect(result[i] > result[i - 1]).toBe(true);
    }
  });

  it('returns single element for n=1', () => {
    expect(lastNMonths(1)).toHaveLength(1);
  });
});
