import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Badge } from '../../../components/ui/Badge';

describe('Badge', () => {
  it('renders children', () => {
    render(<Badge>New</Badge>);
    expect(screen.getByText('New')).toBeInTheDocument();
  });

  it('applies default color classes', () => {
    const { container } = render(<Badge>Tag</Badge>);
    expect(container.firstChild).toHaveClass('bg-indigo-100');
  });

  it('accepts custom color', () => {
    const { container } = render(<Badge color="bg-red-100 text-red-700">Alert</Badge>);
    expect(container.firstChild).toHaveClass('bg-red-100');
  });
});
