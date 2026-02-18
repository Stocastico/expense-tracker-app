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
      <div className="flex items-center gap-3 py-3 px-4 hover:bg-gray-50 dark:hover:bg-gray-700/50 rounded-xl transition-colors group">
        {/* Icon */}
        <div className={`flex-shrink-0 w-10 h-10 rounded-full ${category?.color ?? 'bg-gray-400'} flex items-center justify-center text-lg`}>
          {category?.icon ?? '📦'}
        </div>

        {/* Details */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1">
            <p className="text-sm font-medium text-gray-900 dark:text-white truncate">
              {tx.description}
            </p>
            {tx.isRecurring && <Repeat size={12} className="text-indigo-400 flex-shrink-0" />}
          </div>
          <div className="flex items-center gap-2 mt-0.5">
            <p className="text-xs text-gray-500 dark:text-gray-400">{tx.merchant || category?.name}</p>
            <span className="text-gray-300 dark:text-gray-600">·</span>
            <p className="text-xs text-gray-400 dark:text-gray-500">{formatDate(tx.date, 'MMM d')}</p>
          </div>
          {tx.tags.length > 0 && (
            <div className="flex gap-1 mt-1">
              {tx.tags.slice(0, 3).map(tag => (
                <span key={tag} className="text-xs text-indigo-500 dark:text-indigo-400">#{tag}</span>
              ))}
            </div>
          )}
        </div>

        {/* Amount + Actions */}
        <div className="flex items-center gap-2 flex-shrink-0">
          <span className={`text-sm font-semibold ${isExpense ? 'text-red-500' : 'text-emerald-500'}`}>
            {isExpense ? '-' : '+'}{formatCurrency(tx.amount, tx.currency)}
          </span>
          <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
            <button
              onClick={() => setEditOpen(true)}
              className="p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-600 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            >
              <Edit2 size={14} />
            </button>
            <button
              onClick={() => setDeleteOpen(true)}
              className="p-1.5 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-gray-400 hover:text-red-500"
            >
              <Trash2 size={14} />
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
            Are you sure you want to delete <strong>{tx.description}</strong>?
          </p>
          {tx.isRecurring && (
            <p className="text-sm text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 rounded-xl p-3">
              This is a recurring transaction. You can delete just this one or all future occurrences.
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
