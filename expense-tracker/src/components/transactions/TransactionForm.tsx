import { useState, useRef, useCallback } from 'react';
import { Camera, Upload, Loader2, RefreshCw, Tag, X } from 'lucide-react';
import type { Transaction, TransactionType, RecurringFrequency, AccountId } from '../../types';
import { useAppStore } from '../../store/StoreContext';
import { ACCOUNTS } from '../../store/defaults';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { Select } from '../ui/Select';
import { today } from '../../utils/dates';
import { guessCategory, extractOcrData } from '../../utils/smartCategory';
import { getCurrencySymbol } from '../../utils/money';

interface TransactionFormProps {
  transaction?: Transaction;
  onClose: () => void;
}

const RECURRING_OPTIONS: { value: RecurringFrequency; label: string }[] = [
  { value: 'daily',     label: 'Daily' },
  { value: 'weekly',    label: 'Weekly' },
  { value: 'biweekly',  label: 'Every 2 weeks' },
  { value: 'monthly',   label: 'Monthly' },
  { value: 'quarterly', label: 'Quarterly' },
  { value: 'yearly',    label: 'Yearly' },
];

export function TransactionForm({ transaction, onClose }: TransactionFormProps) {
  const { settings, currentAccount, addTransaction, updateTransaction } = useAppStore();
  const { categories, currency } = settings;
  const isEdit = !!transaction;

  const expenseCategories = categories.filter(c => c.type === 'expense' || c.type === 'both');
  const incomeCategories = categories.filter(c => c.type === 'income' || c.type === 'both');

  const [type, setType] = useState<TransactionType>(transaction?.type ?? 'expense');
  const [amount, setAmount] = useState(transaction?.amount?.toString() ?? '');
  const [description, setDescription] = useState(transaction?.description ?? '');
  const [merchant, setMerchant] = useState(transaction?.merchant ?? '');
  const [date, setDate] = useState(transaction?.date ?? today());
  const [categoryId, setCategoryId] = useState(
    transaction?.categoryId ?? (type === 'expense' ? expenseCategories[0]?.id : incomeCategories[0]?.id) ?? ''
  );
  const [txCurrency, setTxCurrency] = useState(transaction?.currency ?? currency);
  const [isRecurring, setIsRecurring] = useState(transaction?.isRecurring ?? false);
  const [recurringFreq, setRecurringFreq] = useState<RecurringFrequency>(transaction?.recurringFrequency ?? 'monthly');
  const [recurringEnd, setRecurringEnd] = useState(transaction?.recurringEndDate ?? '');
  const [tags, setTags] = useState<string[]>(transaction?.tags ?? []);
  const [tagInput, setTagInput] = useState('');
  const [notes, setNotes] = useState(transaction?.notes ?? '');
  const [accountId, setAccountId] = useState<AccountId>(transaction?.accountId ?? currentAccount);
  const [ocrLoading, setOcrLoading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const fileRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);

  const currentCategories = type === 'expense' ? expenseCategories : incomeCategories;

  const handleTypeChange = (t: TransactionType) => {
    setType(t);
    const cats = t === 'expense' ? expenseCategories : incomeCategories;
    setCategoryId(cats[0]?.id ?? '');
  };

  const handleDescriptionChange = (value: string) => {
    setDescription(value);
    if (!isEdit && value.length > 2) {
      const guessed = guessCategory(value + ' ' + merchant, categories, type);
      if (guessed) setCategoryId(guessed);
    }
  };

  const handleMerchantChange = (value: string) => {
    setMerchant(value);
    if (!isEdit && value.length > 2) {
      const guessed = guessCategory(value + ' ' + description, categories, type);
      if (guessed) setCategoryId(guessed);
    }
  };

  const addTag = () => {
    const t = tagInput.trim().toLowerCase();
    if (t && !tags.includes(t)) setTags([...tags, t]);
    setTagInput('');
  };

  const removeTag = (tag: string) => setTags(tags.filter(t => t !== tag));

  const processImage = useCallback(async (file: File) => {
    setOcrLoading(true);
    try {
      const { createWorker } = await import('tesseract.js');
      const worker = await createWorker('eng');
      const { data: { text } } = await worker.recognize(file);
      await worker.terminate();

      const extracted = extractOcrData(text);
      if (extracted.amount) setAmount(extracted.amount.toFixed(2));
      if (extracted.merchant) {
        setMerchant(extracted.merchant);
        const guessed = guessCategory(extracted.merchant + ' ' + (extracted.categoryHint ?? ''), categories, type);
        if (guessed) setCategoryId(guessed);
      }
      if (extracted.date) setDate(extracted.date);
    } catch (err) {
      console.error('OCR failed', err);
    } finally {
      setOcrLoading(false);
    }
  }, [categories, type]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) processImage(file);
    e.target.value = '';
  };

  const validate = (): boolean => {
    const errs: Record<string, string> = {};
    const num = parseFloat(amount);
    if (!amount || isNaN(num) || num <= 0) errs.amount = 'Enter a valid amount';
    if (!description.trim()) errs.description = 'Description is required';
    if (!date) errs.date = 'Date is required';
    if (!categoryId) errs.category = 'Select a category';
    setErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleSubmit = () => {
    if (!validate()) return;
    const txData = {
      type,
      amount: parseFloat(amount),
      currency: txCurrency,
      categoryId,
      description: description.trim(),
      merchant: merchant.trim() || undefined,
      date,
      tags,
      notes: notes.trim() || undefined,
      isRecurring,
      recurringFrequency: isRecurring ? recurringFreq : undefined,
      recurringEndDate: isRecurring && recurringEnd ? recurringEnd : undefined,
      accountId,
    };

    if (isEdit && transaction) {
      updateTransaction(transaction.id, txData);
    } else {
      addTransaction(txData);
    }
    onClose();
  };

  return (
    <div className="space-y-4">
      {/* Type toggle */}
      <div className="flex rounded-xl bg-gray-100 dark:bg-gray-700 p-1 gap-1">
        {(['expense', 'income'] as TransactionType[]).map(t => (
          <button
            key={t}
            onClick={() => handleTypeChange(t)}
            className={`flex-1 py-2 text-sm font-medium rounded-lg transition-colors capitalize ${
              type === t
                ? t === 'expense'
                  ? 'bg-red-500 text-white shadow-sm'
                  : 'bg-emerald-500 text-white shadow-sm'
                : 'text-gray-600 dark:text-gray-400 hover:text-gray-800'
            }`}
          >
            {t === 'expense' ? '💸 Expense' : '💵 Income'}
          </button>
        ))}
      </div>

      {/* OCR Buttons */}
      <div className="flex gap-2">
        <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={handleFileChange} />
        <input ref={cameraRef} type="file" accept="image/*" capture="environment" className="hidden" onChange={handleFileChange} />
        <button
          onClick={() => cameraRef.current?.click()}
          disabled={ocrLoading}
          className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl border-2 border-dashed border-gray-200 dark:border-gray-600 text-gray-500 dark:text-gray-400 text-sm hover:border-indigo-400 hover:text-indigo-500 transition-colors"
        >
          {ocrLoading ? <Loader2 size={16} className="animate-spin" /> : <Camera size={16} />}
          Scan receipt
        </button>
        <button
          onClick={() => fileRef.current?.click()}
          disabled={ocrLoading}
          className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl border-2 border-dashed border-gray-200 dark:border-gray-600 text-gray-500 dark:text-gray-400 text-sm hover:border-indigo-400 hover:text-indigo-500 transition-colors"
        >
          <Upload size={16} />
          Upload image
        </button>
      </div>
      {ocrLoading && (
        <p className="text-xs text-center text-indigo-500 flex items-center justify-center gap-1">
          <RefreshCw size={12} className="animate-spin" /> Reading receipt...
        </p>
      )}

      {/* Amount + Currency */}
      <div className="flex gap-2">
        <div className="flex-1">
          <Input
            label="Amount"
            type="number"
            min="0"
            step="0.01"
            placeholder="0.00"
            value={amount}
            onChange={e => setAmount(e.target.value)}
            prefix={getCurrencySymbol(txCurrency)}
            error={errors.amount}
          />
        </div>
        <div className="w-24">
          <Select
            label="Currency"
            value={txCurrency}
            onChange={e => setTxCurrency(e.target.value)}
            options={[
              { value: 'USD', label: 'USD' }, { value: 'EUR', label: 'EUR' },
              { value: 'GBP', label: 'GBP' }, { value: 'JPY', label: 'JPY' },
              { value: 'CAD', label: 'CAD' }, { value: 'AUD', label: 'AUD' },
              { value: 'CHF', label: 'CHF' }, { value: 'CNY', label: 'CNY' },
              { value: 'INR', label: 'INR' }, { value: 'BRL', label: 'BRL' },
            ]}
          />
        </div>
      </div>

      <Input
        label="Description"
        placeholder="What was this for?"
        value={description}
        onChange={e => handleDescriptionChange(e.target.value)}
        error={errors.description}
      />

      <Input
        label="Merchant / Payee (optional)"
        placeholder="e.g. Starbucks, Amazon"
        value={merchant}
        onChange={e => handleMerchantChange(e.target.value)}
      />

      <div className="flex gap-2">
        <div className="flex-1">
          <Input
            label="Date"
            type="date"
            value={date}
            onChange={e => setDate(e.target.value)}
            error={errors.date}
          />
        </div>
        <div className="flex-1">
          <Select
            label="Category"
            value={categoryId}
            onChange={e => setCategoryId(e.target.value)}
            error={errors.category}
            options={currentCategories.map(c => ({ value: c.id, label: `${c.icon} ${c.name}` }))}
          />
        </div>
      </div>

      {/* Tags */}
      <div className="flex flex-col gap-1">
        <label className="text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-1">
          <Tag size={14} /> Tags
        </label>
        <div className="flex gap-2">
          <input
            className="flex-1 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            placeholder="Add tag..."
            value={tagInput}
            onChange={e => setTagInput(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); addTag(); }}}
          />
          <Button variant="secondary" size="sm" onClick={addTag} type="button">Add</Button>
        </div>
        {tags.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-1">
            {tags.map(tag => (
              <span key={tag} className="flex items-center gap-1 bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300 text-xs px-2 py-1 rounded-full">
                #{tag}
                <button onClick={() => removeTag(tag)} className="hover:text-red-500"><X size={10} /></button>
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Notes */}
      <div className="flex flex-col gap-1">
        <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Notes (optional)</label>
        <textarea
          className="w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2.5 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
          rows={2}
          placeholder="Additional details..."
          value={notes}
          onChange={e => setNotes(e.target.value)}
        />
      </div>

      {/* Recurring */}
      <div className="rounded-xl border border-gray-200 dark:border-gray-700 p-3 space-y-3">
        <label className="flex items-center gap-3 cursor-pointer">
          <div
            onClick={() => setIsRecurring(!isRecurring)}
            className={`relative w-10 h-6 rounded-full transition-colors ${isRecurring ? 'bg-indigo-500' : 'bg-gray-200 dark:bg-gray-600'}`}
          >
            <div className={`absolute top-1 left-1 w-4 h-4 bg-white rounded-full shadow transition-transform ${isRecurring ? 'translate-x-4' : ''}`} />
          </div>
          <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Recurring transaction</span>
        </label>
        {isRecurring && (
          <div className="flex gap-2">
            <div className="flex-1">
              <Select
                label="Frequency"
                value={recurringFreq}
                onChange={e => setRecurringFreq(e.target.value as RecurringFrequency)}
                options={RECURRING_OPTIONS}
              />
            </div>
            <div className="flex-1">
              <Input
                label="End date (optional)"
                type="date"
                value={recurringEnd}
                onChange={e => setRecurringEnd(e.target.value)}
              />
            </div>
          </div>
        )}
      </div>

      {/* Account */}
      <div className="flex flex-col gap-1">
        <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Account</label>
        <div className="flex rounded-xl bg-gray-100 dark:bg-gray-700 p-1 gap-1">
          {ACCOUNTS.map(acc => (
            <button
              key={acc.id}
              type="button"
              onClick={() => setAccountId(acc.id)}
              className={`flex-1 py-2 text-sm font-medium rounded-lg transition-colors ${
                accountId === acc.id
                  ? 'bg-indigo-500 text-white shadow-sm'
                  : 'text-gray-600 dark:text-gray-400 hover:text-gray-800'
              }`}
            >
              {acc.icon} {acc.label}
            </button>
          ))}
        </div>
      </div>

      {/* Submit */}
      <div className="flex gap-2 pt-2">
        <Button variant="secondary" fullWidth onClick={onClose}>Cancel</Button>
        <Button variant="primary" fullWidth onClick={handleSubmit}>
          {isEdit ? 'Save Changes' : `Add ${type === 'expense' ? 'Expense' : 'Income'}`}
        </Button>
      </div>
    </div>
  );
}
