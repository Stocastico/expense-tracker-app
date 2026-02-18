import type { Category, AppSettings } from '../types';

export const DEFAULT_CATEGORIES: Category[] = [
  { id: 'food',          name: 'Food & Dining',    icon: '🍽️',  color: 'bg-orange-500',  type: 'expense' },
  { id: 'groceries',    name: 'Groceries',         icon: '🛒',  color: 'bg-green-500',   type: 'expense' },
  { id: 'transport',    name: 'Transport',          icon: '🚗',  color: 'bg-blue-500',    type: 'expense' },
  { id: 'housing',      name: 'Housing & Rent',    icon: '🏠',  color: 'bg-purple-500',  type: 'expense' },
  { id: 'utilities',    name: 'Utilities',          icon: '💡',  color: 'bg-yellow-500',  type: 'expense' },
  { id: 'health',       name: 'Health',             icon: '🏥',  color: 'bg-red-500',     type: 'expense' },
  { id: 'entertainment',name: 'Entertainment',      icon: '🎬',  color: 'bg-pink-500',    type: 'expense' },
  { id: 'shopping',     name: 'Shopping',           icon: '🛍️',  color: 'bg-indigo-500',  type: 'expense' },
  { id: 'education',    name: 'Education',          icon: '📚',  color: 'bg-cyan-500',    type: 'expense' },
  { id: 'travel',       name: 'Travel',             icon: '✈️',  color: 'bg-teal-500',    type: 'expense' },
  { id: 'insurance',    name: 'Insurance',          icon: '🛡️',  color: 'bg-slate-500',   type: 'expense' },
  { id: 'subscriptions',name: 'Subscriptions',      icon: '📱',  color: 'bg-violet-500',  type: 'expense' },
  { id: 'personal',     name: 'Personal Care',      icon: '💆',  color: 'bg-rose-500',    type: 'expense' },
  { id: 'gifts',        name: 'Gifts & Donations',  icon: '🎁',  color: 'bg-fuchsia-500', type: 'expense' },
  { id: 'other_exp',    name: 'Other',              icon: '📦',  color: 'bg-gray-500',    type: 'expense' },
  { id: 'salary',       name: 'Salary',             icon: '💼',  color: 'bg-emerald-500', type: 'income'  },
  { id: 'freelance',    name: 'Freelance',          icon: '💻',  color: 'bg-lime-500',    type: 'income'  },
  { id: 'investment',   name: 'Investments',        icon: '📈',  color: 'bg-sky-500',     type: 'income'  },
  { id: 'other_inc',    name: 'Other Income',       icon: '💰',  color: 'bg-amber-500',   type: 'income'  },
];

// Keywords → category mapping for smart defaults
export const MERCHANT_KEYWORDS: Record<string, string> = {
  // Food
  restaurant: 'food', cafe: 'food', coffee: 'food', pizza: 'food', burger: 'food',
  sushi: 'food', mcdonald: 'food', starbucks: 'food', subway: 'food', kfc: 'food',
  // Groceries
  supermarket: 'groceries', walmart: 'groceries', lidl: 'groceries', aldi: 'groceries',
  tesco: 'groceries', safeway: 'groceries', kroger: 'groceries', carrefour: 'groceries',
  // Transport
  uber: 'transport', lyft: 'transport', taxi: 'transport', metro: 'transport',
  parking: 'transport', gas: 'transport', petrol: 'transport', fuel: 'transport',
  train: 'transport', bus: 'transport', tram: 'transport',
  // Health
  pharmacy: 'health', hospital: 'health', clinic: 'health', doctor: 'health',
  dentist: 'health', gym: 'health', fitness: 'health',
  // Entertainment
  netflix: 'subscriptions', spotify: 'subscriptions',
  cinema: 'entertainment', theater: 'entertainment', concert: 'entertainment',
  // Shopping
  amazon: 'shopping', ebay: 'shopping', zara: 'shopping', handm: 'shopping',
  // Utilities
  electric: 'utilities', water: 'utilities', naturalgas: 'utilities', internet: 'utilities',
  phone: 'utilities', broadband: 'utilities',
  // Housing
  rent: 'housing', mortgage: 'housing',
};

export const DEFAULT_SETTINGS: AppSettings = {
  currency: 'USD',
  darkMode: false,
  categories: DEFAULT_CATEGORIES,
  startOfMonth: 1,
};

export const CURRENCIES = [
  { code: 'USD', symbol: '$', name: 'US Dollar' },
  { code: 'EUR', symbol: '€', name: 'Euro' },
  { code: 'GBP', symbol: '£', name: 'British Pound' },
  { code: 'JPY', symbol: '¥', name: 'Japanese Yen' },
  { code: 'CAD', symbol: 'C$', name: 'Canadian Dollar' },
  { code: 'AUD', symbol: 'A$', name: 'Australian Dollar' },
  { code: 'CHF', symbol: 'Fr', name: 'Swiss Franc' },
  { code: 'CNY', symbol: '¥', name: 'Chinese Yuan' },
  { code: 'INR', symbol: '₹', name: 'Indian Rupee' },
  { code: 'BRL', symbol: 'R$', name: 'Brazilian Real' },
  { code: 'MXN', symbol: '$', name: 'Mexican Peso' },
  { code: 'SEK', symbol: 'kr', name: 'Swedish Krona' },
  { code: 'NOK', symbol: 'kr', name: 'Norwegian Krone' },
  { code: 'DKK', symbol: 'kr', name: 'Danish Krone' },
  { code: 'SGD', symbol: 'S$', name: 'Singapore Dollar' },
];
