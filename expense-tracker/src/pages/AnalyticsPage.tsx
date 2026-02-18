import { useMemo, useState } from 'react';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, LineChart, Line, Legend,
} from 'recharts';
import { useAppStore } from '../store/StoreContext';
import { Card } from '../components/ui/Card';
import { formatCurrency } from '../utils/money';
import { lastNMonths, monthLabel, monthKey } from '../utils/dates';
import { getMonthStats, getCategoryStats, predictNextMonth, getSpendingTrend } from '../utils/stats';
import { TrendingDown, TrendingUp, Target } from 'lucide-react';

const COLORS = [
  '#6366f1', '#f43f5e', '#10b981', '#f59e0b', '#3b82f6',
  '#8b5cf6', '#ec4899', '#14b8a6', '#f97316', '#06b6d4',
  '#84cc16', '#a855f7',
];

function CustomTooltip({ active, payload, label, currency }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-3 border border-gray-100 dark:border-gray-700 text-sm">
      <p className="font-medium text-gray-700 dark:text-gray-300 mb-1">{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} style={{ color: p.color }} className="text-xs">
          {p.name}: {formatCurrency(p.value, currency)}
        </p>
      ))}
    </div>
  );
}

export function AnalyticsPage() {
  const { transactions, settings, currentAccount } = useAppStore();
  const { currency, categories } = settings;
  const [monthCount, setMonthCount] = useState(6);

  const accountTransactions = useMemo(
    () => transactions.filter(t => !t.accountId || t.accountId === currentAccount),
    [transactions, currentAccount],
  );

  const months = useMemo(() => lastNMonths(monthCount), [monthCount]);
  const monthStats = useMemo(() => getMonthStats(accountTransactions, months), [accountTransactions, months]);

  const currentMonthKey = monthKey(new Date().toISOString());
  const currentMonthTxs = useMemo(
    () => accountTransactions.filter(t => monthKey(t.date) === currentMonthKey && t.type === 'expense'),
    [accountTransactions, currentMonthKey]
  );

  const categoryStats = useMemo(
    () => getCategoryStats(currentMonthTxs),
    [currentMonthTxs]
  );

  const pieData = useMemo(() => categoryStats.map(s => {
    const cat = categories.find(c => c.id === s.categoryId);
    return { name: `${cat?.icon ?? ''} ${cat?.name ?? s.categoryId}`, value: s.total };
  }), [categoryStats, categories]);

  const trend = useMemo(() => getSpendingTrend(monthStats), [monthStats]);
  const prediction = useMemo(() => predictNextMonth(monthStats), [monthStats]);

  // Savings rate
  const totalIncome = useMemo(() => monthStats.reduce((s, m) => s + m.income, 0), [monthStats]);
  const totalExpenses = useMemo(() => monthStats.reduce((s, m) => s + m.expenses, 0), [monthStats]);
  const savingsRate = totalIncome > 0 ? ((totalIncome - totalExpenses) / totalIncome) * 100 : 0;

  const chartData = monthStats.map(m => ({
    month: monthLabel(m.month),
    Income: m.income,
    Expenses: m.expenses,
    Net: m.net,
  }));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Analytics</h1>
          <p className="text-sm text-gray-500 dark:text-gray-400">Your spending insights</p>
        </div>
        <div className="flex gap-1 bg-gray-100 dark:bg-gray-700 rounded-xl p-1">
          {([3, 6, 12] as const).map(n => (
            <button
              key={n}
              onClick={() => setMonthCount(n)}
              className={`px-3 py-1 text-xs font-medium rounded-lg transition-colors ${
                monthCount === n ? 'bg-white dark:bg-gray-600 text-gray-900 dark:text-white shadow-sm' : 'text-gray-500 dark:text-gray-400'
              }`}
            >
              {n}M
            </button>
          ))}
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-3">
        <Card className="p-3 text-center">
          <div className={`flex items-center justify-center gap-1 text-sm font-bold mb-0.5 ${trend <= 0 ? 'text-emerald-500' : 'text-red-500'}`}>
            {trend <= 0 ? <TrendingDown size={14} /> : <TrendingUp size={14} />}
            {Math.abs(trend).toFixed(1)}%
          </div>
          <p className="text-xs text-gray-500 dark:text-gray-400">vs last month</p>
        </Card>
        <Card className="p-3 text-center">
          <div className="text-sm font-bold text-indigo-500 mb-0.5">
            {formatCurrency(prediction, currency)}
          </div>
          <p className="text-xs text-gray-500 dark:text-gray-400">Predicted</p>
        </Card>
        <Card className="p-3 text-center">
          <div className={`text-sm font-bold mb-0.5 ${savingsRate >= 20 ? 'text-emerald-500' : savingsRate >= 0 ? 'text-amber-500' : 'text-red-500'}`}>
            {savingsRate.toFixed(1)}%
          </div>
          <p className="text-xs text-gray-500 dark:text-gray-400">Savings rate</p>
        </Card>
      </div>

      {/* Monthly bar chart */}
      <Card className="p-4">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-4">Monthly Overview</h2>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={chartData} barSize={12} barGap={4}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
            <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
            <YAxis hide />
            <Tooltip content={<CustomTooltip currency={currency} />} />
            <Legend iconSize={8} wrapperStyle={{ fontSize: 11 }} />
            <Bar dataKey="Expenses" fill="#f43f5e" radius={[4, 4, 0, 0]} />
            <Bar dataKey="Income" fill="#10b981" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </Card>

      {/* Net line chart */}
      <Card className="p-4">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-4">Net Balance Trend</h2>
        <ResponsiveContainer width="100%" height={160}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
            <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
            <YAxis hide />
            <Tooltip content={<CustomTooltip currency={currency} />} />
            <Line dataKey="Net" stroke="#6366f1" strokeWidth={2.5} dot={{ r: 3 }} activeDot={{ r: 5 }} />
          </LineChart>
        </ResponsiveContainer>
      </Card>

      {/* Pie chart — current month by category */}
      {pieData.length > 0 && (
        <Card className="p-4">
          <h2 className="font-semibold text-gray-900 dark:text-white mb-4">This Month by Category</h2>
          <div className="flex flex-col sm:flex-row items-center gap-4">
            <ResponsiveContainer width="100%" height={180}>
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={80}
                  paddingAngle={3}
                  dataKey="value"
                >
                  {pieData.map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(v: number | string | undefined) => formatCurrency(Number(v ?? 0), currency)} />
              </PieChart>
            </ResponsiveContainer>
          </div>
          {/* Legend */}
          <div className="space-y-2 mt-2">
            {categoryStats.slice(0, 8).map((s, i) => {
              const cat = categories.find(c => c.id === s.categoryId);
              return (
                <div key={s.categoryId} className="flex items-center gap-2">
                  <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: COLORS[i % COLORS.length] }} />
                  <span className="text-xs text-gray-600 dark:text-gray-300 flex-1 truncate">
                    {cat?.icon} {cat?.name ?? s.categoryId}
                  </span>
                  <span className="text-xs font-medium text-gray-900 dark:text-white">
                    {formatCurrency(s.total, currency)}
                  </span>
                  <span className="text-xs text-gray-400 w-10 text-right">
                    {s.percentage.toFixed(1)}%
                  </span>
                </div>
              );
            })}
          </div>
        </Card>
      )}

      {/* Savings rate visual */}
      <Card className="p-4">
        <div className="flex items-center gap-2 mb-3">
          <Target size={16} className="text-indigo-500" />
          <h2 className="font-semibold text-gray-900 dark:text-white">Savings Rate</h2>
          <span className="text-xs text-gray-500 dark:text-gray-400 ml-auto">Target: 20%</span>
        </div>
        <div className="h-3 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
          <div
            className={`h-full rounded-full transition-all ${savingsRate >= 20 ? 'bg-emerald-500' : savingsRate >= 10 ? 'bg-amber-500' : 'bg-red-500'}`}
            style={{ width: `${Math.max(0, Math.min(100, savingsRate))}%` }}
          />
        </div>
        <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400 mt-1">
          <span>0%</span>
          <span className={savingsRate >= 20 ? 'text-emerald-500 font-medium' : ''}>{savingsRate.toFixed(1)}%</span>
          <span>100%</span>
        </div>
      </Card>
    </div>
  );
}
