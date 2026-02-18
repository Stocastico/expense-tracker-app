import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, fireEvent, waitFor } from '@testing-library/react';
import { renderWithStore } from '../helpers';
import { PdfImportModal } from '../../components/transactions/PdfImportModal';

// Mock pdfImport utilities so we can test the modal without real PDF parsing
vi.mock('../../utils/pdfImport', () => ({
  extractPdfText: vi.fn().mockResolvedValue('mocked pdf text'),
  parsePdfText: vi.fn().mockReturnValue([
    { date: '2024-01-15', description: 'Coffee Shop', amount: 4.50, merchant: 'Coffee Shop' },
    { date: '2024-01-16', description: 'Grocery Store', amount: 45.00, merchant: 'Grocery Store' },
  ]),
  entriesToTransactions: vi.fn().mockReturnValue([
    {
      id: 'mock-1', type: 'expense', amount: 4.50, currency: 'USD',
      categoryId: 'food', description: 'Coffee Shop', merchant: 'Coffee Shop',
      date: '2024-01-15', tags: [], isRecurring: false, accountId: 'personal',
      createdAt: '2024-01-15T00:00:00Z', updatedAt: '2024-01-15T00:00:00Z',
    },
  ]),
}));

const fakeFile = new File(['%PDF-fake'], 'statement.pdf', { type: 'application/pdf' });

async function simulateFileUpload() {
  const fileInput = document.querySelector('input[type="file"]') as HTMLInputElement;
  Object.defineProperty(fileInput, 'files', { value: [fakeFile], configurable: true });
  fireEvent.change(fileInput);
}

describe('PdfImportModal – closed', () => {
  it('renders nothing when closed', () => {
    renderWithStore(<PdfImportModal open={false} onClose={() => {}} />);
    expect(screen.queryByText(/Import PDF Statement/i)).not.toBeInTheDocument();
  });
});

describe('PdfImportModal – pick step', () => {
  it('shows upload prompt when open', () => {
    renderWithStore(<PdfImportModal open={true} onClose={() => {}} />);
    expect(screen.getByText(/Import PDF Statement/i)).toBeInTheDocument();
    expect(screen.getByText(/Click to select PDF file/i)).toBeInTheDocument();
  });

  it('shows supported formats hint', () => {
    renderWithStore(<PdfImportModal open={true} onClose={() => {}} />);
    expect(screen.getByText(/bank\/credit card statements/i)).toBeInTheDocument();
  });
});

