import { describe, it, expect, beforeEach } from 'vitest';
import { loadState, saveState } from '../../store/storage';
import { DEFAULT_SETTINGS } from '../../store/defaults';
import type { AppState } from '../../types';

const emptyState: AppState = { transactions: [], budgets: [], settings: DEFAULT_SETTINGS };

describe('loadState', () => {
  beforeEach(() => localStorage.clear());

  it('returns default empty state when localStorage is empty', () => {
    const state = loadState();
    expect(state.transactions).toEqual([]);
    expect(state.budgets).toEqual([]);
    expect(state.settings.currency).toBe('USD');
  });

  it('returns saved state from localStorage', () => {
    const saved: AppState = {
      ...emptyState,
      transactions: [{
        id: 'tx-1', type: 'expense', amount: 50, currency: 'USD',
        categoryId: 'food', description: 'Burger', date: '2024-01-01',
        tags: [], isRecurring: false,
        createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z',
      }],
    };
    localStorage.setItem('expense_tracker_v1', JSON.stringify(saved));

    const state = loadState();
    expect(state.transactions).toHaveLength(1);
    expect(state.transactions[0].id).toBe('tx-1');
  });

  it('merges missing settings keys with defaults', () => {
    localStorage.setItem('expense_tracker_v1', JSON.stringify({ settings: { currency: 'EUR' } }));
    const state = loadState();
    expect(state.settings.currency).toBe('EUR');
    expect(state.settings.darkMode).toBe(false); // default filled in
  });

  it('returns defaults on corrupted JSON', () => {
    localStorage.setItem('expense_tracker_v1', '{ not valid json ');
    const state = loadState();
    expect(state.transactions).toEqual([]);
  });
});

describe('saveState', () => {
  it('saves state to localStorage', () => {
    saveState(emptyState);
    const raw = localStorage.getItem('expense_tracker_v1');
    expect(raw).toBeTruthy();
    const parsed = JSON.parse(raw!);
    expect(parsed.transactions).toEqual([]);
  });

  it('round-trips state correctly', () => {
    const state: AppState = {
      ...emptyState,
      transactions: [{
        id: 'tx-2', type: 'income', amount: 1000, currency: 'USD',
        categoryId: 'salary', description: 'Paycheck', date: '2024-01-31',
        tags: ['monthly'], isRecurring: true, recurringFrequency: 'monthly',
        createdAt: '2024-01-31T00:00:00Z', updatedAt: '2024-01-31T00:00:00Z',
      }],
    };
    saveState(state);
    const loaded = loadState();
    expect(loaded.transactions[0].id).toBe('tx-2');
    expect(loaded.transactions[0].recurringFrequency).toBe('monthly');
  });
});
