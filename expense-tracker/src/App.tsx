import { useState } from 'react';
import { StoreProvider } from './store/StoreContext';
import { AppLayout } from './components/layout/AppLayout';
import { DashboardPage } from './pages/DashboardPage';
import { TransactionsPage } from './pages/TransactionsPage';
import { AnalyticsPage } from './pages/AnalyticsPage';
import { BudgetsPage } from './pages/BudgetsPage';
import { SettingsPage } from './pages/SettingsPage';
import { AppPage } from './pages/AppPage';

type Page = 'dashboard' | 'transactions' | 'analytics' | 'budgets' | 'settings';

const isMobileApp = window.location.pathname.startsWith('/app');

function AppContent() {
  const [page, setPage] = useState<Page>('dashboard');

  if (isMobileApp) {
    return <AppPage />;
  }

  return (
    <AppLayout currentPage={page} onNavigate={p => setPage(p as Page)}>
      {page === 'dashboard'    && <DashboardPage onNavigate={p => setPage(p as Page)} />}
      {page === 'transactions' && <TransactionsPage />}
      {page === 'analytics'   && <AnalyticsPage />}
      {page === 'budgets'     && <BudgetsPage />}
      {page === 'settings'    && <SettingsPage />}
    </AppLayout>
  );
}

export default function App() {
  return (
    <StoreProvider>
      <AppContent />
    </StoreProvider>
  );
}
