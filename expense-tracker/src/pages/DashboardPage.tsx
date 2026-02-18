import { useMemo } from 'react';
import { TrendingDown, TrendingUp, Wallet, ArrowRight } from 'lucide-react';
import { format, parseISO, startOfMonth, endOfMonth, isWithinInterval } from 'date-fns';
import { useAppStore } from '../store/StoreContext';
import { Card } from '../components/ui/Card';
import { TransactionItem } from '../components/transactions/TransactionItem';
import { EmptyState } from '../components/ui/EmptyState';
import { formatCurrency } from '../utils/money';

interface DashboardPageProps {
  onNavigate: (page: 'transactions' | 'analytics' | 'budgets' | 'settings') => void;
}

function StatCard({ label, value, sub, color, icon }: {
  label: string; value: string; sub?: string; color: string; icon: React.ReactNode;
}) {
  return (
    <div className={`rounded-2xl p-4 ${color} text-white flex flex-col gap-1`}>
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium opacity-80">{label}</span>
        <div className="opacity-80">{icon}</div>
      </div>
      <span className="text-xl font-bold">{value}</span>
      {sub && <span className="text-xs opacity-70">{sub}</span>}
    </div>
  );
}

export function DashboardPage({ onNavigate }: DashboardPageProps) {
  const { transactions, settings, budgets, currentAccount } = useAppStore();
  const { currency, categories } = settings;

  const accountTransactions = useMemo(
    () => transactions.filter(t => !t.accountId || t.accountId === currentAccount),
    [transactions, currentAccount],
  );

  const now = new Date();
  const monthStart = startOfMonth(now);
  const monthEnd = endOfMonth(now);

  const thisMonthTxs = useMemo(
    () => accountTransactions.filter(t => {
      try {
        return isWithinInterval(parseISO(t.date), { start: monthStart, end: monthEnd });
      } catch { return false; }
    }),
    [accountTransactions, monthStart, monthEnd]
  );

  const totalExpenses = useMemo(
    () => thisMonthTxs.filter(t => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [thisMonthTxs]
  );
  const totalIncome = useMemo(
    () => thisMonthTxs.filter(t => t.type === 'income').reduce((s, t) => s + t.amount, 0),
    [thisMonthTxs]
  );
  const net = totalIncome - totalExpenses;

  // Budget alerts
  const budgetAlerts = useMemo(() => {
    return budgets.filter(b => {
      const spent = thisMonthTxs
        .filter(t => t.type === 'expense' && t.categoryId === b.categoryId)
        .reduce((s, t) => s + t.amount, 0);
      return spent >= b.amount * 0.8;
    });
  }, [budgets, thisMonthTxs]);

  // Top category
  const topCategory = useMemo(() => {
    const map = new Map<string, number>();
    thisMonthTxs.filter(t => t.type === 'expense').forEach(t => {
      map.set(t.categoryId, (map.get(t.categoryId) ?? 0) + t.amount);
    });
    if (map.size === 0) return null;
    const [catId] = [...map.entries()].sort((a, b) => b[1] - a[1])[0];
    return categories.find(c => c.id === catId);
  }, [thisMonthTxs, categories]);

  const recentTxs = useMemo(
    () => [...accountTransactions].sort((a, b) => b.date.localeCompare(a.date)).slice(0, 5),
    [accountTransactions]
  );

  return (
    <div className="space-y-4">
      {/* Month title */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
          {format(now, 'MMMM yyyy')}
        </h1>
        <p className="text-sm text-gray-500 dark:text-gray-400">Your financial snapshot</p>
      </div>

      {/* Budget alerts */}
      {budgetAlerts.length > 0 && (
        <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700 rounded-2xl p-3 space-y-1">
          <p className="text-sm font-semibold text-amber-800 dark:text-amber-300">⚠️ Budget alerts</p>
          {budgetAlerts.map(b => {
            const cat = categories.find(c => c.id === b.categoryId);
            const spent = thisMonthTxs
              .filter(t => t.type === 'expense' && t.categoryId === b.categoryId)
              .reduce((s, t) => s + t.amount, 0);
            const pct = Math.round((spent / b.amount) * 100);
            return (
              <p key={b.id} className="text-xs text-amber-700 dark:text-amber-400">
                {cat?.icon} {cat?.name}: {formatCurrency(spent, currency)} of {formatCurrency(b.amount, currency)} ({pct}%)
              </p>
            );
          })}
        </div>
      )}

      {/* Stats grid */}
      <div className="grid grid-cols-2 gap-3">
        <StatCard
          label="Expenses this month"
          value={formatCurrency(totalExpenses, currency)}
          color="bg-gradient-to-br from-red-500 to-red-600"
          icon={<TrendingDown size={18} />}
        />
        <StatCard
          label="Income this month"
          value={formatCurrency(totalIncome, currency)}
          color="bg-gradient-to-br from-emerald-500 to-emerald-600"
          icon={<TrendingUp size={18} />}
        />
        <StatCard
          label="Net balance"
          value={formatCurrency(Math.abs(net), currency)}
          sub={net >= 0 ? 'You saved money!' : 'Overspent this month'}
          color={net >= 0 ? 'bg-gradient-to-br from-indigo-500 to-indigo-600' : 'bg-gradient-to-br from-orange-500 to-orange-600'}
          icon={<Wallet size={18} />}
        />
        <StatCard
          label="Top category"
          value={topCategory ? `${topCategory.icon} ${topCategory.name}` : 'None'}
          color="bg-gradient-to-br from-purple-500 to-purple-600"
          icon={<span className="text-base">{topCategory?.icon ?? '—'}</span>}
        />
      </div>

      {/* Recent transactions */}
      <Card>
        <div className="flex items-center justify-between px-4 pt-4 pb-2">
          <h2 className="font-semibold text-gray-900 dark:text-white">Recent transactions</h2>
          <button
            onClick={() => onNavigate('transactions')}
            className="text-xs text-indigo-500 flex items-center gap-1 hover:gap-2 transition-all"
          >
            See all <ArrowRight size={12} />
          </button>
        </div>
        {recentTxs.length === 0 ? (
          <EmptyState
            icon="💸"
            title="No transactions yet"
            description="Add your first expense or income to get started."
          />
        ) : (
          <div className="divide-y divide-gray-50 dark:divide-gray-700/50">
            {recentTxs.map(tx => <TransactionItem key={tx.id} transaction={tx} />)}
          </div>
        )}
      </Card>
    </div>
  );
}
