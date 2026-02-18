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
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
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
              w-full rounded-xl border bg-white dark:bg-gray-700
              text-gray-900 dark:text-white
              border-gray-200 dark:border-gray-600
              focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent
              placeholder-gray-400 dark:placeholder-gray-500
              py-2.5 text-sm transition-colors
              ${prefix ? 'pl-8' : 'pl-3'}
              ${suffix ? 'pr-10' : 'pr-3'}
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
