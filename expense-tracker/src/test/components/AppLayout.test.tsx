import { describe, it, expect } from 'vitest';
import { screen, fireEvent } from '@testing-library/react';
import { renderWithStore } from '../helpers';
import { AppLayout } from '../../components/layout/AppLayout';

function noop() {}

describe('AppLayout – account switcher', () => {
  it('renders Personal and Family account tabs', () => {
    renderWithStore(
      <AppLayout currentPage="dashboard" onNavigate={noop}>
        <div>content</div>
      </AppLayout>
    );
    expect(screen.getAllByText(/Personal/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/Family/i).length).toBeGreaterThan(0);
  });

  it('switches account when Family is clicked', () => {
    renderWithStore(
      <AppLayout currentPage="dashboard" onNavigate={noop}>
        <div>content</div>
      </AppLayout>
    );
    const familyBtn = screen.getAllByText(/Family/i)[0];
    fireEvent.click(familyBtn);
    // After clicking Family, it should be visually active (bg-white class applied)
    expect(familyBtn.className).toContain('bg-white');
  });

  it('renders nav items', () => {
    renderWithStore(
      <AppLayout currentPage="dashboard" onNavigate={noop}>
        <div>content</div>
      </AppLayout>
    );
    expect(screen.getByText('Home')).toBeInTheDocument();
    expect(screen.getByText('Transactions')).toBeInTheDocument();
    expect(screen.getByText('Analytics')).toBeInTheDocument();
    expect(screen.getByText('Budgets')).toBeInTheDocument();
    expect(screen.getByText('Settings')).toBeInTheDocument();
  });

  it('calls onNavigate when nav item is clicked', () => {
    const pages: string[] = [];
    renderWithStore(
      <AppLayout currentPage="dashboard" onNavigate={p => pages.push(p)}>
        <div>content</div>
      </AppLayout>
    );
    fireEvent.click(screen.getByText('Transactions'));
    expect(pages).toContain('transactions');
  });

  it('shows Add button', () => {
    renderWithStore(
      <AppLayout currentPage="dashboard" onNavigate={noop}>
        <div>content</div>
      </AppLayout>
    );
    expect(screen.getByRole('button', { name: /add transaction/i })).toBeInTheDocument();
  });
});
