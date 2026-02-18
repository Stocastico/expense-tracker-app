import { useState, useRef } from 'react';
import { FileText, Loader2, Upload, Check, X, AlertCircle } from 'lucide-react';
import { extractPdfText, parsePdfText, entriesToTransactions } from '../../utils/pdfImport';
import type { ParsedEntry } from '../../utils/pdfImport';
import { useAppStore } from '../../store/StoreContext';
import { ACCOUNTS } from '../../store/defaults';
import type { AccountId } from '../../types';
import { Modal } from '../ui/Modal';

interface PdfImportModalProps {
  open: boolean;
  onClose: () => void;
}

type Step = 'pick' | 'parsing' | 'review' | 'done';

export function PdfImportModal({ open, onClose }: PdfImportModalProps) {
  const { settings, currentAccount, addTransaction } = useAppStore();
  const { categories, currency } = settings;
  const expenseCategories = categories.filter(c => c.type === 'expense' || c.type === 'both');

  const fileRef = useRef<HTMLInputElement>(null);
  const [step, setStep] = useState<Step>('pick');
  const [parseError, setParseError] = useState('');
  const [entries, setEntries] = useState<ParsedEntry[]>([]);
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [defaultCategory, setDefaultCategory] = useState(expenseCategories[0]?.id ?? '');
  const [account, setAccount] = useState<AccountId>(currentAccount);

  const handleFile = async (file: File) => {
    setParseError('');
    setStep('parsing');
    try {
      const text = await extractPdfText(file);
      const parsed = parsePdfText(text);
      if (parsed.length === 0) {
        setParseError('No transactions found. The PDF format may not be supported.');
        setStep('pick');
        return;
      }
      setEntries(parsed);
      setSelected(new Set(parsed.map((_, i) => i)));
      setStep('review');
    } catch (err) {
      setParseError(`Failed to read PDF: ${err instanceof Error ? err.message : 'Unknown error'}`);
      setStep('pick');
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) handleFile(file);
    e.target.value = '';
  };

  const toggleAll = () => {
    if (selected.size === entries.length) setSelected(new Set());
    else setSelected(new Set(entries.map((_, i) => i)));
  };

  const toggleOne = (i: number) => {
    const next = new Set(selected);
    if (next.has(i)) next.delete(i); else next.add(i);
    setSelected(next);
  };

  const handleImport = () => {
    const toImport = entries.filter((_, i) => selected.has(i));
    const txs = entriesToTransactions(toImport, { currency, accountId: account, categoryId: defaultCategory });
    for (const tx of txs) {
      // addTransaction expects Omit<Transaction, 'id' | 'createdAt' | 'updatedAt'>
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { id, createdAt, updatedAt, ...rest } = tx;
      addTransaction(rest);
    }
    setStep('done');
  };

  const handleClose = () => {
    setStep('pick');
    setEntries([]);
    setSelected(new Set());
    setParseError('');
    onClose();
  };

  return (
    <Modal open={open} onClose={handleClose} title="Import PDF Statement">
      {step === 'pick' && (
        <div className="space-y-4">
          <p className="text-sm text-gray-600 dark:text-gray-400">
            Upload a credit card or bank statement PDF. Transactions will be extracted automatically.
          </p>

          <button
            onClick={() => fileRef.current?.click()}
            className="w-full py-8 flex flex-col items-center gap-3 border-2 border-dashed border-gray-200 dark:border-gray-600 rounded-2xl text-gray-500 dark:text-gray-400 hover:border-indigo-400 hover:text-indigo-500 transition-colors"
          >
            <FileText size={32} />
            <span className="font-medium">Click to select PDF file</span>
            <span className="text-xs">Supports most bank/credit card statements</span>
          </button>
          <input ref={fileRef} type="file" accept="application/pdf" className="hidden" onChange={handleFileChange} />

          {parseError && (
            <div className="flex items-start gap-2 p-3 bg-red-50 dark:bg-red-900/20 rounded-xl text-red-600 dark:text-red-400 text-sm">
              <AlertCircle size={16} className="mt-0.5 shrink-0" />
              {parseError}
            </div>
          )}
        </div>
      )}

      {step === 'parsing' && (
        <div className="py-12 flex flex-col items-center gap-4 text-gray-500">
          <Loader2 size={32} className="animate-spin text-indigo-500" />
          <p className="font-medium">Reading PDF...</p>
        </div>
      )}

      {step === 'review' && (
        <div className="space-y-4">
          <p className="text-sm text-gray-600 dark:text-gray-400">
            Found <strong>{entries.length}</strong> potential transactions. Review and select which to import.
          </p>

          {/* Options */}
          <div className="flex gap-2">
            <div className="flex-1">
              <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Default category</label>
              <select
                value={defaultCategory}
                onChange={e => setDefaultCategory(e.target.value)}
                className="mt-1 w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                {expenseCategories.map(c => (
                  <option key={c.id} value={c.id}>{c.icon} {c.name}</option>
                ))}
              </select>
            </div>
            <div className="flex-1">
              <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Account</label>
              <select
                value={account}
                onChange={e => setAccount(e.target.value as AccountId)}
                className="mt-1 w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                {ACCOUNTS.map(a => (
                  <option key={a.id} value={a.id}>{a.icon} {a.label}</option>
                ))}
              </select>
            </div>
          </div>

          {/* Select all */}
          <div className="flex items-center justify-between text-sm">
            <button onClick={toggleAll} className="text-indigo-500 hover:underline">
              {selected.size === entries.length ? 'Deselect all' : 'Select all'}
            </button>
            <span className="text-gray-400">{selected.size} of {entries.length} selected</span>
          </div>

          {/* List */}
          <ul className="max-h-72 overflow-y-auto space-y-1 rounded-xl border border-gray-100 dark:border-gray-700 divide-y divide-gray-100 dark:divide-gray-700">
            {entries.map((e, i) => (
              <li
                key={i}
                onClick={() => toggleOne(i)}
                className={`flex items-center gap-3 px-3 py-2.5 cursor-pointer transition-colors ${
                  selected.has(i) ? 'bg-indigo-50 dark:bg-indigo-900/20' : 'hover:bg-gray-50 dark:hover:bg-gray-700/50'
                }`}
              >
                <div className={`w-5 h-5 rounded border-2 flex items-center justify-center shrink-0 transition-colors ${
                  selected.has(i) ? 'bg-indigo-500 border-indigo-500' : 'border-gray-300 dark:border-gray-600'
                }`}>
                  {selected.has(i) && <Check size={12} className="text-white" />}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 dark:text-white truncate">{e.description}</p>
                  <p className="text-xs text-gray-400">{e.date}</p>
                </div>
                <span className="text-sm font-semibold text-gray-700 dark:text-gray-300 whitespace-nowrap">
                  {e.amount.toFixed(2)}
                </span>
              </li>
            ))}
          </ul>

          <div className="flex gap-2 pt-2">
            <button onClick={handleClose} className="flex-1 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-400 text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
              Cancel
            </button>
            <button
              onClick={handleImport}
              disabled={selected.size === 0}
              className="flex-1 py-2.5 bg-indigo-500 hover:bg-indigo-600 disabled:opacity-50 text-white text-sm font-medium rounded-xl transition-colors flex items-center justify-center gap-2"
            >
              <Upload size={16} />
              Import {selected.size} transaction{selected.size !== 1 ? 's' : ''}
            </button>
          </div>
        </div>
      )}

      {step === 'done' && (
        <div className="py-12 flex flex-col items-center gap-4 text-center">
          <div className="w-16 h-16 bg-emerald-100 dark:bg-emerald-900/30 rounded-full flex items-center justify-center">
            <Check size={32} className="text-emerald-500" />
          </div>
          <div>
            <p className="font-semibold text-gray-900 dark:text-white">Import complete!</p>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
              {selected.size} transaction{selected.size !== 1 ? 's were' : ' was'} added.
            </p>
          </div>
          <button
            onClick={handleClose}
            className="px-6 py-2.5 bg-indigo-500 hover:bg-indigo-600 text-white text-sm font-medium rounded-xl transition-colors flex items-center gap-2"
          >
            <X size={16} /> Close
          </button>
        </div>
      )}
    </Modal>
  );
}
