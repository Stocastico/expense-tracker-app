import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { Input } from '../../../components/ui/Input';

describe('Input', () => {
  it('renders with label', () => {
    render(<Input label="Amount" />);
    expect(screen.getByText('Amount')).toBeInTheDocument();
  });

  it('renders placeholder', () => {
    render(<Input placeholder="Enter value" />);
    expect(screen.getByPlaceholderText('Enter value')).toBeInTheDocument();
  });

  it('shows error message', () => {
    render(<Input error="This field is required" />);
    expect(screen.getByText('This field is required')).toBeInTheDocument();
  });

  it('shows prefix', () => {
    render(<Input prefix="$" />);
    expect(screen.getByText('$')).toBeInTheDocument();
  });

  it('shows suffix', () => {
    render(<Input suffix="USD" />);
    expect(screen.getByText('USD')).toBeInTheDocument();
  });

  it('calls onChange handler', () => {
    const onChange = vi.fn();
    render(<Input onChange={onChange} />);
    fireEvent.change(screen.getByRole('textbox'), { target: { value: '42' } });
    expect(onChange).toHaveBeenCalled();
  });

  it('forwards ref', () => {
    const ref = { current: null } as React.RefObject<HTMLInputElement>;
    render(<Input ref={ref} />);
    expect(ref.current).toBeInstanceOf(HTMLInputElement);
  });

  it('accepts controlled value', () => {
    render(<Input value="test-value" onChange={() => {}} />);
    expect(screen.getByDisplayValue('test-value')).toBeInTheDocument();
  });
});
