import { type ReactNode } from 'react';
import { render, type RenderOptions } from '@testing-library/react';
import { StoreProvider } from '../store/StoreContext';

export function renderWithStore(ui: ReactNode, options?: Omit<RenderOptions, 'wrapper'>) {
  return render(ui, { wrapper: ({ children }) => <StoreProvider>{children}</StoreProvider>, ...options });
}

/**
 * Build a minimal transaction fixture. Only required fields must be provided;
 * all optional fields default to sensible values.
 */
import type { Transaction } from '../types';
import { v4 as uuidv4 } from 'uuid';

export function makeTx(overrides: Partial<Transaction> = {}): Transaction {
  return {
    id: uuidv4(),
    type: 'expense',
    amount: 50,
    currency: 'USD',
    categoryId: 'food',
    description: 'Test transaction',
    date: '2024-01-15',
    tags: [],
    isRecurring: false,
    accountId: 'personal',
    createdAt: '2024-01-15T10:00:00Z',
    updatedAt: '2024-01-15T10:00:00Z',
    ...overrides,
  };
}
