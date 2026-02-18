import { CURRENCIES } from '../store/defaults';

export function formatCurrency(amount: number, currency: string): string {
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency,
      maximumFractionDigits: 2,
    }).format(amount);
  } catch {
    const sym = CURRENCIES.find(c => c.code === currency)?.symbol ?? currency;
    return `${sym}${amount.toFixed(2)}`;
  }
}

export function getCurrencySymbol(currency: string): string {
  return CURRENCIES.find(c => c.code === currency)?.symbol ?? currency;
}

export function parseMoney(value: string): number {
  let cleaned = value.replace(/[^0-9.,\-]/g, '');
  // If both comma and period are present, comma is a thousands separator
  if (cleaned.includes(',') && cleaned.includes('.')) {
    cleaned = cleaned.replace(/,/g, '');
  } else {
    // Only comma present: treat as decimal separator
    cleaned = cleaned.replace(',', '.');
  }
  const n = parseFloat(cleaned);
  return isNaN(n) ? 0 : n;
}
