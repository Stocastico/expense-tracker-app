import { useState, useCallback, useEffect, useRef } from 'react';
import { v4 as uuidv4 } from 'uuid';
import type { Transaction, Budget, AppSettings, AppState, Category, AccountId } from '../types';
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

  current = advance(current);
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

// ─── Server sync helpers ───────────────────────────────────────────────────

async function apiFetch(path: string, options?: RequestInit) {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) throw new Error(`API ${path} returned ${res.status}`);
  return res.json();
}

// ─── Store ─────────────────────────────────────────────────────────────────

export function useStore() {
  const [state, setState] = useState<AppState>(() => loadState());
  const [serverConnected, setServerConnected] = useState(false);
  const [currentAccount, setCurrentAccount] = useState<AccountId>(
    () => (loadState().settings.defaultAccount ?? 'personal')
  );
  const serverRef = useRef(false);

  // ── Server detection on mount ──────────────────────────────────────────
  useEffect(() => {
    const detect = async () => {
      try {
        await apiFetch('/api/health');
        const [transactions, budgets, settings] = await Promise.all([
          apiFetch('/api/transactions'),
          apiFetch('/api/budgets'),
          apiFetch('/api/settings'),
        ]);
        setState({
          transactions,
          budgets,
          settings: { ...DEFAULT_SETTINGS, ...settings },
        });
        serverRef.current = true;
        setServerConnected(true);
      } catch {
        // Offline / dev mode – keep localStorage
      }
    };
    detect();
  }, []);

  // ── Persist to localStorage when NOT using server ─────────────────────
  useEffect(() => {
    if (!serverRef.current) saveState(state);
  }, [state]);

  // ── Dark mode ─────────────────────────────────────────────────────────
  useEffect(() => {
    document.documentElement.classList.toggle('dark', state.settings.darkMode);
  }, [state.settings.darkMode]);

  // ── Helpers ───────────────────────────────────────────────────────────
  const syncToServer = useCallback(async (endpoint: string, method: string, body?: unknown) => {
    if (!serverRef.current) return;
    try {
      await apiFetch(endpoint, { method, body: body !== undefined ? JSON.stringify(body) : undefined });
    } catch (err) {
      console.warn('Server sync failed:', err);
    }
  }, []);

  // ── Mutations ─────────────────────────────────────────────────────────

  const addTransaction = useCallback((tx: Omit<Transaction, 'id' | 'createdAt' | 'updatedAt'>) => {
    const now = new Date().toISOString();
    const newTx: Transaction = { ...tx, id: uuidv4(), createdAt: now, updatedAt: now };
    const instances = newTx.isRecurring ? generateRecurringInstances(newTx) : [];
    setState(s => ({ ...s, transactions: [...s.transactions, newTx, ...instances] }));
    syncToServer('/api/transactions', 'POST', [newTx, ...instances]);
  }, [syncToServer]);

  const updateTransaction = useCallback((id: string, updates: Partial<Transaction>) => {
    setState(s => ({
      ...s,
      transactions: s.transactions.map(t =>
        t.id === id ? { ...t, ...updates, updatedAt: new Date().toISOString() } : t
      ),
    }));
    syncToServer(`/api/transactions/${id}`, 'PUT', updates);
  }, [syncToServer]);

  const deleteTransaction = useCallback((id: string, deleteAll = false) => {
    setState(s => ({
      ...s,
      transactions: s.transactions.filter(t => {
        if (t.id === id) return false;
        if (deleteAll && t.recurringParentId === id) return false;
        return true;
      }),
    }));
    syncToServer(`/api/transactions/${id}?deleteAll=${deleteAll}`, 'DELETE');
  }, [syncToServer]);

  const addBudget = useCallback((b: Omit<Budget, 'id' | 'createdAt' | 'updatedAt'>) => {
    const now = new Date().toISOString();
    const newB: Budget = { ...b, id: uuidv4(), createdAt: now, updatedAt: now };
    setState(s => ({
      ...s,
      budgets: [...s.budgets.filter(x => x.categoryId !== b.categoryId || x.period !== b.period), newB],
    }));
    syncToServer('/api/budgets', 'POST', newB);
  }, [syncToServer]);

  const deleteBudget = useCallback((id: string) => {
    setState(s => ({ ...s, budgets: s.budgets.filter(b => b.id !== id) }));
    syncToServer(`/api/budgets/${id}`, 'DELETE');
  }, [syncToServer]);

  const updateSettings = useCallback((updates: Partial<AppSettings>) => {
    setState(s => {
      const next = { ...s.settings, ...updates };
      syncToServer('/api/settings', 'PUT', next);
      return { ...s, settings: next };
    });
  }, [syncToServer]);

  const addCategory = useCallback((cat: Omit<Category, 'id'>) => {
    const newCat: Category = { ...cat, id: uuidv4() };
    setState(s => {
      const next = { ...s.settings, categories: [...s.settings.categories, newCat] };
      syncToServer('/api/settings', 'PUT', next);
      return { ...s, settings: next };
    });
  }, [syncToServer]);

  const deleteCategory = useCallback((id: string) => {
    setState(s => {
      const next = { ...s.settings, categories: s.settings.categories.filter(c => c.id !== id) };
      syncToServer('/api/settings', 'PUT', next);
      return { ...s, settings: next };
    });
  }, [syncToServer]);

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

  // Upload pending transactions from the mobile app queue to the server, then
  // merge them into the main state so the dashboard reflects them immediately.
  const uploadPending = useCallback(async (pending: Transaction[]): Promise<{ uploaded: number }> => {
    const res = await apiFetch('/api/sync', { method: 'POST', body: JSON.stringify({ transactions: pending }) });
    setState(s => ({
      ...s,
      transactions: [
        ...s.transactions.filter(t => !pending.find(p => p.id === t.id)),
        ...pending,
      ],
    }));
    return res;
  }, []);

  return {
    ...state,
    serverConnected,
    currentAccount,
    setCurrentAccount,
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
    uploadPending,
  };
}

export type Store = ReturnType<typeof useStore>;
