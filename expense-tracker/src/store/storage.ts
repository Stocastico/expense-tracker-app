import type { AppState } from '../types';
import { DEFAULT_SETTINGS } from './defaults';

const STORAGE_KEY = 'expense_tracker_v1';

export function loadState(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { transactions: [], budgets: [], settings: DEFAULT_SETTINGS };
    const parsed = JSON.parse(raw) as Partial<AppState>;
    return {
      transactions: parsed.transactions ?? [],
      budgets: parsed.budgets ?? [],
      settings: { ...DEFAULT_SETTINGS, ...parsed.settings },
    };
  } catch {
    return { transactions: [], budgets: [], settings: DEFAULT_SETTINGS };
  }
}

export function saveState(state: AppState): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // Storage might be full; fail silently
  }
}
