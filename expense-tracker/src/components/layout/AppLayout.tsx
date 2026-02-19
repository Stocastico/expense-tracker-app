import { type ReactNode, useState } from 'react';
import { LayoutDashboard, List, BarChart2, Target, Settings, Plus } from 'lucide-react';
import { TransactionForm } from '../transactions/TransactionForm';
import { Modal } from '../ui/Modal';
import { useAppStore } from '../../store/StoreContext';
import { ACCOUNTS } from '../../store/defaults';

type Page = 'dashboard' | 'transactions' | 'analytics' | 'budgets' | 'settings';

interface AppLayoutProps {
  currentPage: Page;
  onNavigate: (page: Page) => void;
  children: ReactNode;
}

const navItems: { page: Page; icon: typeof LayoutDashboard; label: string }[] = [
  { page: 'dashboard',    icon: LayoutDashboard, label: 'Home' },
  { page: 'transactions', icon: List,            label: 'Transactions' },
  { page: 'analytics',    icon: BarChart2,       label: 'Analytics' },
  { page: 'budgets',      icon: Target,          label: 'Budgets' },
  { page: 'settings',     icon: Settings,        label: 'Settings' },
];

export function AppLayout({ currentPage, onNavigate, children }: AppLayoutProps) {
  const [addOpen, setAddOpen] = useState(false);
  const { currentAccount, setCurrentAccount, serverConnected } = useAppStore();

  return (
    <div className="flex flex-col min-h-screen">
      {/* ── Gradient Header ─────────────────────────────────────────────── */}
      <header className="sticky top-0 z-40 safe-top">
        <div className="bg-gradient-to-r from-indigo-600 via-violet-600 to-purple-600 shadow-lg shadow-indigo-500/20">
          <div className="max-w-2xl mx-auto px-4 py-3.5 flex items-center justify-between">

            {/* Brand */}
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 bg-white/20 rounded-2xl flex items-center justify-center text-xl shadow-inner">
                💰
              </div>
              <div>
                <span className="font-bold text-white text-base leading-tight block">Expense Tracker</span>
                {serverConnected && (
                  <span className="text-[10px] text-indigo-200 flex items-center gap-1">
                    <span className="w-1.5 h-1.5 bg-emerald-400 rounded-full inline-block" />
                    synced
                  </span>
                )}
              </div>
            </div>

            {/* Right: account switcher + Add button */}
            <div className="flex items-center gap-2">
              {/* Glassmorphism account switcher */}
              <div className="flex items-center bg-white/15 backdrop-blur-md rounded-2xl p-0.5 gap-0.5">
                {ACCOUNTS.map(acc => (
                  <button
                    key={acc.id}
                    onClick={() => setCurrentAccount(acc.id)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all duration-200 ${
                      currentAccount === acc.id
                        ? 'bg-white text-indigo-700 shadow-sm'
                        : 'text-white/80 hover:text-white hover:bg-white/10'
                    }`}
                  >
                    {acc.icon} {acc.label}
                  </button>
                ))}
              </div>

              {/* Circular Add button */}
              <button
                onClick={() => setAddOpen(true)}
                className="w-9 h-9 bg-white text-indigo-600 rounded-2xl flex items-center justify-center shadow-lg shadow-black/10 hover:scale-105 active:scale-95 transition-transform"
                aria-label="Add transaction"
              >
                <Plus size={20} strokeWidth={2.5} />
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* ── Main content ────────────────────────────────────────────────── */}
      <main className="flex-1 max-w-2xl mx-auto w-full px-4 py-5 pb-28">
        {children}
      </main>

      {/* ── Glassmorphism Bottom Nav ─────────────────────────────────────── */}
      <nav className="fixed bottom-0 left-0 right-0 z-40 safe-bottom">
        <div className="mx-auto max-w-2xl px-3 pb-2 pt-1">
          <div className="bg-white/80 dark:bg-gray-900/80 backdrop-blur-xl rounded-3xl shadow-xl shadow-gray-300/30 dark:shadow-black/40 border border-white/60 dark:border-gray-700/40">
            <div className="flex items-center justify-around px-1 py-1">
              {navItems.map(({ page, icon: Icon, label }) => {
                const active = currentPage === page;
                return (
                  <button
                    key={page}
                    onClick={() => onNavigate(page)}
                    className={`flex flex-col items-center gap-0.5 px-3 py-1.5 rounded-2xl transition-all duration-200 min-w-0 flex-1 ${
                      active
                        ? 'text-indigo-600 dark:text-indigo-400'
                        : 'text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'
                    }`}
                  >
                    <div className={`p-1.5 rounded-xl transition-all duration-200 ${
                      active ? 'bg-indigo-50 dark:bg-indigo-900/40' : ''
                    }`}>
                      <Icon size={20} strokeWidth={active ? 2.5 : 1.8} />
                    </div>
                    <span className="text-[10px] font-semibold truncate">{label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </nav>

      {/* ── Add Transaction Modal ─────────────────────────────────────────── */}
      <Modal open={addOpen} onClose={() => setAddOpen(false)} title="Add Transaction">
        <TransactionForm onClose={() => setAddOpen(false)} />
      </Modal>
    </div>
  );
}
