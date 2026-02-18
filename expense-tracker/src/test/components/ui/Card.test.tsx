import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { Card } from '../../../components/ui/Card';

describe('Card', () => {
  it('renders children', () => {
    render(<Card>Hello card</Card>);
    expect(screen.getByText('Hello card')).toBeInTheDocument();
  });

  it('applies custom className', () => {
    const { container } = render(<Card className="p-8">Content</Card>);
    expect(container.firstChild).toHaveClass('p-8');
  });

  it('calls onClick when provided', () => {
    const onClick = vi.fn();
    render(<Card onClick={onClick}>Clickable</Card>);
    fireEvent.click(screen.getByText('Clickable'));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('adds cursor-pointer class when onClick is provided', () => {
    const { container } = render(<Card onClick={() => {}}>Click</Card>);
    expect(container.firstChild).toHaveClass('cursor-pointer');
  });

  it('does not add cursor-pointer when no onClick', () => {
    const { container } = render(<Card>Static</Card>);
    expect(container.firstChild).not.toHaveClass('cursor-pointer');
  });
});
