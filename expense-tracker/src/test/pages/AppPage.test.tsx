import { describe, it, expect, beforeEach } from 'vitest';
import { screen, fireEvent } from '@testing-library/react';
import { renderWithStore } from '../helpers';
import { AppPage } from '../../pages/AppPage';

// The AppPage reads/writes to localStorage directly (QUEUE_KEY)
const QUEUE_KEY = 'app_pending_queue';

beforeEach(() => {
  localStorage.removeItem(QUEUE_KEY);
});

describe('AppPage', () => {
  it('renders the header', () => {
    renderWithStore(<AppPage />);
    expect(screen.getByText(/Quick Add/i)).toBeInTheDocument();
  });

  it('shows account picker buttons', () => {
    renderWithStore(<AppPage />);
    expect(screen.getAllByText(/Personal/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/Family/i).length).toBeGreaterThan(0);
  });

  it('shows the Add to queue button', () => {
    renderWithStore(<AppPage />);
    expect(screen.getByText(/Add to queue/i)).toBeInTheDocument();
  });

  it('shows empty state when no pending transactions', () => {
    renderWithStore(<AppPage />);
    expect(screen.getByText(/No pending expenses/i)).toBeInTheDocument();
  });

  it('validates: shows error when amount is missing', () => {
    renderWithStore(<AppPage />);
    fireEvent.click(screen.getByText(/Add to queue/i));
    expect(screen.getByText(/Enter a valid amount/i)).toBeInTheDocument();
  });

  it('validates: shows error when description is missing', () => {
    renderWithStore(<AppPage />);
    const amountInput = screen.getByPlaceholderText('0.00');
    fireEvent.change(amountInput, { target: { value: '10' } });
    fireEvent.click(screen.getByText(/Add to queue/i));
    expect(screen.getByText(/Description is required/i)).toBeInTheDocument();
  });

  it('adds an expense to pending queue', () => {
    renderWithStore(<AppPage />);
    const amountInput = screen.getByPlaceholderText('0.00');
    fireEvent.change(amountInput, { target: { value: '25.50' } });
    const descInput = screen.getByPlaceholderText('What was this for?');
    fireEvent.change(descInput, { target: { value: 'Morning coffee' } });
    fireEvent.click(screen.getByText(/Add to queue/i));
    expect(screen.getByText('Morning coffee')).toBeInTheDocument();
    expect(screen.getByText(/Pending \(1\)/i)).toBeInTheDocument();
  });

  it('removes an item from the pending queue', () => {
    renderWithStore(<AppPage />);
    // Add one item
    fireEvent.change(screen.getByPlaceholderText('0.00'), { target: { value: '15' } });
    fireEvent.change(screen.getByPlaceholderText('What was this for?'), { target: { value: 'Lunch' } });
    fireEvent.click(screen.getByText(/Add to queue/i));
    expect(screen.getByText('Lunch')).toBeInTheDocument();
    // Remove it
    const deleteBtn = screen.getByRole('button', { name: '' }); // Trash2 icon button has no accessible label
    // Find it by its container; simpler: look for all buttons and find Trash icon's parent
    const trashBtn = document.querySelector('button svg.lucide-trash-2')?.closest('button') as HTMLButtonElement;
    if (trashBtn) fireEvent.click(trashBtn);
    expect(screen.queryByText('Lunch')).not.toBeInTheDocument();
  });

  it('persists queue to localStorage on add', () => {
    renderWithStore(<AppPage />);
    fireEvent.change(screen.getByPlaceholderText('0.00'), { target: { value: '5' } });
    fireEvent.change(screen.getByPlaceholderText('What was this for?'), { target: { value: 'Tea' } });
    fireEvent.click(screen.getByText(/Add to queue/i));
    const stored = JSON.parse(localStorage.getItem(QUEUE_KEY) ?? '[]');
    expect(stored).toHaveLength(1);
    expect(stored[0].description).toBe('Tea');
  });

  it('shows upload button when pending items exist', () => {
    renderWithStore(<AppPage />);
    fireEvent.change(screen.getByPlaceholderText('0.00'), { target: { value: '5' } });
    fireEvent.change(screen.getByPlaceholderText('What was this for?'), { target: { value: 'Juice' } });
    fireEvent.click(screen.getByText(/Add to queue/i));
    expect(screen.getByText(/Upload/i)).toBeInTheDocument();
  });

  it('upload button is disabled when not connected to server', () => {
    renderWithStore(<AppPage />);
    fireEvent.change(screen.getByPlaceholderText('0.00'), { target: { value: '5' } });
    fireEvent.change(screen.getByPlaceholderText('What was this for?'), { target: { value: 'Coffee' } });
    fireEvent.click(screen.getByText(/Add to queue/i));
    // Button is disabled because serverConnected is false in test environment
    const uploadBtn = screen.getByText(/Upload/i).closest('button') as HTMLButtonElement;
    expect(uploadBtn).toBeDisabled();
  });

  it('restores queue from localStorage on mount', () => {
    const stored = [
      {
        id: 'test-1', type: 'expense', amount: 9.99, currency: 'USD',
        categoryId: 'food', description: 'Saved expense', date: '2024-01-01',
        tags: [], isRecurring: false, accountId: 'personal',
        createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z',
      },
    ];
    localStorage.setItem(QUEUE_KEY, JSON.stringify(stored));
    renderWithStore(<AppPage />);
    expect(screen.getByText('Saved expense')).toBeInTheDocument();
    expect(screen.getByText(/Pending \(1\)/i)).toBeInTheDocument();
  });

  it('switches account label when Family is clicked', () => {
    renderWithStore(<AppPage />);
    // Add an item as personal
    fireEvent.change(screen.getByPlaceholderText('0.00'), { target: { value: '5' } });
    fireEvent.change(screen.getByPlaceholderText('What was this for?'), { target: { value: 'Test' } });

    // Click Family account in header picker
    const familyBtns = screen.getAllByText(/Family/i);
    fireEvent.click(familyBtns[0]);
    // Family tab should now be selected (active state)
    expect(familyBtns[0].className).toContain('bg-white');
  });

  it('adds merchant when provided', () => {
    renderWithStore(<AppPage />);
    fireEvent.change(screen.getByPlaceholderText('0.00'), { target: { value: '10' } });
    fireEvent.change(screen.getByPlaceholderText('What was this for?'), { target: { value: 'Espresso' } });
    fireEvent.change(screen.getByPlaceholderText('Merchant (optional)'), { target: { value: 'Starbucks' } });
    fireEvent.click(screen.getByText(/Add to queue/i));
    const stored = JSON.parse(localStorage.getItem(QUEUE_KEY) ?? '[]');
    expect(stored[0].merchant).toBe('Starbucks');
  });

  it('handles invalid JSON in localStorage gracefully (empty queue)', () => {
    localStorage.setItem(QUEUE_KEY, 'not-valid-json!');
    renderWithStore(<AppPage />);
    // Should render the empty state without throwing
    expect(screen.getByText(/No pending expenses/i)).toBeInTheDocument();
  });

  it('can add multiple items to the queue', () => {
    renderWithStore(<AppPage />);
    const addItem = (amt: string, desc: string) => {
      fireEvent.change(screen.getByPlaceholderText('0.00'), { target: { value: amt } });
      fireEvent.change(screen.getByPlaceholderText('What was this for?'), { target: { value: desc } });
      fireEvent.click(screen.getByText(/Add to queue/i));
    };
    addItem('5', 'Coffee');
    addItem('15', 'Lunch');
    addItem('3', 'Snack');
    expect(screen.getByText(/Pending \(3\)/i)).toBeInTheDocument();
    expect(screen.getByText('Coffee')).toBeInTheDocument();
    expect(screen.getByText('Lunch')).toBeInTheDocument();
    expect(screen.getByText('Snack')).toBeInTheDocument();
  });
});