describe('PdfImportModal – review step', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  async function goToReview(parsedEntries = [
    { date: '2024-01-15', description: 'Coffee Shop', amount: 4.50, merchant: 'Coffee Shop' },
    { date: '2024-01-16', description: 'Grocery Store', amount: 45.00, merchant: 'Grocery Store' },
  ]) {
    const { extractPdfText, parsePdfText } = await import('../../utils/pdfImport');
    vi.mocked(extractPdfText).mockResolvedValue('mocked pdf text');
    vi.mocked(parsePdfText).mockReturnValue(parsedEntries);

    renderWithStore(<PdfImportModal open={true} onClose={() => {}} />);
    await simulateFileUpload();
    await waitFor(() => expect(screen.getByText(/Found/i)).toBeInTheDocument(), { timeout: 3000 });
  }

  it('shows parsed transactions in review step', async () => {
    await goToReview();
    expect(screen.getByText('Coffee Shop')).toBeInTheDocument();
    expect(screen.getByText('Grocery Store')).toBeInTheDocument();
  });

  it('shows "Found N potential transactions"', async () => {
    await goToReview();
    // The text has a <strong> tag around the count, so match parts separately
    expect(screen.getByText(/Found/i)).toBeInTheDocument();
    expect(screen.getByText('2')).toBeInTheDocument();
  });

  it('shows deselect all toggle (all selected by default)', async () => {
    await goToReview();
    expect(screen.getByText(/Deselect all/i)).toBeInTheDocument();
    expect(screen.getByText(/2 of 2 selected/i)).toBeInTheDocument();
  });

  it('deselects all when "Deselect all" is clicked', async () => {
    await goToReview();
    fireEvent.click(screen.getByText(/Deselect all/i));
    expect(screen.getByText(/0 of 2 selected/i)).toBeInTheDocument();
    expect(screen.getByText(/Select all/i)).toBeInTheDocument();
  });

  it('re-selects all after deselecting', async () => {
    await goToReview();
    fireEvent.click(screen.getByText(/Deselect all/i));
    fireEvent.click(screen.getByText(/Select all/i));
    expect(screen.getByText(/2 of 2 selected/i)).toBeInTheDocument();
  });

  it('toggles individual entry on click', async () => {
    await goToReview();
    const coffeeRow = screen.getByText('Coffee Shop').closest('li') as HTMLElement;
    fireEvent.click(coffeeRow);
    expect(screen.getByText(/1 of 2 selected/i)).toBeInTheDocument();
  });

  it('import button is disabled when nothing selected', async () => {
    await goToReview();
    fireEvent.click(screen.getByText(/Deselect all/i));
    const importBtn = screen.getByRole('button', { name: /Import 0/i });
    expect(importBtn).toBeDisabled();
  });

  it('shows done step after clicking import', async () => {
    await goToReview();
    fireEvent.click(screen.getByText(/Import 2 transactions/i));
    await waitFor(() => expect(screen.getByText(/Import complete/i)).toBeInTheDocument());
  });

  it('cancel resets to pick step', async () => {
    await goToReview();
    fireEvent.click(screen.getByText('Cancel'));
    await waitFor(() => expect(screen.getByText(/Click to select PDF file/i)).toBeInTheDocument());
  });

  it('shows default category and account selects', async () => {
    await goToReview();
    expect(screen.getByText(/Default category/i)).toBeInTheDocument();
    expect(screen.getByText(/Account/i)).toBeInTheDocument();
  });

  it('shows dates of transactions', async () => {
    await goToReview();
    expect(screen.getByText('2024-01-15')).toBeInTheDocument();
  });

  it('can change the account selector', async () => {
    await goToReview();
    const selects = screen.getAllByRole('combobox');
    // Last select is the account selector
    const accountSelect = selects[selects.length - 1];
    fireEvent.change(accountSelect, { target: { value: 'family' } });
    expect((accountSelect as HTMLSelectElement).value).toBe('family');
  });
});

describe('PdfImportModal – done step', () => {
  it('shows Import complete and Close button', async () => {
    const { extractPdfText, parsePdfText } = await import('../../utils/pdfImport');
    vi.mocked(extractPdfText).mockResolvedValue('text');
    vi.mocked(parsePdfText).mockReturnValue([
      { date: '2024-01-15', description: 'Test', amount: 10 },
    ]);

    renderWithStore(<PdfImportModal open={true} onClose={() => {}} />);
    await simulateFileUpload();
    await waitFor(() => expect(screen.getByText(/Found/i)).toBeInTheDocument(), { timeout: 3000 });
    fireEvent.click(screen.getByText(/Import 1 transaction/i));
    await waitFor(() => expect(screen.getByText(/Import complete/i)).toBeInTheDocument());
    expect(screen.getByText(/Close/i)).toBeInTheDocument();
  });
});

describe('PdfImportModal – parse errors', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows error when no transactions found', async () => {
    const { extractPdfText, parsePdfText } = await import('../../utils/pdfImport');
    vi.mocked(extractPdfText).mockResolvedValue('text');
    vi.mocked(parsePdfText).mockReturnValue([]);

    renderWithStore(<PdfImportModal open={true} onClose={() => {}} />);
    await simulateFileUpload();
    await waitFor(() =>
      expect(screen.getByText(/No transactions found/i)).toBeInTheDocument(),
      { timeout: 3000 }
    );
  });

  it('shows error when PDF parsing throws', async () => {
    const { extractPdfText } = await import('../../utils/pdfImport');
    vi.mocked(extractPdfText).mockRejectedValue(new Error('PDF read error'));

    renderWithStore(<PdfImportModal open={true} onClose={() => {}} />);
    await simulateFileUpload();
    await waitFor(() =>
      expect(screen.getByText(/Failed to read PDF.*PDF read error/i)).toBeInTheDocument(),
      { timeout: 3000 }
    );
  });
});
