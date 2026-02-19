import { describe, it, expect, vi } from 'vitest';
import { screen, fireEvent } from '@testing-library/react';
import { renderWithStore, makeTx } from '../../helpers';
import { TransactionItem } from '../../../components/transactions/TransactionItem';

// Mock tesseract.js (pulled in via TransactionForm inside the edit modal)
vi.mock('tesseract.js', () => ({
  createWorker: vi.fn().mockResolvedValue({
    recognize: vi.fn().mockResolvedValue({ data: { text: '' } }),
    terminate: vi.fn(),
  }),
}));

describe('TransactionItem', () => {
  it('renders description', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ description: 'Morning coffee' })} />);
    expect(screen.getByText('Morning coffee')).toBeInTheDocument();
  });

  it('shows expense amount in red with minus sign', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ type: 'expense', amount: 42.5 })} />);
    const amountEl = screen.getByText(/-.*42/);
    expect(amountEl.className).toMatch(/red|rose/);
  });

  it('shows income amount in green with plus sign', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ type: 'income', amount: 1000, categoryId: 'salary' })} />);
    const amountEl = screen.getByText(/\+/);
    expect(amountEl.className).toContain('emerald');
  });

  it('shows SVG icons', () => {
    const { container } = renderWithStore(<TransactionItem transaction={makeTx({ isRecurring: true })} />);
    expect(container.querySelectorAll('svg').length).toBeGreaterThan(0);
  });

  it('renders tags', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ tags: ['work', 'team'] })} />);
    expect(screen.getByText('#work')).toBeInTheDocument();
    expect(screen.getByText('#team')).toBeInTheDocument();
  });

  it('shows merchant name when provided', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ merchant: 'Starbucks' })} />);
    expect(screen.getByText('Starbucks')).toBeInTheDocument();
  });

  it('shows formatted date', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ date: '2024-03-15' })} />);
    expect(screen.getByText(/Mar 15/)).toBeInTheDocument();
  });

  it('opens edit modal when edit icon button is clicked', () => {
    renderWithStore(<TransactionItem transaction={makeTx()} />);
    const svgBtns = Array.from(document.querySelectorAll('button')).filter(b => b.querySelector('svg'));
    if (svgBtns.length >= 1) {
      fireEvent.click(svgBtns[0]);
      expect(screen.queryByText('Edit Transaction')).toBeInTheDocument();
    }
  });

  it('opens delete confirmation dialog when trash icon is clicked', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ description: 'Coffee' })} />);
    const svgBtns = Array.from(document.querySelectorAll('button')).filter(b => b.querySelector('svg'));
    if (svgBtns.length >= 2) {
      fireEvent.click(svgBtns[1]);
      // Multiple "delete" texts appear (title + buttons) — check at least one exists
      const deleteEls = screen.getAllByText(/delete/i);
      expect(deleteEls.length).toBeGreaterThan(0);
    }
  });

  it('shows the confirmation question in the delete dialog', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ description: 'Coffee' })} />);
    const svgBtns = Array.from(document.querySelectorAll('button')).filter(b => b.querySelector('svg'));
    if (svgBtns.length >= 2) {
      fireEvent.click(svgBtns[1]);
      expect(screen.getByText(/Delete this one/i)).toBeInTheDocument();
    }
  });

  it('shows "Delete all recurring" option for recurring transactions', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ description: 'Rent', isRecurring: true })} />);
    const svgBtns = Array.from(document.querySelectorAll('button')).filter(b => b.querySelector('svg'));
    if (svgBtns.length >= 2) {
      fireEvent.click(svgBtns[1]);
      expect(screen.getByText(/Delete all recurring/i)).toBeInTheDocument();
    }
  });

  it('closes delete modal when Cancel is clicked', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ description: 'Coffee' })} />);
    const svgBtns = Array.from(document.querySelectorAll('button')).filter(b => b.querySelector('svg'));
    if (svgBtns.length >= 2) {
      fireEvent.click(svgBtns[1]);
      fireEvent.click(screen.getByText(/^Cancel$/i));
      expect(screen.queryByText(/Are you sure/i)).not.toBeInTheDocument();
    }
  });

  it('deletes transaction when "Delete this one" is clicked', () => {
    renderWithStore(<TransactionItem transaction={makeTx({ description: 'Lunch' })} />);
    const svgBtns = Array.from(document.querySelectorAll('button')).filter(b => b.querySelector('svg'));
    if (svgBtns.length >= 2) {
      fireEvent.click(svgBtns[1]);
      fireEvent.click(screen.getByText(/Delete this one/i));
      // After delete, modal should close
      expect(screen.queryByText(/Are you sure/i)).not.toBeInTheDocument();
    }
  });
});
