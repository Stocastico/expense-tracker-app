import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { EmptyState } from '../../../components/ui/EmptyState';
import { Button } from '../../../components/ui/Button';

describe('EmptyState', () => {
  it('renders title', () => {
    render(<EmptyState icon="💡" title="Nothing here" />);
    expect(screen.getByText('Nothing here')).toBeInTheDocument();
  });

  it('renders icon', () => {
    render(<EmptyState icon="🎉" title="Done" />);
    expect(screen.getByText('🎉')).toBeInTheDocument();
  });

  it('renders description when provided', () => {
    render(<EmptyState icon="💡" title="Empty" description="Add items to get started" />);
    expect(screen.getByText('Add items to get started')).toBeInTheDocument();
  });

  it('does not render description when omitted', () => {
    const { queryByText } = render(<EmptyState icon="💡" title="Empty" />);
    expect(queryByText('Add items')).not.toBeInTheDocument();
  });

  it('renders action element when provided', () => {
    render(
      <EmptyState
        icon="💡"
        title="Empty"
        action={<Button>Create new</Button>}
      />
    );
    expect(screen.getByText('Create new')).toBeInTheDocument();
  });
});
