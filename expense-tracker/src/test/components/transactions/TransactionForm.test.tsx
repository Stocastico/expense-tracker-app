import { describe, it, expect, vi } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { renderWithStore, makeTx } from '../../helpers';
import { TransactionForm } from '../../../components/transactions/TransactionForm';

// Mock tesseract.js dynamic import used by OCR feature
vi.mock('tesseract.js', () => ({
  createWorker: vi.fn().mockResolvedValue({
    recognize: vi.fn().mockResolvedValue({ data: { text: 'Starbucks\n01/15/2024\nTotal $5.50' } }),
    terminate: vi.fn(),
  }),
}));

describe('TransactionForm – add mode', () => {
  it('renders all key fields', () => {
    renderWithStore(<TransactionForm onClose={() => {}} />);
    expect(screen.getByPlaceholderText(/what was this for/i)).toBeInTheDocument();
    expect(screen.getAllByText(/Expense/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/Income/i).length).toBeGreaterThan(0);
    expect(screen.getByText(/Recurring transaction/i)).toBeInTheDocument();
  });

  it('renders Scan receipt and Upload image buttons', () => {
    renderWithStore(<TransactionForm onClose={() => {}} />);
    expect(screen.getByText(/Scan receipt/i)).toBeInTheDocument();
    expect(screen.getByText(/Upload image/i)).toBeInTheDocument();
  });

  it('renders at least one category dropdown', () => {
    renderWithStore(<TransactionForm onClose={() => {}} />);
    expect(screen.getAllByRole('combobox').length).toBeGreaterThan(0);
  });

  it('switches to income type', async () => {
    const user = userEvent.setup();
    renderWithStore(<TransactionForm onClose={() => {}} />);
    const incomeToggle = screen.getAllByText(/Income/i)[0];
    await user.click(incomeToggle);
    // After switching, the Add Income button should appear
    expect(screen.getByText(/Add Income/i)).toBeInTheDocument();
  });

  it('shows validation error for empty amount', async () => {
    const user = userEvent.setup();
    renderWithStore(<TransactionForm onClose={() => {}} />);
    await user.type(screen.getByPlaceholderText(/what was this for/i), 'Lunch');
    await user.click(screen.getByText(/Add Expense/i));
    expect(screen.getByText(/valid amount/i)).toBeInTheDocument();
  });

  it('shows validation error for empty description', async () => {
    const user = userEvent.setup();
    renderWithStore(<TransactionForm onClose={() => {}} />);
    await user.type(screen.getByPlaceholderText(/0\.00/), '25');
    await user.click(screen.getByText(/Add Expense/i));
    expect(screen.getByText(/description is required/i)).toBeInTheDocument();
  });

  it('calls onClose after successful submission', async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();
    renderWithStore(<TransactionForm onClose={onClose} />);
    await user.type(screen.getByPlaceholderText(/0\.00/), '42');
    await user.type(screen.getByPlaceholderText(/what was this for/i), 'Pizza');
    await user.click(screen.getByText(/Add Expense/i));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('calls onClose when Cancel is clicked', async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();
    renderWithStore(<TransactionForm onClose={onClose} />);
    await user.click(screen.getByText(/Cancel/i));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('shows recurring frequency field when toggle is enabled', async () => {
    const user = userEvent.setup();
    renderWithStore(<TransactionForm onClose={() => {}} />);
    const toggleLabel = screen.getByText(/Recurring transaction/i).closest('label');
    const toggleDiv = toggleLabel?.querySelector('div') as HTMLElement;
    if (toggleDiv) {
      await user.click(toggleDiv);
      await waitFor(() => expect(screen.getByText('Frequency')).toBeInTheDocument());
    }
  });

  it('adds a tag and displays it', async () => {
    const user = userEvent.setup();
    renderWithStore(<TransactionForm onClose={() => {}} />);
    await user.type(screen.getByPlaceholderText(/Add tag/i), 'work');
    await user.click(screen.getByRole('button', { name: /^Add$/i }));
    expect(screen.getByText('#work')).toBeInTheDocument();
  });

  it('removes a tag when its X button is clicked', async () => {
    const user = userEvent.setup();
    renderWithStore(<TransactionForm onClose={() => {}} />);
    await user.type(screen.getByPlaceholderText(/Add tag/i), 'work');
    await user.click(screen.getByRole('button', { name: /^Add$/i }));
    // The tag span contains the text and an X button child
    const tagSpan = screen.getByText('#work');
    const removeBtn = tagSpan.querySelector('button') as HTMLButtonElement;
    if (removeBtn) await user.click(removeBtn);
    expect(screen.queryByText('#work')).not.toBeInTheDocument();
  });

  it('adds tag via Enter key', async () => {
    const user = userEvent.setup();
    renderWithStore(<TransactionForm onClose={() => {}} />);
    await user.type(screen.getByPlaceholderText(/Add tag/i), 'budget{Enter}');
    expect(screen.getByText('#budget')).toBeInTheDocument();
  });

  it('auto-guesses transport category from "Uber" merchant', async () => {
    const user = userEvent.setup();
    renderWithStore(<TransactionForm onClose={() => {}} />);
    await user.type(screen.getByPlaceholderText(/starbucks/i), 'Uber');
    await waitFor(() => {
      const selects = screen.getAllByRole('combobox') as HTMLSelectElement[];
      const catSelect = selects.find(s => s.value === 'transport');
      expect(catSelect).toBeTruthy();
    });
  });
});

describe('TransactionForm – edit mode', () => {
  it('pre-fills form with transaction data', () => {
    const tx = makeTx({ description: 'Existing lunch', amount: 35, date: '2024-03-10' });
    renderWithStore(<TransactionForm transaction={tx} onClose={() => {}} />);
    expect(screen.getByDisplayValue('Existing lunch')).toBeInTheDocument();
    expect(screen.getByDisplayValue('35')).toBeInTheDocument();
  });

  it('shows Save Changes button in edit mode', () => {
    const tx = makeTx();
    renderWithStore(<TransactionForm transaction={tx} onClose={() => {}} />);
    expect(screen.getByText(/Save Changes/i)).toBeInTheDocument();
  });

  it('saves edits and calls onClose', async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();
    const tx = makeTx({ description: 'Old description', amount: 10 });
    renderWithStore(<TransactionForm transaction={tx} onClose={onClose} />);
    const descInput = screen.getByDisplayValue('Old description');
    await user.clear(descInput);
    await user.type(descInput, 'New description');
    await user.click(screen.getByText(/Save Changes/i));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('pre-fills recurring state when editing a recurring transaction', () => {
    const tx = makeTx({ isRecurring: true, recurringFrequency: 'monthly' });
    renderWithStore(<TransactionForm transaction={tx} onClose={() => {}} />);
    // Frequency field should be visible since recurring is already on
    expect(screen.getByText('Frequency')).toBeInTheDocument();
  });
});
