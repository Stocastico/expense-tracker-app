import type { Transaction, CategoryStats, MonthStats } from '../types';
import { monthKey } from './dates';

export function getMonthStats(transactions: Transaction[], months: string[]): MonthStats[] {
  return months.map(month => {
    const txs = transactions.filter(t => monthKey(t.date) === month);
    const income = txs.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0);
    const expenses = txs.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0);
    return { month, income, expenses, net: income - expenses };
  });
}

export function getCategoryStats(transactions: Transaction[]): CategoryStats[] {
  const map = new Map<string, { total: number; count: number }>();
  const total = transactions.reduce((s, t) => s + t.amount, 0);
  for (const tx of transactions) {
    const existing = map.get(tx.categoryId) ?? { total: 0, count: 0 };
    map.set(tx.categoryId, { total: existing.total + tx.amount, count: existing.count + 1 });
  }
  return Array.from(map.entries()).map(([categoryId, { total: catTotal, count }]) => ({
    categoryId,
    total: catTotal,
    count,
    percentage: total > 0 ? (catTotal / total) * 100 : 0,
  })).sort((a, b) => b.total - a.total);
}

export function getDailyTotals(transactions: Transaction[]): Record<string, number> {
  const result: Record<string, number> = {};
  for (const tx of transactions) {
    result[tx.date] = (result[tx.date] ?? 0) + tx.amount;
  }
  return result;
}

export function getSpendingTrend(monthStats: MonthStats[]): number {
  if (monthStats.length < 2) return 0;
  const last = monthStats[monthStats.length - 1].expenses;
  const prev = monthStats[monthStats.length - 2].expenses;
  if (prev === 0) return 0;
  return ((last - prev) / prev) * 100;
}

export function predictNextMonth(monthStats: MonthStats[]): number {
  const expenses = monthStats.map(m => m.expenses).filter(e => e > 0);
  if (expenses.length === 0) return 0;
  if (expenses.length === 1) return expenses[0];
  // Simple weighted average: more recent months weigh more
  let totalWeight = 0;
  let weightedSum = 0;
  expenses.forEach((e, i) => {
    const weight = i + 1;
    weightedSum += e * weight;
    totalWeight += weight;
  });
  return weightedSum / totalWeight;
}
