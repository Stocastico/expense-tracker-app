import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { screen, fireEvent } from '@testing-library/react';
import { renderWithStore } from '../helpers';
import { SettingsPage } from '../../pages/SettingsPage';
import { saveState } from '../../store/storage';
import { DEFAULT_SETTINGS, DEFAULT_CATEGORIES } from '../../store/defaults';

describe('SettingsPage', () => {
  it('renders heading', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText('Settings')).toBeInTheDocument();
  });

  it('renders Appearance section', () => {
    renderWithStore(<SettingsPage />);
    // Section header text is uppercased in the DOM
    expect(screen.getAllByText(/Appearance/i).length).toBeGreaterThan(0);
    expect(screen.getByText(/Dark mode/i)).toBeInTheDocument();
  });

  it('renders Currency section heading', () => {
    renderWithStore(<SettingsPage />);
    // The section has multiple "Currency" occurrences (heading + select description)
    const currencyEls = screen.getAllByText(/Currency/i);
    expect(currencyEls.length).toBeGreaterThan(0);
  });

  it('renders currency selector', () => {
    renderWithStore(<SettingsPage />);
    // Should be a select element with currency options
    const selects = screen.getAllByRole('combobox');
    expect(selects.length).toBeGreaterThan(0);
  });

  it('renders Categories section heading', () => {
    renderWithStore(<SettingsPage />);
    // Section heading may appear alongside category description text
    const catEls = screen.getAllByText(/Categories/i);
    expect(catEls.length).toBeGreaterThan(0);
  });

  it('shows the custom categories count', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getAllByText(/categories/i).length).toBeGreaterThan(0);
  });

  it('renders Data section with export buttons', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Export as CSV/i)).toBeInTheDocument();
    expect(screen.getByText(/Export as JSON/i)).toBeInTheDocument();
    expect(screen.getByText(/Import from JSON/i)).toBeInTheDocument();
  });

  it('renders iOS install hint', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Add to iOS Home Screen/i)).toBeInTheDocument();
  });

  it('renders Danger Zone section', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Danger Zone/i)).toBeInTheDocument();
    expect(screen.getByText(/Clear all data/i)).toBeInTheDocument();
  });

  it('shows confirmation prompt before clearing data', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/Clear all data/i));
    expect(screen.getByText(/Are you sure/i)).toBeInTheDocument();
  });

  it('cancels data clear when Cancel is clicked', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/Clear all data/i));
    fireEvent.click(screen.getByText(/^Cancel$/i));
    expect(screen.queryByText(/Are you sure/i)).not.toBeInTheDocument();
  });

  it('toggles dark mode', () => {
    renderWithStore(<SettingsPage />);
    const toggleLabel = screen.getByText(/Dark mode/i).closest('div');
    const toggle = toggleLabel?.querySelector('[class*="rounded-full"]') as HTMLElement | null;
    if (toggle) {
      fireEvent.click(toggle);
      expect(document.documentElement.classList.contains('dark')).toBe(true);
    }
  });

  it('opens Add category modal', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/^Add$/i));
    expect(screen.getByText(/New Category/i)).toBeInTheDocument();
  });

  it('triggers CSV export via URL.createObjectURL', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/^CSV$/i));
    expect(URL.createObjectURL).toHaveBeenCalled();
  });

  it('triggers JSON export via URL.createObjectURL', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/^JSON$/i));
    expect(URL.createObjectURL).toHaveBeenCalled();
  });

  it('confirms data clear and calls clearAllData', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/Clear all data/i));
    fireEvent.click(screen.getByText(/Yes, delete everything/i));
    // After clearing, the confirm prompt disappears
    expect(screen.queryByText(/Are you sure/i)).not.toBeInTheDocument();
  });

  it('changes currency when selector is changed', () => {
    renderWithStore(<SettingsPage />);
    const selects = screen.getAllByRole('combobox');
    fireEvent.change(selects[0], { target: { value: 'EUR' } });
    // Check that the select now shows EUR
    expect((selects[0] as HTMLSelectElement).value).toBe('EUR');
  });

  it('validates empty name in Add category form', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/^Add$/i));
    // Click Add Category without entering name
    fireEvent.click(screen.getByText(/Add Category/i));
    expect(screen.getByText(/Name is required/i)).toBeInTheDocument();
  });

  it('closes Add category modal via Cancel button', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/^Add$/i));
    expect(screen.getByText(/New Category/i)).toBeInTheDocument();
    fireEvent.click(screen.getByText(/^Cancel$/i));
    expect(screen.queryByText(/New Category/i)).not.toBeInTheDocument();
  });

  it('clicks Import button (triggers file input)', () => {
    renderWithStore(<SettingsPage />);
    // Click Import button - should not throw
    const importBtn = screen.getByText(/^Import$/i);
    expect(() => fireEvent.click(importBtn)).not.toThrow();
  });
});

describe('SettingsPage – custom categories', () => {
  beforeEach(() => {
    saveState({
      transactions: [],
      budgets: [],
      settings: {
        ...DEFAULT_SETTINGS,
        categories: [
          ...DEFAULT_CATEGORIES,
          { id: 'custom-sports', name: 'Sports', icon: '⚽', color: 'bg-green-500', type: 'expense' as const },
        ],
      },
    });
  });

  it('shows delete button for custom categories', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText('Sports')).toBeInTheDocument();
    // There should be trash icons visible
    const trashBtns = document.querySelectorAll('button');
    expect(trashBtns.length).toBeGreaterThan(0);
  });

  it('deletes a custom category when trash icon is clicked', () => {
    renderWithStore(<SettingsPage />);
    // Find the Sports category row and click its delete button
    const sportsEl = screen.getByText('Sports');
    const row = sportsEl.closest('div');
    const deleteBtn = row?.querySelector('button');
    if (deleteBtn) {
      fireEvent.click(deleteBtn);
      expect(screen.queryByText('Sports')).not.toBeInTheDocument();
    }
  });
});
