export type TransactionType = 'expense' | 'income';

export type AccountId = 'personal' | 'family';

export type RecurringFrequency = 'daily' | 'weekly' | 'biweekly' | 'monthly' | 'quarterly' | 'yearly';

export interface Category {
  id: string;
  name: string;
  icon: string;         // emoji
  color: string;        // tailwind color class e.g. "bg-red-500"
  type: TransactionType | 'both';
}

export interface Transaction {
  id: string;
  type: TransactionType;
  amount: number;
  currency: string;     // ISO 4217 e.g. "USD"
  categoryId: string;
  description: string;
  merchant?: string;
  date: string;         // ISO date string YYYY-MM-DD
  tags: string[];
  notes?: string;
  // Recurring
  isRecurring: boolean;
  recurringFrequency?: RecurringFrequency;
  recurringEndDate?: string;   // ISO date string, undefined = no end
  recurringParentId?: string;  // links generated instances to template
  // Receipt
  receiptImageUrl?: string;
  // Account
  accountId: AccountId;
  // Meta
  createdAt: string;
  updatedAt: string;
}

export interface Budget {
  id: string;
  categoryId: string;
  amount: number;
  currency: string;
  period: 'monthly' | 'yearly';
  createdAt: string;
  updatedAt: string;
}

export type SyncProvider = 'dropbox' | 'onedrive' | 'icloud' | 'googledrive' | 'custom';

export interface SyncConfig {
  enabled: boolean;
  provider: SyncProvider;
  folderPath: string;       // absolute path to the cloud-synced folder
  filename: string;          // e.g. "expense-tracker-data.json"
  lastSyncedAt?: string;     // ISO timestamp
}

export interface AppSettings {
  currency: string;
  darkMode: boolean;
  categories: Category[];
  startOfMonth: number;    // day 1-28
  defaultAccount: AccountId;
  syncConfig?: SyncConfig;
}

export interface AppState {
  transactions: Transaction[];
  budgets: Budget[];
  settings: AppSettings;
}

export interface MonthStats {
  month: string;          // "2024-01"
  income: number;
  expenses: number;
  net: number;
}

export interface CategoryStats {
  categoryId: string;
  total: number;
  count: number;
  percentage: number;
}
