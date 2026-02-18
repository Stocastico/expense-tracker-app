import { useState, useMemo } from 'react';
import { Plus, Trash2, AlertTriangle, CheckCircle } from 'lucide-react';
import { useAppStore } from '../store/StoreContext';
import { Card } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { EmptyState } from '../components/ui/EmptyState';
import { formatCurrency } from '../utils/money';
import { monthKey } from '../utils/dates';
import { getCurrencySymbol } from '../utils/money';

function BudgetForm({ onClose }: { onClose: () => void }) {
  const { settings, addBudget } = useAppStore();
  const { categories, currency } = settings;
  const expCats = categories.filter(c => c.type === 'expense' || c.type === 'both');
  const [categoryId, setCategoryId] = useState(expCats[0]?.id ?? '');
  const [amount, setAmount] = useState('');
  const [period, setPeriod] = useState<'monthly' | 'yearly'>('monthly');
  const [error, setError] = useState('');

  const handleSave = () => {
    const num = parseFloat(amount);
    if (!num || num <= 0) { setError('Enter a valid amount'); return; }
    addBudget({ categoryId, amount: num, currency, period });
    onClose();
  };

  return (
    <div className="space-y-4">
      <Select
        label="Category"
        value={categoryId}
        onChange={e => setCategoryId(e.target.value)}
        options={expCats.map(c => ({ value: c.id, label: `${c.icon} ${c.name}` }))}
      />
      <Input
        label="Budget amount"
        type="number"
        min="0"
        step="0.01"
        value={amount}
        onChange={e => setAmount(e.target.value)}
        prefix={getCurrencySymbol(currency)}
        error={error}
      />
      <Select
        label="Period"
        value={period}
        onChange={e => setPeriod(e.target.value as 'monthly' | 'yearly')}
        options={[{ value: 'monthly', label: 'Monthly' }, { value: 'yearly', label: 'Yearly' }]}
      />
      <div className="flex gap-2">
        <Button variant="secondary" fullWidth onClick={onClose}>Cancel</Button>
        <Button variant="primary" fullWidth onClick={handleSave}>Save Budget</Button>
      </div>
    </div>
  );
}

export function BudgetsPage() {
  const { budgets, transactions, settings, deleteBudget } = useAppStore();
  const { currency, categories } = settings;
  const [addOpen, setAddOpen] = useState(false);

  const currentMonth = monthKey(new Date().toISOString());

  const budgetData = useMemo(() => {
    return budgets.map(b => {
      const cat = categories.find(c => c.id === b.categoryId);
      const monthTxs = transactions.filter(t =>
        t.type === 'expense' &&
        t.categoryId === b.categoryId &&
        (b.period === 'monthly' ? monthKey(t.date) === currentMonth : t.date.startsWith(currentMonth.substring(0, 4)))
      );
      const spent = monthTxs.reduce((s, t) => s + t.amount, 0);
      const remaining = b.amount - spent;
      const percentage = b.amount > 0 ? (spent / b.amount) * 100 : 0;
      return { budget: b, cat, spent, remaining, percentage };
    });
  }, [budgets, transactions, categories, currentMonth]);

  const totalBudgeted = budgetData.reduce((s, d) => s + d.budget.amount, 0);
  const totalSpent = budgetData.reduce((s, d) => s + d.spent, 0);
  const overBudgetCount = budgetData.filter(d => d.percentage > 100).length;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Budgets</h1>
          <p className="text-sm text-gray-500 dark:text-gray-400">
            {formatCurrency(totalSpent, currency)} of {formatCurrency(totalBudgeted, currency)} used
          </p>
        </div>
        <Button onClick={() => setAddOpen(true)} size="sm">
          <Plus size={14} />
          Add budget
        </Button>
      </div>

      {overBudgetCount > 0 && (
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-700 rounded-2xl p-3 flex items-center gap-2">
          <AlertTriangle size={16} className="text-red-500 flex-shrink-0" />
          <p className="text-sm text-red-700 dark:text-red-300">
            You've exceeded {overBudgetCount} budget{overBudgetCount > 1 ? 's' : ''} this month.
          </p>
        </div>
      )}

      {budgetData.length === 0 ? (
        <EmptyState
          icon="🎯"
          title="No budgets set"
          description="Set spending limits per category to stay on track."
          action={
            <Button onClick={() => setAddOpen(true)}>
              <Plus size={14} />
              Create your first budget
            </Button>
          }
        />
      ) : (
        <div className="space-y-3">
          {budgetData.map(({ budget, cat, spent, remaining, percentage }) => {
            const over = percentage > 100;
            const warning = percentage >= 80 && !over;
            const barColor = over ? 'bg-red-500' : warning ? 'bg-amber-500' : 'bg-emerald-500';
            const statusColor = over ? 'text-red-500' : warning ? 'text-amber-500' : 'text-emerald-500';

            return (
              <Card key={budget.id} className="p-4">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <span className="text-xl">{cat?.icon ?? '📦'}</span>
                    <div>
                      <p className="text-sm font-semibold text-gray-900 dark:text-white">{cat?.name ?? 'Unknown'}</p>
                      <p className="text-xs text-gray-500 dark:text-gray-400 capitalize">{budget.period}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {over ? (
                      <AlertTriangle size={16} className="text-red-500" />
                    ) : (
                      <CheckCircle size={16} className="text-emerald-500" />
                    )}
                    <button
                      onClick={() => deleteBudget(budget.id)}
                      className="p-1.5 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-gray-400 hover:text-red-500 transition-colors"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>

                {/* Progress bar */}
                <div className="h-2.5 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden mb-2">
                  <div
                    className={`h-full rounded-full transition-all ${barColor}`}
                    style={{ width: `${Math.min(100, percentage)}%` }}
                  />
                </div>

                <div className="flex justify-between text-xs">
                  <span className={`font-medium ${statusColor}`}>
                    {formatCurrency(spent, currency)} spent
                  </span>
                  <span className="text-gray-500 dark:text-gray-400">
                    {over
                      ? `${formatCurrency(Math.abs(remaining), currency)} over`
                      : `${formatCurrency(remaining, currency)} left`}
                    {' · '}{budget.amount > 0 ? percentage.toFixed(0) : 0}%
                  </span>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      <Modal open={addOpen} onClose={() => setAddOpen(false)} title="Set Budget">
        <BudgetForm onClose={() => setAddOpen(false)} />
      </Modal>
    </div>
  );
}
