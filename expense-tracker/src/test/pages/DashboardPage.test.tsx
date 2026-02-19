import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithStore, makeTx } from '../helpers';
import { DashboardPage } from '../../pages/DashboardPage';
import { saveState } from '../../store/storage';
import { DEFAULT_SETTINGS } from '../../store/defaults';

// Recharts uses SVG; jsdom handles it fine but we need ResizeObserver mocked (done in setup)

// Get current date strings for this month's transactions
const today = new Date();
const currentMonthDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-15`;

describe('DashboardPage – empty state', () => {
  const onNavigate = vi.fn();

  it('renders the current month title', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    const now = new Date();
    const monthName = now.toLocaleString('en-US', { month: 'long' });
    expect(screen.getByText(new RegExp(monthName, 'i'))).toBeInTheDocument();
  });

  it('shows empty state when no transactions', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    expect(screen.getByText(/No transactions yet/i)).toBeInTheDocument();
  });

  it('renders stat cards', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    expect(screen.getByText(/Spent this month/i)).toBeInTheDocument();
    expect(screen.getByText(/Earned this month/i)).toBeInTheDocument();
    expect(screen.getByText(/Net balance/i)).toBeInTheDocument();
  });

  it('shows "See all" link', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    expect(screen.getByText(/See all/i)).toBeInTheDocument();
  });

  it('calls onNavigate when See all is clicked', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    screen.getByText(/See all/i).closest('button')?.click();
    expect(onNavigate).toHaveBeenCalledWith('transactions');
  });

  it('renders net cash flow stat card', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    expect(screen.getByText(/Net cash flow/i)).toBeInTheDocument();
  });
});

describe('DashboardPage – with transactions', () => {
  const onNavigate = vi.fn();

  beforeEach(() => {
    saveState({
      transactions: [
        makeTx({ description: 'Coffee', amount: 5, type: 'expense', categoryId: 'food', date: currentMonthDate }),
        makeTx({ description: 'Salary', amount: 3000, type: 'income', categoryId: 'salary', date: currentMonthDate }),
      ],
      budgets: [],
      settings: DEFAULT_SETTINGS,
    });
  });

  it('displays transactions in recent list', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    expect(screen.getByText('Coffee')).toBeInTheDocument();
    expect(screen.getAllByText('Salary').length).toBeGreaterThan(0);
  });

  it('shows top category when there are expenses', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    // "Top category" stat card should show a category name
    expect(screen.getByText(/Top category/i)).toBeInTheDocument();
  });

  it('shows overspent label when expenses exceed income', () => {
    saveState({
      transactions: [
        makeTx({ description: 'Rent', amount: 5000, type: 'expense', categoryId: 'housing', date: currentMonthDate }),
      ],
      budgets: [],
      settings: DEFAULT_SETTINGS,
    });
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    expect(screen.getByText(/Overspent this month/i)).toBeInTheDocument();
  });
});

describe('DashboardPage – budget alerts', () => {
  const onNavigate = vi.fn();

  beforeEach(() => {
    saveState({
      transactions: [
        makeTx({ description: 'Food spend', amount: 250, type: 'expense', categoryId: 'food', date: currentMonthDate }),
      ],
      budgets: [{
        id: 'b1', categoryId: 'food', amount: 300, currency: 'USD',
        period: 'monthly', createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z',
      }],
      settings: DEFAULT_SETTINGS,
    });
  });

  it('shows budget alert when spending is >= 80% of budget', () => {
    renderWithStore(<DashboardPage onNavigate={onNavigate} />);
    expect(screen.getByText(/Budget alerts/i)).toBeInTheDocument();
  });
});
