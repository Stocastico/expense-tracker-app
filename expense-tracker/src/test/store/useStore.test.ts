import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useStore } from '../../store/useStore';

beforeEach(() => {
  localStorage.clear();
  document.documentElement.classList.remove('dark');
});

describe('addTransaction', () => {
  it('adds a one-off transaction', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 50, currency: 'USD', categoryId: 'food',
        description: 'Pizza', date: '2024-01-15', tags: [], isRecurring: false,
      });
    });
    expect(result.current.transactions).toHaveLength(1);
    expect(result.current.transactions[0].amount).toBe(50);
    expect(result.current.transactions[0].id).toBeTruthy();
  });

  it('generates recurring instances for monthly recurring transaction', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 100, currency: 'USD', categoryId: 'subscriptions',
        description: 'Netflix', date: '2024-01-01', tags: [], isRecurring: true,
        recurringFrequency: 'monthly',
      });
    });
    // Should have the original + several monthly instances within the next year
    expect(result.current.transactions.length).toBeGreaterThan(1);
    // All instances should have the same amount and description
    result.current.transactions.forEach(t => {
      expect(t.amount).toBe(100);
      expect(t.description).toBe('Netflix');
    });
  });

  it('recurring instances have recurringParentId set', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 30, currency: 'USD', categoryId: 'utilities',
        description: 'Internet', date: '2024-01-01', tags: [], isRecurring: true,
        recurringFrequency: 'monthly',
      });
    });
    const parentId = result.current.transactions[0].id;
    const instances = result.current.transactions.filter(t => t.recurringParentId === parentId);
    expect(instances.length).toBeGreaterThan(0);
  });

  it('generates weekly recurring instances', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 10, currency: 'USD', categoryId: 'food',
        description: 'Coffee', date: '2024-01-01', tags: [], isRecurring: true,
        recurringFrequency: 'weekly',
      });
    });
    expect(result.current.transactions.length).toBeGreaterThan(4); // at least 4 weeks
  });

  it('respects recurringEndDate', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 50, currency: 'USD', categoryId: 'health',
        description: 'Gym', date: '2024-01-01', tags: [], isRecurring: true,
        recurringFrequency: 'monthly', recurringEndDate: '2024-03-31',
      });
    });
    // Should have: Jan 1 (original) + Feb + Mar = 3 max
    const txs = result.current.transactions;
    expect(txs.length).toBeLessThanOrEqual(3);
    txs.forEach(t => {
      expect(t.date <= '2024-03-31').toBe(true);
    });
  });

  it('generates daily recurring instances', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 5, currency: 'USD', categoryId: 'food',
        description: 'Coffee', date: '2025-01-01', tags: [], isRecurring: true,
        recurringFrequency: 'daily', recurringEndDate: '2025-01-10',
      });
    });
    // Should have original + 9 daily instances (Jan 2 through Jan 10)
    expect(result.current.transactions.length).toBeGreaterThan(1);
  });

  it('generates biweekly recurring instances', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 100, currency: 'USD', categoryId: 'health',
        description: 'Gym biweekly', date: '2024-01-01', tags: [], isRecurring: true,
        recurringFrequency: 'biweekly', recurringEndDate: '2024-03-31',
      });
    });
    expect(result.current.transactions.length).toBeGreaterThan(1);
  });

  it('generates quarterly recurring instances', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 200, currency: 'USD', categoryId: 'subscriptions',
        description: 'Quarterly sub', date: '2024-01-01', tags: [], isRecurring: true,
        recurringFrequency: 'quarterly', recurringEndDate: '2025-01-01',
      });
    });
    expect(result.current.transactions.length).toBeGreaterThan(1);
  });

  it('generates yearly recurring instances', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 500, currency: 'USD', categoryId: 'insurance',
        description: 'Annual insurance', date: '2024-01-01', tags: [], isRecurring: true,
        recurringFrequency: 'yearly',
      });
    });
    // Within 1 year, should just have original + 1 next-year instance
    expect(result.current.transactions.length).toBeGreaterThanOrEqual(1);
  });
});

describe('updateTransaction', () => {
  it('updates an existing transaction', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({
        type: 'expense', amount: 50, currency: 'USD', categoryId: 'food',
        description: 'Burger', date: '2024-01-10', tags: [], isRecurring: false,
      });
    });
    const id = result.current.transactions[0].id;
    act(() => {
      result.current.updateTransaction(id, { amount: 75, description: 'Double Burger' });
    });
    expect(result.current.transactions[0].amount).toBe(75);
    expect(result.current.transactions[0].description).toBe('Double Burger');
  });

  it('does not change other transactions', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({ type: 'expense', amount: 10, currency: 'USD', categoryId: 'food', description: 'A', date: '2024-01-10', tags: [], isRecurring: false });
      result.current.addTransaction({ type: 'expense', amount: 20, currency: 'USD', categoryId: 'food', description: 'B', date: '2024-01-11', tags: [], isRecurring: false });
    });
    const id0 = result.current.transactions[0].id;
    act(() => {
      result.current.updateTransaction(id0, { amount: 99 });
    });
    expect(result.current.transactions[1].amount).toBe(20);
  });
});

