import { useState } from 'react';
import { Edit2, Trash2, Repeat } from 'lucide-react';
import type { Transaction } from '../../types';
import { useAppStore } from '../../store/StoreContext';
import { formatCurrency } from '../../utils/money';
import { formatDate } from '../../utils/dates';
import { Modal } from '../ui/Modal';
import { TransactionForm } from './TransactionForm';
import { Button } from '../ui/Button';

interface TransactionItemProps {
  transaction: Transaction;
}

export function TransactionItem({ transaction: tx }: TransactionItemProps) {
  const { settings, deleteTransaction } = useAppStore();
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);

  const category = settings.categories.find(c => c.id === tx.categoryId);
  const isExpense = tx.type === 'expense';

  return (
    <>
      <div className="flex items-center gap-3 py-3 px-4 hover:bg-indigo-50/40 dark:hover:bg-indigo-900/10 transition-colors group">
        {/* Category icon */}
        <div className={`flex-shrink-0 w-11 h-11 rounded-2xl ${category?.color ?? 'bg-gray-400'} flex items-center justify-center text-lg shadow-sm`}>
          {category?.icon ?? '📦'}
        </div>

        {/* Details */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5">
            <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">{tx.description}</p>
            {tx.isRecurring && <Repeat size={11} className="text-indigo-400 flex-shrink-0" />}
          </div>
          <div className="flex items-center gap-1.5 mt-0.5">
            <p className="text-xs text-gray-400 dark:text-gray-500 truncate">{tx.merchant || category?.name}</p>
            <span className="text-gray-200 dark:text-gray-700 text-xs">·</span>
            <p className="text-xs text-gray-400 dark:text-gray-500 flex-shrink-0">{formatDate(tx.date, 'MMM d')}</p>
          </div>
          {tx.tags.length > 0 && (
            <div className="flex gap-1 mt-1 flex-wrap">
              {tx.tags.slice(0, 3).map(tag => (
                <span key={tag} className="text-[10px] font-medium text-indigo-500 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-900/30 px-1.5 py-0.5 rounded-md">
                  #{tag}
                </span>
              ))}
            </div>
          )}
        </div>

        {/* Amount + Actions */}
        <div className="flex items-center gap-1 flex-shrink-0">
          <span className={`text-sm font-bold tabular-nums ${
            isExpense ? 'text-rose-500 dark:text-rose-400' : 'text-emerald-500 dark:text-emerald-400'
          }`}>
            {isExpense ? '-' : '+'}{formatCurrency(tx.amount, tx.currency)}
          </span>
          <div className="flex gap-0.5 opacity-0 group-hover:opacity-100 transition-all duration-150 ml-1">
            <button
              onClick={() => setEditOpen(true)}
              className="p-1.5 rounded-xl hover:bg-indigo-100 dark:hover:bg-indigo-900/40 text-gray-400 hover:text-indigo-500 transition-colors"
            >
              <Edit2 size={13} />
            </button>
            <button
              onClick={() => setDeleteOpen(true)}
              className="p-1.5 rounded-xl hover:bg-rose-100 dark:hover:bg-rose-900/30 text-gray-400 hover:text-rose-500 transition-colors"
            >
              <Trash2 size={13} />
            </button>
          </div>
        </div>
      </div>

      <Modal open={editOpen} onClose={() => setEditOpen(false)} title="Edit Transaction">
        <TransactionForm transaction={tx} onClose={() => setEditOpen(false)} />
      </Modal>

      <Modal open={deleteOpen} onClose={() => setDeleteOpen(false)} title="Delete Transaction">
        <div className="space-y-4">
          <p className="text-gray-600 dark:text-gray-300">
            Delete <strong className="text-gray-900 dark:text-white">{tx.description}</strong>?
          </p>
          {tx.isRecurring && (
            <p className="text-sm text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 rounded-2xl p-3">
              This is a recurring transaction. Choose what to delete.
            </p>
          )}
          <div className="flex flex-col gap-2">
            <Button variant="danger" fullWidth onClick={() => { deleteTransaction(tx.id); setDeleteOpen(false); }}>
              Delete this one
            </Button>
            {tx.isRecurring && (
              <Button variant="danger" fullWidth onClick={() => { deleteTransaction(tx.id, true); setDeleteOpen(false); }}>
                Delete all recurring
              </Button>
            )}
            <Button variant="secondary" fullWidth onClick={() => setDeleteOpen(false)}>Cancel</Button>
          </div>
        </div>
      </Modal>
    </>
  );
}
