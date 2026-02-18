import { describe, it, expect } from 'vitest';
import { getMonthStats, getCategoryStats, getDailyTotals, getSpendingTrend, predictNextMonth } from '../../utils/stats';
import type { Transaction, MonthStats } from '../../types';

const makeTx = (overrides: Partial<Transaction> = {}): Transaction => ({
  id: 'tx1',
  type: 'expense',
  amount: 100,
  currency: 'USD',
  categoryId: 'food',
  description: 'Lunch',
  date: '2024-01-15',
  tags: [],
  isRecurring: false,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  ...overrides,
});

describe('getMonthStats', () => {
  const txs: Transaction[] = [
    makeTx({ id: '1', type: 'expense', amount: 200, date: '2024-01-10' }),
    makeTx({ id: '2', type: 'income',  amount: 500, date: '2024-01-20' }),
    makeTx({ id: '3', type: 'expense', amount: 100, date: '2024-02-05' }),
  ];

  it('calculates correct income, expenses, and net for a month', () => {
    const [jan] = getMonthStats(txs, ['2024-01']);
    expect(jan.income).toBe(500);
    expect(jan.expenses).toBe(200);
    expect(jan.net).toBe(300);
  });

  it('returns zeros for months with no transactions', () => {
    const [mar] = getMonthStats(txs, ['2024-03']);
    expect(mar.income).toBe(0);
    expect(mar.expenses).toBe(0);
    expect(mar.net).toBe(0);
  });

  it('returns correct number of entries', () => {
    const result = getMonthStats(txs, ['2024-01', '2024-02', '2024-03']);
    expect(result).toHaveLength(3);
  });

  it('handles empty transaction list', () => {
    const [jan] = getMonthStats([], ['2024-01']);
    expect(jan.income).toBe(0);
    expect(jan.expenses).toBe(0);
  });
});

describe('getCategoryStats', () => {
  const txs: Transaction[] = [
    makeTx({ id: '1', categoryId: 'food',      amount: 300 }),
    makeTx({ id: '2', categoryId: 'food',      amount: 100 }),
    makeTx({ id: '3', categoryId: 'transport', amount: 200 }),
  ];

  it('sums amounts by category', () => {
    const stats = getCategoryStats(txs);
    const food = stats.find(s => s.categoryId === 'food')!;
    expect(food.total).toBe(400);
    expect(food.count).toBe(2);
  });

  it('calculates correct percentages', () => {
    const stats = getCategoryStats(txs);
    const food = stats.find(s => s.categoryId === 'food')!;
    // 400/600 ≈ 66.67%
    expect(food.percentage).toBeCloseTo(66.67, 1);
  });

  it('sorts by total descending', () => {
    const stats = getCategoryStats(txs);
    expect(stats[0].categoryId).toBe('food');
    expect(stats[1].categoryId).toBe('transport');
  });

  it('returns empty array for empty input', () => {
    expect(getCategoryStats([])).toEqual([]);
  });

  it('percentage is 0 when total is 0', () => {
    const stats = getCategoryStats([makeTx({ amount: 0 })]);
    expect(stats[0].percentage).toBe(0);
  });
});

describe('getDailyTotals', () => {
  it('sums amounts per day', () => {
    const txs: Transaction[] = [
      makeTx({ id: '1', date: '2024-01-10', amount: 50 }),
      makeTx({ id: '2', date: '2024-01-10', amount: 30 }),
      makeTx({ id: '3', date: '2024-01-11', amount: 20 }),
    ];
    const totals = getDailyTotals(txs);
    expect(totals['2024-01-10']).toBe(80);
    expect(totals['2024-01-11']).toBe(20);
  });

  it('returns empty object for empty input', () => {
    expect(getDailyTotals([])).toEqual({});
  });
});

describe('getSpendingTrend', () => {
  it('returns positive trend when spending increased', () => {
    const stats: MonthStats[] = [
      { month: '2024-01', income: 0, expenses: 100, net: -100 },
      { month: '2024-02', income: 0, expenses: 150, net: -150 },
    ];
    expect(getSpendingTrend(stats)).toBe(50);
  });

  it('returns negative trend when spending decreased', () => {
    const stats: MonthStats[] = [
      { month: '2024-01', income: 0, expenses: 200, net: -200 },
      { month: '2024-02', income: 0, expenses: 100, net: -100 },
    ];
    expect(getSpendingTrend(stats)).toBe(-50);
  });

  it('returns 0 when previous month had 0 expenses', () => {
    const stats: MonthStats[] = [
      { month: '2024-01', income: 0, expenses: 0, net: 0 },
      { month: '2024-02', income: 0, expenses: 100, net: -100 },
    ];
    expect(getSpendingTrend(stats)).toBe(0);
  });

  it('returns 0 for fewer than 2 months', () => {
    expect(getSpendingTrend([{ month: '2024-01', income: 0, expenses: 100, net: -100 }])).toBe(0);
    expect(getSpendingTrend([])).toBe(0);
  });
});

describe('predictNextMonth', () => {
  it('returns 0 for empty input', () => {
    expect(predictNextMonth([])).toBe(0);
  });

  it('returns the single value if only one data point', () => {
    const stats: MonthStats[] = [
      { month: '2024-01', income: 0, expenses: 400, net: -400 },
    ];
    expect(predictNextMonth(stats)).toBe(400);
  });

  it('returns weighted average favouring recent months', () => {
    const stats: MonthStats[] = [
      { month: '2024-01', income: 0, expenses: 100, net: -100 },
      { month: '2024-02', income: 0, expenses: 200, net: -200 },
    ];
    // weight: month1=1, month2=2; total_weight=3; weighted_sum = 100 + 400 = 500; avg = 500/3 ≈ 166.67
    const prediction = predictNextMonth(stats);
    expect(prediction).toBeCloseTo(500 / 3, 1);
  });

  it('ignores months with zero expenses in weighting', () => {
    const stats: MonthStats[] = [
      { month: '2024-01', income: 0, expenses: 0, net: 0 },
      { month: '2024-02', income: 0, expenses: 300, net: -300 },
    ];
    // Only non-zero: [300]; single element → 300
    expect(predictNextMonth(stats)).toBe(300);
  });
});
