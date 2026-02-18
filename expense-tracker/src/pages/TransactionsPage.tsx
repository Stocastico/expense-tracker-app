import { useState, useMemo } from 'react';
import { Search, Filter, ChevronDown, FileText } from 'lucide-react';
import { useAppStore } from '../store/StoreContext';
import { Card } from '../components/ui/Card';
import { TransactionItem } from '../components/transactions/TransactionItem';
import { EmptyState } from '../components/ui/EmptyState';
import { PdfImportModal } from '../components/transactions/PdfImportModal';
import { monthKey, formatDate } from '../utils/dates';

type SortKey = 'date' | 'amount';
type SortDir = 'asc' | 'desc';

export function TransactionsPage() {
  const { transactions, settings, currentAccount } = useAppStore();
  const { categories } = settings;
  const accountTransactions = useMemo(
    () => transactions.filter(t => !t.accountId || t.accountId === currentAccount),
    [transactions, currentAccount],
  );

  const [search, setSearch] = useState('');
  const [filterType, setFilterType] = useState<'all' | 'expense' | 'income'>('all');
  const [filterCategory, setFilterCategory] = useState('all');
  const [filterMonth, setFilterMonth] = useState('all');
  const [sortKey, setSortKey] = useState<SortKey>('date');
  const [sortDir, setSortDir] = useState<SortDir>('desc');
  const [showFilters, setShowFilters] = useState(false);
  const [showPdfImport, setShowPdfImport] = useState(false);

  const months = useMemo(() => {
    const keys = new Set(accountTransactions.map(t => monthKey(t.date)));
    return [...keys].sort().reverse();
  }, [accountTransactions]);

  const filtered = useMemo(() => {
    let result = accountTransactions;

    if (search) {
      const q = search.toLowerCase();
      result = result.filter(t =>
        t.description.toLowerCase().includes(q) ||
        (t.merchant ?? '').toLowerCase().includes(q) ||
        t.tags.some(tag => tag.includes(q)) ||
        (t.notes ?? '').toLowerCase().includes(q)
      );
    }

    if (filterType !== 'all') result = result.filter(t => t.type === filterType);
    if (filterCategory !== 'all') result = result.filter(t => t.categoryId === filterCategory);
    if (filterMonth !== 'all') result = result.filter(t => monthKey(t.date) === filterMonth);

    result = [...result].sort((a, b) => {
      let cmp = 0;
      if (sortKey === 'date') cmp = a.date.localeCompare(b.date);
      else cmp = a.amount - b.amount;
      return sortDir === 'desc' ? -cmp : cmp;
    });

    return result;
  }, [accountTransactions, search, filterType, filterCategory, filterMonth, sortKey, sortDir]);

  // Group by date
  const groups = useMemo(() => {
    const map = new Map<string, typeof filtered>();
    for (const tx of filtered) {
      const existing = map.get(tx.date) ?? [];
      map.set(tx.date, [...existing, tx]);
    }
    return [...map.entries()].sort((a, b) => b[0].localeCompare(a[0]));
  }, [filtered]);

  const toggleSort = (key: SortKey) => {
    if (sortKey === key) setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    else { setSortKey(key); setSortDir('desc'); }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Transactions</h1>
          <p className="text-sm text-gray-500 dark:text-gray-400">{filtered.length} of {accountTransactions.length} shown</p>
        </div>
        <button
          onClick={() => setShowPdfImport(true)}
          className="flex items-center gap-1.5 text-sm text-indigo-500 hover:text-indigo-600 font-medium"
        >
          <FileText size={16} />
          Import PDF
        </button>
      </div>

      {/* Search */}
      <div className="relative">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
        <input
          className="w-full pl-9 pr-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          placeholder="Search transactions..."
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </div>

      {/* Filter toggle */}
      <button
        onClick={() => setShowFilters(f => !f)}
        className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
      >
        <Filter size={14} />
        Filters
        <ChevronDown size={14} className={`transition-transform ${showFilters ? 'rotate-180' : ''}`} />
      </button>

      {showFilters && (
        <Card className="p-4 space-y-3">
          {/* Type filter */}
          <div className="flex gap-2">
            {(['all', 'expense', 'income'] as const).map(t => (
              <button
                key={t}
                onClick={() => setFilterType(t)}
                className={`flex-1 py-1.5 text-xs font-medium rounded-lg capitalize transition-colors ${
                  filterType === t
                    ? 'bg-indigo-500 text-white'
                    : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                }`}
              >
                {t === 'all' ? 'All' : t === 'expense' ? '💸 Expenses' : '💵 Income'}
              </button>
            ))}
          </div>

          {/* Category */}
          <select
            className="w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            value={filterCategory}
            onChange={e => setFilterCategory(e.target.value)}
          >
            <option value="all">All categories</option>
            {categories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
          </select>

          {/* Month */}
          <select
            className="w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            value={filterMonth}
            onChange={e => setFilterMonth(e.target.value)}
          >
            <option value="all">All months</option>
            {months.map(m => <option key={m} value={m}>{formatDate(`${m}-01`, 'MMMM yyyy')}</option>)}
          </select>

          {/* Sort */}
          <div className="flex gap-2">
            {(['date', 'amount'] as SortKey[]).map(key => (
              <button
                key={key}
                onClick={() => toggleSort(key)}
                className={`flex-1 flex items-center justify-center gap-1 py-1.5 text-xs font-medium rounded-lg capitalize transition-colors ${
                  sortKey === key
                    ? 'bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400'
                    : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                }`}
              >
                Sort by {key}
                {sortKey === key && <ChevronDown size={12} className={sortDir === 'asc' ? 'rotate-180' : ''} />}
              </button>
            ))}
          </div>
        </Card>
      )}

      <PdfImportModal open={showPdfImport} onClose={() => setShowPdfImport(false)} />

      {/* Transaction groups */}
      {groups.length === 0 ? (
        <EmptyState
          icon="🔍"
          title="No transactions found"
          description={search ? 'Try adjusting your search or filters' : 'Add your first transaction using the + button above'}
        />
      ) : (
        <div className="space-y-4">
          {groups.map(([date, txs]) => (
            <Card key={date}>
              <div className="px-4 pt-3 pb-1">
                <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                  {formatDate(date, 'EEEE, MMMM d')}
                </p>
              </div>
              <div className="divide-y divide-gray-50 dark:divide-gray-700/50">
                {txs.map(tx => <TransactionItem key={tx.id} transaction={tx} />)}
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
