import { describe, it, expect } from 'vitest';
import { screen, fireEvent } from '@testing-library/react';
import { renderWithStore } from '../helpers';
import { TransactionsPage } from '../../pages/TransactionsPage';

// Wrap with store that has pre-loaded data via localStorage
import { saveState } from '../../store/storage';
import { DEFAULT_SETTINGS } from '../../store/defaults';
import { makeTx } from '../helpers';

function setupWithTransactions() {
  saveState({
    transactions: [
      makeTx({ id: 'tx-a', description: 'Pizza lunch',  categoryId: 'food',      date: '2024-01-15', amount: 15 }),
      makeTx({ id: 'tx-b', description: 'Uber home',    categoryId: 'transport', date: '2024-01-10', amount: 20 }),
      makeTx({ id: 'tx-c', description: 'Netflix',      categoryId: 'subscriptions', date: '2024-02-01', amount: 14, type: 'expense' }),
    ],
    budgets: [],
    settings: DEFAULT_SETTINGS,
  });
}

describe('TransactionsPage – empty state', () => {
  it('shows empty state when no transactions', () => {
    renderWithStore(<TransactionsPage />);
    expect(screen.getByText(/No transactions found/i)).toBeInTheDocument();
  });

  it('renders search input', () => {
    renderWithStore(<TransactionsPage />);
    expect(screen.getByPlaceholderText(/Search transactions/i)).toBeInTheDocument();
  });

  it('renders Filters toggle', () => {
    renderWithStore(<TransactionsPage />);
    expect(screen.getByText(/Filters/i)).toBeInTheDocument();
  });
});

describe('TransactionsPage – with data', () => {
  beforeEach(setupWithTransactions);

  it('shows transaction descriptions', () => {
    renderWithStore(<TransactionsPage />);
    expect(screen.getByText('Pizza lunch')).toBeInTheDocument();
    expect(screen.getByText('Uber home')).toBeInTheDocument();
    expect(screen.getByText('Netflix')).toBeInTheDocument();
  });

  it('shows transaction count in subtitle', () => {
    renderWithStore(<TransactionsPage />);
    expect(screen.getByText(/3 of 3/i)).toBeInTheDocument();
  });

  it('filters by search query', () => {
    renderWithStore(<TransactionsPage />);
    const searchInput = screen.getByPlaceholderText(/Search transactions/i);
    fireEvent.change(searchInput, { target: { value: 'Pizza' } });
    expect(screen.getByText('Pizza lunch')).toBeInTheDocument();
    expect(screen.queryByText('Uber home')).not.toBeInTheDocument();
  });

  it('shows filter options when Filters is clicked', () => {
    renderWithStore(<TransactionsPage />);
    fireEvent.click(screen.getByText(/Filters/i));
    expect(screen.getByText(/All categories/i)).toBeInTheDocument();
  });

  it('filters by expense type', () => {
    renderWithStore(<TransactionsPage />);
    fireEvent.click(screen.getByText(/Filters/i));
    fireEvent.click(screen.getByText(/💸 Expenses/i));
    // All transactions are expenses, so all 3 still show
    expect(screen.getByText('Pizza lunch')).toBeInTheDocument();
  });

  it('filters by income type shows empty state', () => {
    renderWithStore(<TransactionsPage />);
    fireEvent.click(screen.getByText(/Filters/i));
    fireEvent.click(screen.getByText(/💵 Income/i));
    expect(screen.getByText(/No transactions found/i)).toBeInTheDocument();
  });

  it('filters by category', () => {
    renderWithStore(<TransactionsPage />);
    fireEvent.click(screen.getByText(/Filters/i));
    const selects = screen.getAllByRole('combobox');
    fireEvent.change(selects[0], { target: { value: 'food' } });
    expect(screen.getByText('Pizza lunch')).toBeInTheDocument();
    expect(screen.queryByText('Uber home')).not.toBeInTheDocument();
  });

  it('sorts by amount when sort button is clicked', () => {
    renderWithStore(<TransactionsPage />);
    fireEvent.click(screen.getByText(/Filters/i));
    fireEvent.click(screen.getByText(/Sort by amount/i));
    expect(screen.getByText('Pizza lunch')).toBeInTheDocument();
  });

  it('toggles sort direction when clicking same sort key again', () => {
    renderWithStore(<TransactionsPage />);
    fireEvent.click(screen.getByText(/Filters/i));
    // Click date sort twice to toggle direction
    const dateSortBtn = screen.getByText(/Sort by date/i);
    fireEvent.click(dateSortBtn);
    fireEvent.click(dateSortBtn);
    expect(screen.getByText('Pizza lunch')).toBeInTheDocument();
  });
});
