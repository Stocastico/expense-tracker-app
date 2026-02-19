import { type ReactNode } from 'react';

interface CardProps {
  children: ReactNode;
  className?: string;
  onClick?: () => void;
}

export function Card({ children, className = '', onClick }: CardProps) {
  return (
    <div
      className={`bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm rounded-3xl border border-white/60 dark:border-gray-700/50 card-glow transition-all duration-200 ${onClick ? 'cursor-pointer hover:scale-[1.01] active:scale-[0.99]' : ''} ${className}`}
      onClick={onClick}
    >
      {children}
    </div>
  );
}
