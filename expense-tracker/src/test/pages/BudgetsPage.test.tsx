import { describe, it, expect, beforeEach } from 'vitest';
import { screen, fireEvent } from '@testing-library/react';
import { renderWithStore } from '../helpers';
import { BudgetsPage } from '../../pages/BudgetsPage';
import { saveState } from '../../store/storage';
import { DEFAULT_SETTINGS } from '../../store/defaults';

// Current month prefix for transactions that match this month
const currentMonthPrefix = new Date().toISOString().substring(0, 7);
const currentMonthDate = `${currentMonthPrefix}-15`;

describe('BudgetsPage – empty state', () => {
  it('renders heading', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText('Budgets')).toBeInTheDocument();
  });

  it('shows empty state when no budgets', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText(/No budgets set/i)).toBeInTheDocument();
  });

  it('renders Add budget button', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getAllByText(/Add budget/i).length).toBeGreaterThan(0);
  });

  it('opens Set Budget modal when Add budget clicked', () => {
    renderWithStore(<BudgetsPage />);
    fireEvent.click(screen.getAllByText(/Add budget/i)[0]);
    expect(screen.getByText('Set Budget')).toBeInTheDocument();
  });

  it('budget modal contains at least two select boxes (category + period)', () => {
    renderWithStore(<BudgetsPage />);
    fireEvent.click(screen.getAllByText(/Add budget/i)[0]);
    expect(screen.getAllByRole('combobox').length).toBeGreaterThanOrEqual(2);
  });

  it('budget modal shows Monthly and Yearly period options', () => {
    renderWithStore(<BudgetsPage />);
    fireEvent.click(screen.getAllByText(/Add budget/i)[0]);
    expect(screen.getByText('Monthly')).toBeInTheDocument();
    expect(screen.getByText('Yearly')).toBeInTheDocument();
  });

  it('budget modal has a Save Budget button', () => {
    renderWithStore(<BudgetsPage />);
    fireEvent.click(screen.getAllByText(/Add budget/i)[0]);
    expect(screen.getByText(/Save Budget/i)).toBeInTheDocument();
  });

  it('shows validation error when saving without amount', () => {
    renderWithStore(<BudgetsPage />);
    fireEvent.click(screen.getAllByText(/Add budget/i)[0]);
    fireEvent.click(screen.getByText(/Save Budget/i));
    expect(screen.getByText(/valid amount/i)).toBeInTheDocument();
  });
});

describe('BudgetsPage – with a pre-loaded budget', () => {
  beforeEach(() => {
    saveState({
      transactions: [],
      budgets: [{
        id: 'b1', categoryId: 'food', amount: 300, currency: 'USD',
        period: 'monthly', createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z',
      }],
      settings: DEFAULT_SETTINGS,
    });
  });

  it('shows the budget category name', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText('Food & Dining')).toBeInTheDocument();
  });

  it('shows "spent" label', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText(/spent/i)).toBeInTheDocument();
  });

  it('shows summary with total budgeted amount', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText(/of.*used/i)).toBeInTheDocument();
  });

  it('has action buttons on the page', () => {
    renderWithStore(<BudgetsPage />);
    expect(document.querySelectorAll('button').length).toBeGreaterThan(0);
  });

  it('shows monthly period label', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText(/monthly/i)).toBeInTheDocument();
  });
});

describe('BudgetsPage – over budget state', () => {
  beforeEach(() => {
    saveState({
      transactions: [
        { id: 't1', type: 'expense', amount: 400, currency: 'USD', categoryId: 'food',
          description: 'Food overspend', date: currentMonthDate, tags: [],
          isRecurring: false, createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
      ],
      budgets: [{
        id: 'b1', categoryId: 'food', amount: 300, currency: 'USD',
        period: 'monthly', createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z',
      }],
      settings: DEFAULT_SETTINGS,
    });
  });

  it('shows over budget alert when spending exceeds budget', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText(/exceeded/i)).toBeInTheDocument();
  });

  it('shows "over" text in budget card', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText(/over/i)).toBeInTheDocument();
  });
});

describe('BudgetsPage – warning state (80-100%)', () => {
  beforeEach(() => {
    saveState({
      transactions: [
        { id: 't1', type: 'expense', amount: 260, currency: 'USD', categoryId: 'food',
          description: 'Food spend', date: currentMonthDate, tags: [],
          isRecurring: false, createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
      ],
      budgets: [{
        id: 'b1', categoryId: 'food', amount: 300, currency: 'USD',
        period: 'monthly', createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z',
      }],
      settings: DEFAULT_SETTINGS,
    });
  });

  it('shows "left" text when within budget', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText(/left/i)).toBeInTheDocument();
  });
});

describe('BudgetsPage – yearly budget', () => {
  beforeEach(() => {
    saveState({
      transactions: [],
      budgets: [{
        id: 'b2', categoryId: 'transport', amount: 5000, currency: 'USD',
        period: 'yearly', createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z',
      }],
      settings: DEFAULT_SETTINGS,
    });
  });

  it('shows yearly period label', () => {
    renderWithStore(<BudgetsPage />);
    expect(screen.getByText(/yearly/i)).toBeInTheDocument();
  });
});