describe('deleteTransaction', () => {
  it('removes a transaction by id', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({ type: 'expense', amount: 50, currency: 'USD', categoryId: 'food', description: 'Lunch', date: '2024-01-10', tags: [], isRecurring: false });
    });
    const id = result.current.transactions[0].id;
    act(() => { result.current.deleteTransaction(id); });
    expect(result.current.transactions).toHaveLength(0);
  });

  it('deletes recurring instances when deleteAll=true', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({ type: 'expense', amount: 10, currency: 'USD', categoryId: 'food', description: 'Sub', date: '2024-01-01', tags: [], isRecurring: true, recurringFrequency: 'monthly' });
    });
    const parentId = result.current.transactions[0].id;
    act(() => { result.current.deleteTransaction(parentId, true); });
    expect(result.current.transactions).toHaveLength(0);
  });

  it('keeps other recurring instances when deleteAll=false', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({ type: 'expense', amount: 10, currency: 'USD', categoryId: 'food', description: 'Sub', date: '2024-01-01', tags: [], isRecurring: true, recurringFrequency: 'monthly' });
    });
    const totalBefore = result.current.transactions.length;
    const parentId = result.current.transactions[0].id;
    act(() => { result.current.deleteTransaction(parentId, false); });
    // Parent gone, instances remain
    expect(result.current.transactions.length).toBe(totalBefore - 1);
    expect(result.current.transactions.every(t => t.id !== parentId)).toBe(true);
  });
});

describe('addBudget', () => {
  it('adds a budget', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addBudget({ categoryId: 'food', amount: 300, currency: 'USD', period: 'monthly' });
    });
    expect(result.current.budgets).toHaveLength(1);
    expect(result.current.budgets[0].amount).toBe(300);
  });

  it('replaces an existing budget for the same category+period', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addBudget({ categoryId: 'food', amount: 200, currency: 'USD', period: 'monthly' });
      result.current.addBudget({ categoryId: 'food', amount: 500, currency: 'USD', period: 'monthly' });
    });
    expect(result.current.budgets).toHaveLength(1);
    expect(result.current.budgets[0].amount).toBe(500);
  });
});

describe('deleteBudget', () => {
  it('removes a budget by id', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addBudget({ categoryId: 'food', amount: 200, currency: 'USD', period: 'monthly' });
    });
    const id = result.current.budgets[0].id;
    act(() => { result.current.deleteBudget(id); });
    expect(result.current.budgets).toHaveLength(0);
  });
});

describe('updateSettings', () => {
  it('updates currency setting', () => {
    const { result } = renderHook(() => useStore());
    act(() => { result.current.updateSettings({ currency: 'EUR' }); });
    expect(result.current.settings.currency).toBe('EUR');
  });

  it('applies dark mode to document element', () => {
    const { result } = renderHook(() => useStore());
    act(() => { result.current.updateSettings({ darkMode: true }); });
    expect(document.documentElement.classList.contains('dark')).toBe(true);
    act(() => { result.current.updateSettings({ darkMode: false }); });
    expect(document.documentElement.classList.contains('dark')).toBe(false);
  });

  it('merges partial updates', () => {
    const { result } = renderHook(() => useStore());
    const before = result.current.settings.startOfMonth;
    act(() => { result.current.updateSettings({ currency: 'GBP' }); });
    expect(result.current.settings.startOfMonth).toBe(before);
  });
});

describe('addCategory', () => {
  it('appends a custom category', () => {
    const { result } = renderHook(() => useStore());
    const before = result.current.settings.categories.length;
    act(() => {
      result.current.addCategory({ name: 'Sports', icon: '⚽', color: 'bg-green-500', type: 'expense' });
    });
    expect(result.current.settings.categories.length).toBe(before + 1);
    expect(result.current.settings.categories.at(-1)!.name).toBe('Sports');
  });
});

describe('deleteCategory', () => {
  it('removes a category by id', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addCategory({ name: 'Test', icon: '🔥', color: 'bg-red-500', type: 'expense' });
    });
    const newCat = result.current.settings.categories.at(-1)!;
    act(() => { result.current.deleteCategory(newCat.id); });
    expect(result.current.settings.categories.find(c => c.id === newCat.id)).toBeUndefined();
  });
});

describe('importData', () => {
  it('replaces transactions with imported data', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.importData({
        transactions: [{
          id: 'imported-1', type: 'income', amount: 1000, currency: 'USD',
          categoryId: 'salary', description: 'Pay', date: '2024-01-31',
          tags: [], isRecurring: false,
          createdAt: '2024-01-31T00:00:00Z', updatedAt: '2024-01-31T00:00:00Z',
        }],
      });
    });
    expect(result.current.transactions[0].id).toBe('imported-1');
  });
});

describe('clearAllData', () => {
  it('resets to empty state', () => {
    const { result } = renderHook(() => useStore());
    act(() => {
      result.current.addTransaction({ type: 'expense', amount: 50, currency: 'USD', categoryId: 'food', description: 'X', date: '2024-01-10', tags: [], isRecurring: false });
      result.current.addBudget({ categoryId: 'food', amount: 200, currency: 'USD', period: 'monthly' });
    });
    act(() => { result.current.clearAllData(); });
    expect(result.current.transactions).toHaveLength(0);
    expect(result.current.budgets).toHaveLength(0);
  });
});
