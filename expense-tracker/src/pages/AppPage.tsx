import { useState, useCallback } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { Upload, Trash2, CloudOff, CheckCircle2, Loader2 } from 'lucide-react';
import type { Transaction, AccountId } from '../types';
import { ACCOUNTS } from '../store/defaults';
import { useAppStore } from '../store/StoreContext';
import { today } from '../utils/dates';
import { getCurrencySymbol } from '../utils/money';

const QUEUE_KEY = 'app_pending_queue';

function loadQueue(): Transaction[] {
  try { return JSON.parse(localStorage.getItem(QUEUE_KEY) ?? '[]'); }
  catch { return []; }
}

function saveQueue(q: Transaction[]) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(q));
}

export function AppPage() {
  const { settings, serverConnected, uploadPending } = useAppStore();
  const { categories, currency } = settings;
  const expenseCategories = categories.filter(c => c.type === 'expense' || c.type === 'both');

  const [pending, setPending] = useState<Transaction[]>(loadQueue);
  const [account, setAccount] = useState<AccountId>('personal');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [categoryId, setCategoryId] = useState(expenseCategories[0]?.id ?? '');
  const [date, setDate] = useState(today());
  const [merchant, setMerchant] = useState('');
  const [error, setError] = useState('');
  const [uploading, setUploading] = useState(false);
  const [uploadResult, setUploadResult] = useState<string | null>(null);

  const updateQueue = useCallback((q: Transaction[]) => {
    setPending(q);
    saveQueue(q);
  }, []);

  const handleAdd = () => {
    const num = parseFloat(amount);
    if (!amount || isNaN(num) || num <= 0) { setError('Enter a valid amount'); return; }
    if (!description.trim()) { setError('Description is required'); return; }
    setError('');

    const now = new Date().toISOString();
    const tx: Transaction = {
      id: uuidv4(),
      type: 'expense',
      amount: num,
      currency,
      categoryId,
      description: description.trim(),
      merchant: merchant.trim() || undefined,
      date,
      tags: [],
      isRecurring: false,
      accountId: account,
      createdAt: now,
      updatedAt: now,
    };
    updateQueue([...pending, tx]);
    setAmount('');
    setDescription('');
    setMerchant('');
  };

  const handleRemove = (id: string) => {
    updateQueue(pending.filter(t => t.id !== id));
  };

  const handleUpload = async () => {
    if (pending.length === 0) return;
    if (!serverConnected) { setUploadResult('Not connected to server'); return; }
    setUploading(true);
    setUploadResult(null);
    try {
      const res = await uploadPending(pending);
      updateQueue([]);
      setUploadResult(`Uploaded ${res.uploaded} transaction${res.uploaded !== 1 ? 's' : ''}`);
    } catch (err) {
      setUploadResult(`Upload failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setUploading(false);
    }
  };

  const symbol = getCurrencySymbol(currency);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-8">
      {/* Header */}
      <header className="bg-indigo-600 text-white px-4 pt-safe-top pb-4">
        <div className="max-w-md mx-auto">
          <div className="flex items-center justify-between py-3">
            <div>
              <h1 className="text-xl font-bold">💰 Quick Add</h1>
              <p className="text-indigo-200 text-sm">Mobile expense entry</p>
            </div>
            <div className="flex items-center gap-2 text-sm">
              {serverConnected
                ? <span className="flex items-center gap-1 text-emerald-300"><CheckCircle2 size={14} /> Connected</span>
                : <span className="flex items-center gap-1 text-indigo-300"><CloudOff size={14} /> Offline</span>
              }
            </div>
          </div>

          {/* Account picker */}
          <div className="flex rounded-xl bg-indigo-700 p-1 gap-1">
            {ACCOUNTS.map(acc => (
              <button
                key={acc.id}
                onClick={() => setAccount(acc.id)}
                className={`flex-1 py-2 text-sm font-medium rounded-lg transition-colors ${
                  account === acc.id
                    ? 'bg-white text-indigo-700 shadow-sm'
                    : 'text-indigo-200 hover:text-white'
                }`}
              >
                {acc.icon} {acc.label}
              </button>
            ))}
          </div>
        </div>
      </header>

      <div className="max-w-md mx-auto px-4 py-4 space-y-4">
        {/* Add form */}
        <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-sm p-4 space-y-3">
          <h2 className="font-semibold text-gray-900 dark:text-white">Add Expense</h2>

          {/* Amount */}
          <div className="flex items-center gap-2 rounded-xl border-2 border-gray-200 dark:border-gray-600 px-3 focus-within:border-indigo-500 transition-colors">
            <span className="text-gray-400 font-medium">{symbol}</span>
            <input
              type="number"
              min="0"
              step="0.01"
              placeholder="0.00"
              value={amount}
              onChange={e => setAmount(e.target.value)}
              className="flex-1 py-3 text-xl font-bold text-gray-900 dark:text-white bg-transparent outline-none"
            />
          </div>

          {/* Description */}
          <input
            type="text"
            placeholder="What was this for?"
            value={description}
            onChange={e => setDescription(e.target.value)}
            className="w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />

          {/* Merchant */}
          <input
            type="text"
            placeholder="Merchant (optional)"
            value={merchant}
            onChange={e => setMerchant(e.target.value)}
            className="w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />

          {/* Category + Date */}
          <div className="flex gap-2">
            <select
              value={categoryId}
              onChange={e => setCategoryId(e.target.value)}
              className="flex-1 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              {expenseCategories.map(c => (
                <option key={c.id} value={c.id}>{c.icon} {c.name}</option>
              ))}
            </select>
            <input
              type="date"
              value={date}
              onChange={e => setDate(e.target.value)}
              className="flex-1 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          {error && <p className="text-red-500 text-sm">{error}</p>}

          <button
            onClick={handleAdd}
            className="w-full py-3 bg-indigo-500 hover:bg-indigo-600 text-white font-semibold rounded-xl transition-colors"
          >
            + Add to queue
          </button>
        </div>

        {/* Pending list */}
        {pending.length > 0 && (
          <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-sm p-4 space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="font-semibold text-gray-900 dark:text-white">
                Pending ({pending.length})
              </h2>
              <button
                onClick={handleUpload}
                disabled={uploading || !serverConnected}
                className="flex items-center gap-2 px-4 py-2 bg-emerald-500 hover:bg-emerald-600 disabled:opacity-50 text-white text-sm font-medium rounded-xl transition-colors"
              >
                {uploading ? <Loader2 size={14} className="animate-spin" /> : <Upload size={14} />}
                Upload
              </button>
            </div>

            {uploadResult && (
              <p className={`text-sm ${uploadResult.startsWith('Upload failed') || uploadResult.startsWith('Not') ? 'text-red-500' : 'text-emerald-600'}`}>
                {uploadResult}
              </p>
            )}

            <ul className="space-y-2">
              {pending.map(tx => {
                const cat = categories.find(c => c.id === tx.categoryId);
                return (
                  <li key={tx.id} className="flex items-center gap-3 py-2 border-b border-gray-100 dark:border-gray-700 last:border-0">
                    <span className="text-xl">{cat?.icon ?? '📦'}</span>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 dark:text-white truncate">{tx.description}</p>
                      <p className="text-xs text-gray-400">{tx.date} · {ACCOUNTS.find(a => a.id === tx.accountId)?.label}</p>
                    </div>
                    <span className="text-sm font-semibold text-red-500 whitespace-nowrap">
                      -{symbol}{tx.amount.toFixed(2)}
                    </span>
                    <button onClick={() => handleRemove(tx.id)} className="text-gray-300 hover:text-red-500 transition-colors">
                      <Trash2 size={16} />
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>
        )}

        {pending.length === 0 && (
          <div className="text-center py-12 text-gray-400">
            <p className="text-4xl mb-2">📋</p>
            <p className="text-sm">No pending expenses.<br />Add some above!</p>
          </div>
        )}
      </div>
    </div>
  );
}
