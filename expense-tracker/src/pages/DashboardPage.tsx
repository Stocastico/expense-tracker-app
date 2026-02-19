import { useMemo } from 'react';
import { TrendingDown, TrendingUp, Wallet, ArrowRight, Sparkles } from 'lucide-react';
import { format, parseISO, startOfMonth, endOfMonth, isWithinInterval } from 'date-fns';
import { useAppStore } from '../store/StoreContext';
import { Card } from '../components/ui/Card';
import { TransactionItem } from '../components/transactions/TransactionItem';
import { EmptyState } from '../components/ui/EmptyState';
import { formatCurrency } from '../utils/money';

interface DashboardPageProps {
  onNavigate: (page: 'transactions' | 'analytics' | 'budgets' | 'settings') => void;
}

function MiniStatCard({ label, value, icon, gradient }: {
  label: string; value: string; icon: React.ReactNode; gradient: string;
}) {
  return (
    <div className={`relative overflow-hidden rounded-3xl p-4 ${gradient} text-white shadow-lg`}>
      {/* Decorative circle */}
      <div className="absolute -right-3 -top-3 w-16 h-16 bg-white/10 rounded-full" />
      <div className="absolute -right-1 -bottom-4 w-10 h-10 bg-white/10 rounded-full" />
      <div className="relative z-10">
        <div className="flex items-center justify-between mb-2">
          <span className="text-xs font-medium text-white/70">{label}</span>
          <div className="w-7 h-7 bg-white/20 rounded-xl flex items-center justify-center">
            {icon}
          </div>
        </div>
        <p className="text-lg font-bold leading-tight">{value}</p>
      </div>
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

  // Spending progress this month (expenses vs income)
  const spendingPct = totalIncome > 0 ? Math.min((totalExpenses / totalIncome) * 100, 100) : 0;

  return (
    <div className="space-y-4">

      {/* ── Hero Balance Card ──────────────────────────────────────────── */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-indigo-600 via-violet-600 to-purple-600 p-6 text-white shadow-xl shadow-indigo-300/30 dark:shadow-indigo-900/40">
        {/* Background blobs */}
        <div className="absolute -right-8 -top-8 w-40 h-40 bg-white/10 rounded-full blur-2xl" />
        <div className="absolute -left-4 -bottom-6 w-32 h-32 bg-purple-400/20 rounded-full blur-2xl" />
        <div className="absolute right-12 bottom-4 w-20 h-20 bg-indigo-300/20 rounded-full blur-xl" />

        <div className="relative z-10">
          <div className="flex items-center justify-between mb-4">
            <div>
              <p className="text-indigo-200 text-sm font-medium">{format(now, 'MMMM yyyy')}</p>
              <p className="text-xs text-indigo-300 mt-0.5">Net balance</p>
            </div>
            <div className="w-10 h-10 bg-white/20 rounded-2xl flex items-center justify-center">
              <Sparkles size={18} />
            </div>
          </div>

          <p className={`text-4xl font-bold tracking-tight mb-1 ${net < 0 ? 'text-rose-200' : 'text-white'}`}>
            {net < 0 ? '-' : ''}{formatCurrency(Math.abs(net), currency)}
          </p>
          <p className="text-indigo-200 text-sm">
            {net >= 0 ? '✨ Great job saving this month!' : '💸 Overspent this month'}
          </p>

          {/* Mini progress bar: expenses / income */}
          {totalIncome > 0 && (
            <div className="mt-4">
              <div className="flex justify-between text-xs text-indigo-200 mb-1.5">
                <span>Spent {Math.round(spendingPct)}% of income</span>
                <span>{formatCurrency(totalExpenses, currency)} / {formatCurrency(totalIncome, currency)}</span>
              </div>
              <div className="h-1.5 bg-white/20 rounded-full overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all duration-700 ${
                    spendingPct > 90 ? 'bg-rose-400' : spendingPct > 70 ? 'bg-amber-400' : 'bg-emerald-400'
                  }`}
                  style={{ width: `${spendingPct}%` }}
                />
              </div>
            </div>
          )}
        </div>
      </div>

      {/* ── Budget alerts ──────────────────────────────────────────────── */}
      {budgetAlerts.length > 0 && (
        <div className="bg-amber-50/80 dark:bg-amber-900/20 backdrop-blur-sm border border-amber-200/60 dark:border-amber-700/40 rounded-3xl p-4 space-y-1.5">
          <p className="text-sm font-semibold text-amber-800 dark:text-amber-300 flex items-center gap-1.5">
            ⚠️ Budget alerts
          </p>
          {budgetAlerts.map(b => {
            const cat = categories.find(c => c.id === b.categoryId);
            const spent = thisMonthTxs
              .filter(t => t.type === 'expense' && t.categoryId === b.categoryId)
              .reduce((s, t) => s + t.amount, 0);
            const pct = Math.round((spent / b.amount) * 100);
            return (
              <p key={b.id} className="text-xs text-amber-700 dark:text-amber-400 flex items-center gap-1.5">
                <span className="text-base">{cat?.icon}</span>
                <span>{cat?.name}: {formatCurrency(spent, currency)} / {formatCurrency(b.amount, currency)}</span>
                <span className={`ml-auto font-bold ${pct >= 100 ? 'text-red-500' : 'text-amber-600'}`}>{pct}%</span>
              </p>
            );
          })}
        </div>
      )}

      {/* ── Mini stat grid ─────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3">
        <MiniStatCard
          label="Spent this month"
          value={formatCurrency(totalExpenses, currency)}
          gradient="bg-gradient-to-br from-rose-500 to-pink-600"
          icon={<TrendingDown size={14} />}
        />
        <MiniStatCard
          label="Earned this month"
          value={formatCurrency(totalIncome, currency)}
          gradient="bg-gradient-to-br from-emerald-500 to-teal-600"
          icon={<TrendingUp size={14} />}
        />
        <MiniStatCard
          label="Net cash flow"
          value={formatCurrency(Math.abs(net), currency)}
          gradient={net >= 0
            ? 'bg-gradient-to-br from-blue-500 to-indigo-600'
            : 'bg-gradient-to-br from-orange-500 to-amber-600'}
          icon={<Wallet size={14} />}
        />
        <MiniStatCard
          label="Top category"
          value={topCategory ? `${topCategory.icon} ${topCategory.name}` : '—'}
          gradient="bg-gradient-to-br from-violet-500 to-purple-600"
          icon={<span className="text-sm">{topCategory?.icon ?? '🏷️'}</span>}
        />
      </div>

      {/* ── Recent transactions ────────────────────────────────────────── */}
      <Card>
        <div className="flex items-center justify-between px-5 pt-5 pb-2">
          <h2 className="font-bold text-gray-900 dark:text-white">Recent</h2>
          <button
            onClick={() => onNavigate('transactions')}
            className="text-xs font-semibold text-indigo-500 flex items-center gap-1 hover:gap-2 transition-all duration-200 bg-indigo-50 dark:bg-indigo-900/30 px-3 py-1.5 rounded-xl"
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
          <div className="divide-y divide-gray-50/80 dark:divide-gray-700/30 pb-2">
            {recentTxs.map(tx => <TransactionItem key={tx.id} transaction={tx} />)}
          </div>
        )}
      </Card>
    </div>
  );
}
