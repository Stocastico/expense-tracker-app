import { describe, it, expect } from 'vitest';
import { screen, fireEvent } from '@testing-library/react';
import { render } from '@testing-library/react';
import App from '../App';

// Mock tesseract.js (pulled in transitively via TransactionForm)
vi.mock('tesseract.js', () => ({
  createWorker: vi.fn().mockResolvedValue({
    recognize: vi.fn().mockResolvedValue({ data: { text: '' } }),
    terminate: vi.fn(),
  }),
}));

describe('App integration', () => {
  it('renders without crashing', () => {
    render(<App />);
    expect(screen.getByText(/Expense Tracker/i)).toBeInTheDocument();
  });

  it('shows dashboard by default', () => {
    render(<App />);
    expect(screen.getByText(/Net balance/i)).toBeInTheDocument();
  });

  it('navigates to Transactions page', () => {
    render(<App />);
    // "Transactions" nav item label
    const navItem = screen.getAllByText('Transactions')[0];
    fireEvent.click(navItem);
    // TransactionsPage renders a search input with this placeholder
    expect(screen.getByPlaceholderText(/Search transactions/i)).toBeInTheDocument();
  });

  it('navigates to Analytics page', () => {
    render(<App />);
    const navItem = screen.getAllByText('Analytics')[0];
    fireEvent.click(navItem);
    expect(screen.getByText(/Monthly Overview/i)).toBeInTheDocument();
  });

  it('navigates to Budgets page', () => {
    render(<App />);
    fireEvent.click(screen.getByText('Budgets'));
    expect(screen.getByText(/No budgets set/i)).toBeInTheDocument();
  });

  it('navigates to Settings page', () => {
    render(<App />);
    const navItem = screen.getAllByText('Settings')[0];
    fireEvent.click(navItem);
    expect(screen.getByText(/Dark mode/i)).toBeInTheDocument();
  });

  it('opens Add Transaction modal from header button', () => {
    render(<App />);
    fireEvent.click(screen.getByRole('button', { name: /add transaction/i }));
    expect(screen.getByText(/Add Transaction/i)).toBeInTheDocument();
  });

  it('closes Add Transaction modal on Cancel', () => {
    render(<App />);
    fireEvent.click(screen.getByRole('button', { name: /add transaction/i }));
    fireEvent.click(screen.getByText(/Cancel/i));
    expect(screen.queryByText('Add Transaction')).not.toBeInTheDocument();
  });
});
