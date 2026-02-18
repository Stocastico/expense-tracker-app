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
    <div className="flex flex-col min-h-screen bg-gray-50 dark:bg-gray-950">
      {/* Top header */}
      <header className="sticky top-0 z-40 bg-white/80 dark:bg-gray-900/80 backdrop-blur-md border-b border-gray-100 dark:border-gray-800 safe-top">
        <div className="max-w-2xl mx-auto flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-2">
            <span className="text-2xl">💰</span>
            <span className="font-bold text-gray-900 dark:text-white text-lg">Expense Tracker</span>
            {serverConnected && (
              <span className="text-xs bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 px-1.5 py-0.5 rounded-full font-medium">
                ● sync
              </span>
            )}
          </div>

          <div className="flex items-center gap-2">
            {/* Account switcher */}
            <div className="flex rounded-lg bg-gray-100 dark:bg-gray-700 p-0.5 text-xs">
              {ACCOUNTS.map(acc => (
                <button
                  key={acc.id}
                  onClick={() => setCurrentAccount(acc.id)}
                  className={`px-2.5 py-1 rounded-md font-medium transition-colors ${
                    currentAccount === acc.id
                      ? 'bg-white dark:bg-gray-600 text-gray-900 dark:text-white shadow-sm'
                      : 'text-gray-500 dark:text-gray-400'
                  }`}
                >
                  {acc.icon} {acc.label}
                </button>
              ))}
            </div>

            <button
              onClick={() => setAddOpen(true)}
              className="flex items-center gap-1.5 bg-indigo-500 hover:bg-indigo-600 text-white px-4 py-2 rounded-xl text-sm font-medium transition-colors shadow-sm"
            >
              <Plus size={16} />
              Add
            </button>
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="flex-1 max-w-2xl mx-auto w-full px-4 py-4 pb-24">
        {children}
      </main>

      {/* Bottom nav */}
      <nav className="fixed bottom-0 left-0 right-0 z-40 bg-white/90 dark:bg-gray-900/90 backdrop-blur-md border-t border-gray-100 dark:border-gray-800 safe-bottom">
        <div className="max-w-2xl mx-auto flex items-center justify-around px-2 py-1">
          {navItems.map(({ page, icon: Icon, label }) => {
            const active = currentPage === page;
            return (
              <button
                key={page}
                onClick={() => onNavigate(page)}
                className={`flex flex-col items-center gap-0.5 px-3 py-2 rounded-xl transition-colors min-w-0 flex-1 ${
                  active
                    ? 'text-indigo-500'
                    : 'text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'
                }`}
              >
                <Icon size={22} strokeWidth={active ? 2.5 : 1.8} />
                <span className="text-xs font-medium truncate">{label}</span>
              </button>
            );
          })}
        </div>
      </nav>

      {/* Add Transaction Modal */}
      <Modal open={addOpen} onClose={() => setAddOpen(false)} title="Add Transaction">
        <TransactionForm onClose={() => setAddOpen(false)} />
      </Modal>
    </div>
  );
}
