import { useState, useCallback, useEffect } from 'react';
import { v4 as uuidv4 } from 'uuid';
import type { Transaction, Budget, AppSettings, AppState, Category } from '../types';
import { loadState, saveState } from './storage';
import { DEFAULT_SETTINGS } from './defaults';
import { addDays, addWeeks, addMonths, addQuarters, addYears, isBefore, parseISO } from 'date-fns';

function generateRecurringInstances(template: Transaction): Transaction[] {
  if (!template.isRecurring || !template.recurringFrequency) return [];
  const instances: Transaction[] = [];
  const today = new Date();
  let current = parseISO(template.date);
  const endDate = template.recurringEndDate ? parseISO(template.recurringEndDate) : addYears(today, 1);

  const advance = (d: Date) => {
    switch (template.recurringFrequency) {
      case 'daily':     return addDays(d, 1);
      case 'weekly':    return addWeeks(d, 1);
      case 'biweekly':  return addWeeks(d, 2);
      case 'monthly':   return addMonths(d, 1);
      case 'quarterly': return addQuarters(d, 1);
      case 'yearly':    return addYears(d, 1);
      default:          return addMonths(d, 1);
    }
  };

  current = advance(current); // skip original
  while (isBefore(current, endDate) && isBefore(current, addYears(today, 1))) {
    instances.push({
      ...template,
      id: uuidv4(),
      date: current.toISOString().split('T')[0],
      recurringParentId: template.id,
      isRecurring: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
    current = advance(current);
  }
  return instances;
}

export function useStore() {
  const [state, setState] = useState<AppState>(() => loadState());

  useEffect(() => {
    saveState(state);
  }, [state]);

  // Apply dark mode
  useEffect(() => {
    document.documentElement.classList.toggle('dark', state.settings.darkMode);
  }, [state.settings.darkMode]);

  const addTransaction = useCallback((tx: Omit<Transaction, 'id' | 'createdAt' | 'updatedAt'>) => {
    const now = new Date().toISOString();
    const newTx: Transaction = { ...tx, id: uuidv4(), createdAt: now, updatedAt: now };
    const instances = newTx.isRecurring ? generateRecurringInstances(newTx) : [];
    setState(s => ({ ...s, transactions: [...s.transactions, newTx, ...instances] }));
  }, []);

  const updateTransaction = useCallback((id: string, updates: Partial<Transaction>) => {
    setState(s => ({
      ...s,
      transactions: s.transactions.map(t =>
        t.id === id ? { ...t, ...updates, updatedAt: new Date().toISOString() } : t
      ),
    }));
  }, []);

  const deleteTransaction = useCallback((id: string, deleteAll = false) => {
    setState(s => ({
      ...s,
      transactions: s.transactions.filter(t => {
        if (t.id === id) return false;
        if (deleteAll && t.recurringParentId === id) return false;
        return true;
      }),
    }));
  }, []);

  const addBudget = useCallback((b: Omit<Budget, 'id' | 'createdAt' | 'updatedAt'>) => {
    const now = new Date().toISOString();
    const newB: Budget = { ...b, id: uuidv4(), createdAt: now, updatedAt: now };
    setState(s => ({
      ...s,
      budgets: [...s.budgets.filter(x => x.categoryId !== b.categoryId || x.period !== b.period), newB],
    }));
  }, []);

  const deleteBudget = useCallback((id: string) => {
    setState(s => ({ ...s, budgets: s.budgets.filter(b => b.id !== id) }));
  }, []);

  const updateSettings = useCallback((updates: Partial<AppSettings>) => {
    setState(s => ({ ...s, settings: { ...s.settings, ...updates } }));
  }, []);

  const addCategory = useCallback((cat: Omit<Category, 'id'>) => {
    const newCat: Category = { ...cat, id: uuidv4() };
    setState(s => ({ ...s, settings: { ...s.settings, categories: [...s.settings.categories, newCat] } }));
  }, []);

  const deleteCategory = useCallback((id: string) => {
    setState(s => ({
      ...s,
      settings: { ...s.settings, categories: s.settings.categories.filter(c => c.id !== id) },
    }));
  }, []);

  const importData = useCallback((imported: Partial<AppState>) => {
    setState(s => ({
      transactions: imported.transactions ?? s.transactions,
      budgets: imported.budgets ?? s.budgets,
      settings: imported.settings ? { ...DEFAULT_SETTINGS, ...imported.settings } : s.settings,
    }));
  }, []);

  const clearAllData = useCallback(() => {
    setState({ transactions: [], budgets: [], settings: DEFAULT_SETTINGS });
  }, []);

  return {
    ...state,
    addTransaction,
    updateTransaction,
    deleteTransaction,
    addBudget,
    deleteBudget,
    updateSettings,
    addCategory,
    deleteCategory,
    importData,
    clearAllData,
  };
}

export type Store = ReturnType<typeof useStore>;
