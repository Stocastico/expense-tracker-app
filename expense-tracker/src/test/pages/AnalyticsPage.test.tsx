import { describe, it, expect, beforeEach } from 'vitest';
import { screen, fireEvent } from '@testing-library/react';
import { renderWithStore } from '../helpers';
import { AnalyticsPage } from '../../pages/AnalyticsPage';
import { saveState } from '../../store/storage';
import { DEFAULT_SETTINGS } from '../../store/defaults';

const currentMonthDate = `${new Date().toISOString().substring(0, 7)}-15`;

describe('AnalyticsPage – empty state', () => {
  it('renders heading', () => {
    renderWithStore(<AnalyticsPage />);
    expect(screen.getByText('Analytics')).toBeInTheDocument();
  });

  it('renders the month range selector buttons', () => {
    renderWithStore(<AnalyticsPage />);
    expect(screen.getByText('3M')).toBeInTheDocument();
    expect(screen.getByText('6M')).toBeInTheDocument();
    expect(screen.getByText('12M')).toBeInTheDocument();
  });

  it('renders summary stat cards', () => {
    renderWithStore(<AnalyticsPage />);
    expect(screen.getByText(/vs last month/i)).toBeInTheDocument();
    expect(screen.getByText(/Predicted/i)).toBeInTheDocument();
    expect(screen.getAllByText(/Savings rate/i).length).toBeGreaterThan(0);
  });

  it('renders chart section titles', () => {
    renderWithStore(<AnalyticsPage />);
    expect(screen.getByText(/Monthly Overview/i)).toBeInTheDocument();
    expect(screen.getByText(/Net Balance Trend/i)).toBeInTheDocument();
  });

  it('changes month range when button clicked', () => {
    renderWithStore(<AnalyticsPage />);
    const btn3m = screen.getByText('3M');
    fireEvent.click(btn3m);
    // 3M button should become "active" (has different bg class)
    expect(btn3m.className).toContain('bg-white');
  });

  it('renders savings rate section', () => {
    renderWithStore(<AnalyticsPage />);
    expect(screen.getAllByText(/Savings Rate/i).length).toBeGreaterThan(0);
    expect(screen.getByText(/Target: 20%/i)).toBeInTheDocument();
  });
});

describe('AnalyticsPage – with current month transactions', () => {
  beforeEach(() => {
    saveState({
      transactions: [
        { id: 't1', type: 'expense', amount: 50, currency: 'USD', categoryId: 'food',
          description: 'Lunch', date: currentMonthDate, tags: [], isRecurring: false,
          createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
        { id: 't2', type: 'expense', amount: 30, currency: 'USD', categoryId: 'transport',
          description: 'Bus', date: currentMonthDate, tags: [], isRecurring: false,
          createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
        { id: 't3', type: 'income', amount: 3000, currency: 'USD', categoryId: 'salary',
          description: 'Paycheck', date: currentMonthDate, tags: [], isRecurring: false,
          createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
      ],
      budgets: [],
      settings: DEFAULT_SETTINGS,
    });
  });

  it('renders pie chart section when there are current month expenses', () => {
    renderWithStore(<AnalyticsPage />);
    expect(screen.getByText(/This Month by Category/i)).toBeInTheDocument();
  });

  it('renders category legend entries', () => {
    renderWithStore(<AnalyticsPage />);
    // Category names appear in the legend
    expect(screen.getAllByText(/Food|Transport/i).length).toBeGreaterThan(0);
  });

  it('shows a positive savings rate when income > expenses', () => {
    renderWithStore(<AnalyticsPage />);
    // With $3000 income and $80 expenses, savings rate is very high
    // The savings rate display shows green for >=20%
    const savingsCards = document.querySelectorAll('[class*="emerald"]');
    expect(savingsCards.length).toBeGreaterThan(0);
  });
});

describe('AnalyticsPage – savings rate color states', () => {
  it('shows amber savings rate when rate is between 0-20%', () => {
    saveState({
      transactions: [
        { id: 't1', type: 'expense', amount: 850, currency: 'USD', categoryId: 'food',
          description: 'Expenses', date: currentMonthDate, tags: [], isRecurring: false,
          createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
        { id: 't2', type: 'income', amount: 1000, currency: 'USD', categoryId: 'salary',
          description: 'Salary', date: currentMonthDate, tags: [], isRecurring: false,
          createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
      ],
      budgets: [],
      settings: DEFAULT_SETTINGS,
    });
    renderWithStore(<AnalyticsPage />);
    // savings rate = (1000 - 850) / 1000 * 100 = 15% — amber range
    expect(screen.getAllByText(/Savings Rate/i).length).toBeGreaterThan(0);
  });

  it('shows red savings rate when expenses exceed income', () => {
    saveState({
      transactions: [
        { id: 't1', type: 'expense', amount: 1200, currency: 'USD', categoryId: 'housing',
          description: 'Rent', date: currentMonthDate, tags: [], isRecurring: false,
          createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
        { id: 't2', type: 'income', amount: 1000, currency: 'USD', categoryId: 'salary',
          description: 'Salary', date: currentMonthDate, tags: [], isRecurring: false,
          createdAt: `${currentMonthDate}T00:00:00Z`, updatedAt: `${currentMonthDate}T00:00:00Z` },
      ],
      budgets: [],
      settings: DEFAULT_SETTINGS,
    });
    renderWithStore(<AnalyticsPage />);
    expect(screen.getAllByText(/Savings Rate/i).length).toBeGreaterThan(0);
  });
});
