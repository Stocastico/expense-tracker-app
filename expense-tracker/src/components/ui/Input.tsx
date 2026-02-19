import { type InputHTMLAttributes, forwardRef } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  prefix?: string;
  suffix?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, prefix, suffix, className = '', ...props }, ref) => {
    return (
      <div className="flex flex-col gap-1">
        {label && (
          <label className="text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">
            {label}
          </label>
        )}
        <div className="relative flex items-center">
          {prefix && (
            <span className="absolute left-3 text-gray-500 dark:text-gray-400 text-sm pointer-events-none">
              {prefix}
            </span>
          )}
          <input
            ref={ref}
            className={`
              w-full rounded-2xl border bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm
              text-gray-900 dark:text-white
              border-gray-200/80 dark:border-gray-700/50
              focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:border-indigo-300 dark:focus:border-indigo-600
              placeholder-gray-400 dark:placeholder-gray-500
              py-2.5 text-sm transition-all duration-200
              ${prefix ? 'pl-8' : 'pl-3.5'}
              ${suffix ? 'pr-10' : 'pr-3.5'}
              ${error ? 'border-red-400 focus:ring-red-400' : ''}
              ${className}
            `}
            {...props}
          />
          {suffix && (
            <span className="absolute right-3 text-gray-500 dark:text-gray-400 text-sm pointer-events-none">
              {suffix}
            </span>
          )}
        </div>
        {error && <span className="text-xs text-red-500">{error}</span>}
      </div>
    );
  }
);
Input.displayName = 'Input';
