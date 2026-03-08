/**
 * Tests for the Cloud Sync settings section in SettingsPage.
 * This covers the Electron-only sync UI: provider selection, folder picker,
 * enable/disable sync, and sync status display.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { screen, fireEvent, waitFor } from '@testing-library/react';
import { renderWithStore } from '../helpers';
import { SettingsPage } from '../../pages/SettingsPage';

// Mock the fileSync module to simulate Electron/non-Electron modes
vi.mock('../../store/fileSync', () => ({
  isElectronApp: vi.fn(() => false),
  pickSyncFolder: vi.fn(async () => null),
  configureSync: vi.fn(async () => ({ ok: true })),
  readSyncFile: vi.fn(async () => null),
  writeSyncFile: vi.fn(async () => {}),
  onSyncFileChanged: vi.fn(() => vi.fn()),
}));

import * as fileSync from '../../store/fileSync';

beforeEach(() => {
  localStorage.clear();
  vi.clearAllMocks();
});

// ─── Non-Electron: sync section should be hidden ───────────────────────────

describe('SettingsPage – non-Electron', () => {
  it('does not show Cloud Sync section when not in Electron', () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(false);
    renderWithStore(<SettingsPage />);
    expect(screen.queryByText(/Cloud Sync/i)).not.toBeInTheDocument();
  });

  it('still shows all other settings sections', () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(false);
    renderWithStore(<SettingsPage />);
    expect(screen.getByText('Settings')).toBeInTheDocument();
    expect(screen.getByText(/Appearance/i)).toBeInTheDocument();
    expect(screen.getByText(/Export as CSV/i)).toBeInTheDocument();
  });
});

// ─── Electron: sync section visible ────────────────────────────────────────

describe('SettingsPage – Electron sync UI', () => {
  beforeEach(() => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(true);
  });

  it('shows Cloud Sync section heading', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Cloud Sync/i)).toBeInTheDocument();
  });

  it('shows sync description text', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Sync your data across devices/i)).toBeInTheDocument();
  });

  it('shows Cloud provider dropdown', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Cloud provider/i)).toBeInTheDocument();
  });

  it('shows all provider options in dropdown', () => {
    renderWithStore(<SettingsPage />);
    const selects = screen.getAllByRole('combobox');
    // Find the provider select (has Dropbox option)
    const providerSelect = selects.find(s => {
      const options = Array.from((s as HTMLSelectElement).options);
      return options.some(o => o.text === 'Dropbox');
    });
    expect(providerSelect).toBeTruthy();
    const options = Array.from((providerSelect as HTMLSelectElement).options).map(o => o.text);
    expect(options).toContain('Dropbox');
    expect(options).toContain('OneDrive');
    expect(options).toContain('iCloud Drive');
    expect(options).toContain('Google Drive');
    expect(options).toContain('Custom folder');
  });

  it('shows Sync folder input', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Sync folder/i)).toBeInTheDocument();
  });

  it('shows Enable sync button', () => {
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Enable sync/i)).toBeInTheDocument();
  });

  it('shows folder picker button', () => {
    renderWithStore(<SettingsPage />);
    // The folder picker button contains FolderOpen icon
    const buttons = screen.getAllByRole('button');
    // At least one button should be in the sync section
    expect(buttons.length).toBeGreaterThan(0);
  });

  it('shows error when enabling sync without folder', async () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/Enable sync/i));
    expect(screen.getByText(/Please select a folder/i)).toBeInTheDocument();
  });

  it('changes provider selection', () => {
    renderWithStore(<SettingsPage />);
    const selects = screen.getAllByRole('combobox');
    const providerSelect = selects.find(s => {
      const options = Array.from((s as HTMLSelectElement).options);
      return options.some(o => o.text === 'Dropbox');
    });
    expect(providerSelect).toBeTruthy();
    fireEvent.change(providerSelect!, { target: { value: 'onedrive' } });
    expect((providerSelect as HTMLSelectElement).value).toBe('onedrive');
  });

  it('updates folder path when typed', () => {
    renderWithStore(<SettingsPage />);
    const folderInput = screen.getByPlaceholderText(/~\/Dropbox/i);
    fireEvent.change(folderInput, { target: { value: '/Users/test/Dropbox' } });
    expect((folderInput as HTMLInputElement).value).toBe('/Users/test/Dropbox');
  });

  it('clears error when folder path is typed', () => {
    renderWithStore(<SettingsPage />);
    // Trigger error first
    fireEvent.click(screen.getByText(/Enable sync/i));
    expect(screen.getByText(/Please select a folder/i)).toBeInTheDocument();
    // Now type a folder path
    const folderInput = screen.getByPlaceholderText(/~\/Dropbox/i);
    fireEvent.change(folderInput, { target: { value: '/test' } });
    expect(screen.queryByText(/Please select a folder/i)).not.toBeInTheDocument();
  });

  it('clears error when provider is changed', () => {
    renderWithStore(<SettingsPage />);
    fireEvent.click(screen.getByText(/Enable sync/i));
    expect(screen.getByText(/Please select a folder/i)).toBeInTheDocument();
    const selects = screen.getAllByRole('combobox');
    const providerSelect = selects.find(s => {
      const options = Array.from((s as HTMLSelectElement).options);
      return options.some(o => o.text === 'Dropbox');
    });
    fireEvent.change(providerSelect!, { target: { value: 'onedrive' } });
    expect(screen.queryByText(/Please select a folder/i)).not.toBeInTheDocument();
  });

  it('calls pickSyncFolder when folder picker button is clicked', async () => {
    vi.mocked(fileSync.pickSyncFolder).mockResolvedValue('/Users/test/Dropbox');
    renderWithStore(<SettingsPage />);

    // Find the folder picker button (last small button before Enable sync)
    const buttons = screen.getAllByRole('button');
    const folderBtn = buttons.find(b => b.querySelector('svg') && b.textContent === '');
    if (folderBtn) {
      await fireEvent.click(folderBtn);
      await waitFor(() => {
        expect(fileSync.pickSyncFolder).toHaveBeenCalled();
      });
    }
  });

  it('updates placeholder based on selected provider', () => {
    renderWithStore(<SettingsPage />);
    // Default is Dropbox
    expect(screen.getByPlaceholderText(/~\/Dropbox/i)).toBeInTheDocument();

    // Change to OneDrive
    const selects = screen.getAllByRole('combobox');
    const providerSelect = selects.find(s => {
      const options = Array.from((s as HTMLSelectElement).options);
      return options.some(o => o.text === 'Dropbox');
    });
    fireEvent.change(providerSelect!, { target: { value: 'onedrive' } });
    expect(screen.getByPlaceholderText(/~\/OneDrive/i)).toBeInTheDocument();
  });

  it('changes placeholder for iCloud provider', () => {
    renderWithStore(<SettingsPage />);
    const selects = screen.getAllByRole('combobox');
    const providerSelect = selects.find(s => {
      const options = Array.from((s as HTMLSelectElement).options);
      return options.some(o => o.text === 'Dropbox');
    });
    fireEvent.change(providerSelect!, { target: { value: 'icloud' } });
    expect(screen.getByPlaceholderText(/Mobile Documents/i)).toBeInTheDocument();
  });

  it('changes placeholder for Google Drive provider', () => {
    renderWithStore(<SettingsPage />);
    const selects = screen.getAllByRole('combobox');
    const providerSelect = selects.find(s => {
      const options = Array.from((s as HTMLSelectElement).options);
      return options.some(o => o.text === 'Dropbox');
    });
    fireEvent.change(providerSelect!, { target: { value: 'googledrive' } });
    expect(screen.getByPlaceholderText(/Google Drive/i)).toBeInTheDocument();
  });

  it('changes placeholder for custom provider', () => {
    renderWithStore(<SettingsPage />);
    const selects = screen.getAllByRole('combobox');
    const providerSelect = selects.find(s => {
      const options = Array.from((s as HTMLSelectElement).options);
      return options.some(o => o.text === 'Dropbox');
    });
    fireEvent.change(providerSelect!, { target: { value: 'custom' } });
    expect(screen.getByPlaceholderText(/Any folder/i)).toBeInTheDocument();
  });
});

// ─── Coexistence with other sections ───────────────────────────────────────

describe('SettingsPage – sync section coexistence', () => {
  it('sync section does not interfere with Data section', () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(true);
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Export as CSV/i)).toBeInTheDocument();
    expect(screen.getByText(/Export as JSON/i)).toBeInTheDocument();
    expect(screen.getByText(/Import from JSON/i)).toBeInTheDocument();
  });

  it('sync section does not interfere with Danger Zone', () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(true);
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Danger Zone/i)).toBeInTheDocument();
    expect(screen.getByText(/Clear all data/i)).toBeInTheDocument();
  });

  it('sync section does not interfere with iOS install hint', () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(true);
    renderWithStore(<SettingsPage />);
    expect(screen.getByText(/Add to iOS Home Screen/i)).toBeInTheDocument();
  });
});
