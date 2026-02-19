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
        <label className="text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">{label}</label>
      )}
      <select
        className={`
          w-full rounded-2xl border bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm
          text-gray-900 dark:text-white
          border-gray-200/80 dark:border-gray-700/50
          focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:border-indigo-300 dark:focus:border-indigo-600
          py-2.5 pl-3.5 pr-8 text-sm transition-all duration-200
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
