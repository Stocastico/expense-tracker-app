import { type SelectHTMLAttributes } from 'react';

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
  options: { value: string; label: string }[];
}

export function Select({ label, error, options, className = '', ...props }: SelectProps) {
  return (
    <div className="flex flex-col gap-1">
      {label && (
        <label className="text-sm font-medium text-gray-700 dark:text-gray-300">{label}</label>
      )}
      <select
        className={`
          w-full rounded-xl border bg-white dark:bg-gray-700
          text-gray-900 dark:text-white
          border-gray-200 dark:border-gray-600
          focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent
          py-2.5 pl-3 pr-8 text-sm transition-colors
          ${error ? 'border-red-400' : ''}
          ${className}
        `}
        {...props}
      >
        {options.map(o => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
      {error && <span className="text-xs text-red-500">{error}</span>}
    </div>
  );
}
