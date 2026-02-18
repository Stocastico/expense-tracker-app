import { format, parseISO, startOfMonth, endOfMonth, isWithinInterval, subMonths } from 'date-fns';

export function today(): string {
  return format(new Date(), 'yyyy-MM-dd');
}

export function formatDate(dateStr: string, fmt = 'MMM d, yyyy'): string {
  try { return format(parseISO(dateStr), fmt); } catch { return dateStr; }
}

export function monthKey(dateStr: string): string {
  try { return format(parseISO(dateStr), 'yyyy-MM'); } catch { return ''; }
}

export function monthLabel(key: string): string {
  try { return format(parseISO(`${key}-01`), 'MMM yyyy'); } catch { return key; }
}

export function isInMonth(dateStr: string, year: number, month: number): boolean {
  try {
    const d = parseISO(dateStr);
    const start = startOfMonth(new Date(year, month, 1));
    const end = endOfMonth(new Date(year, month, 1));
    return isWithinInterval(d, { start, end });
  } catch { return false; }
}

export function lastNMonths(n: number): string[] {
  const result: string[] = [];
  for (let i = n - 1; i >= 0; i--) {
    result.push(format(subMonths(new Date(), i), 'yyyy-MM'));
  }
  return result;
}
