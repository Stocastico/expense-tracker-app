/**
 * Tests for useStore file sync integration.
 * We mock the fileSync module so these tests work in jsdom (no Electron).
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';

// Mock the fileSync module before importing useStore
vi.mock('../../store/fileSync', () => ({
  isElectronApp: vi.fn(() => false),
  configureSync: vi.fn(async () => ({ ok: true })),
  readSyncFile: vi.fn(async () => null),
  writeSyncFile: vi.fn(async () => {}),
  onSyncFileChanged: vi.fn(() => vi.fn()),
}));

import { useStore } from '../../store/useStore';
import * as fileSync from '../../store/fileSync';

beforeEach(() => {
  localStorage.clear();
  document.documentElement.classList.remove('dark');
  vi.clearAllMocks();
});

// ─── fileSyncActive state ──────────────────────────────────────────────────

describe('fileSyncActive', () => {
  it('defaults to false', () => {
    const { result } = renderHook(() => useStore());
    expect(result.current.fileSyncActive).toBe(false);
  });

  it('exposes enableFileSync and disableFileSync functions', () => {
    const { result } = renderHook(() => useStore());
    expect(typeof result.current.enableFileSync).toBe('function');
    expect(typeof result.current.disableFileSync).toBe('function');
  });
});

// ─── enableFileSync ────────────────────────────────────────────────────────

describe('enableFileSync', () => {
  it('calls configureSync and sets fileSyncActive to true', async () => {
    const { result } = renderHook(() => useStore());

    await act(async () => {
      const res = await result.current.enableFileSync({
        enabled: true,
        provider: 'dropbox',
        folderPath: '/Users/test/Dropbox',
        filename: 'expense-tracker-data.json',
      });
      expect(res).toEqual({ ok: true });
    });

    expect(fileSync.configureSync).toHaveBeenCalledWith({
      enabled: true,
      provider: 'dropbox',
      folderPath: '/Users/test/Dropbox',
      filename: 'expense-tracker-data.json',
    });
    expect(result.current.fileSyncActive).toBe(true);
  });

  it('saves syncConfig to settings', async () => {
    const { result } = renderHook(() => useStore());
    const config = {
      enabled: true,
      provider: 'onedrive' as const,
      folderPath: '/Users/test/OneDrive',
      filename: 'expenses.json',
    };

    await act(async () => {
      await result.current.enableFileSync(config);
    });

    expect(result.current.settings.syncConfig).toEqual(config);
  });

  it('writes current state to sync file immediately', async () => {
    const { result } = renderHook(() => useStore());

    await act(async () => {
      await result.current.enableFileSync({
        enabled: true,
        provider: 'dropbox',
        folderPath: '/test',
        filename: 'data.json',
      });
    });

    expect(fileSync.writeSyncFile).toHaveBeenCalled();
  });

  it('returns error when configureSync fails', async () => {
    vi.mocked(fileSync.configureSync).mockResolvedValueOnce({
      ok: false,
      error: 'Folder does not exist',
    });

    const { result } = renderHook(() => useStore());

    await act(async () => {
      const res = await result.current.enableFileSync({
        enabled: true,
        provider: 'custom',
        folderPath: '/bad/path',
        filename: 'data.json',
      });
      expect(res).toEqual({ ok: false, error: 'Folder does not exist' });
    });

    expect(result.current.fileSyncActive).toBe(false);
  });

  it('does not set fileSyncActive when configureSync fails', async () => {
    vi.mocked(fileSync.configureSync).mockResolvedValueOnce({
      ok: false,
      error: 'Failed',
    });

    const { result } = renderHook(() => useStore());

    await act(async () => {
      await result.current.enableFileSync({
        enabled: true,
        provider: 'dropbox',
        folderPath: '/bad',
        filename: 'data.json',
      });
    });

    expect(result.current.fileSyncActive).toBe(false);
    expect(result.current.settings.syncConfig).toBeUndefined();
  });
});

// ─── disableFileSync ───────────────────────────────────────────────────────

describe('disableFileSync', () => {
  it('calls configureSync with enabled=false and sets fileSyncActive to false', async () => {
    const { result } = renderHook(() => useStore());

    // First enable
    await act(async () => {
      await result.current.enableFileSync({
        enabled: true,
        provider: 'dropbox',
        folderPath: '/test',
        filename: 'data.json',
      });
    });
    expect(result.current.fileSyncActive).toBe(true);

    // Then disable
    await act(async () => {
      await result.current.disableFileSync();
    });

    expect(result.current.fileSyncActive).toBe(false);
    expect(result.current.settings.syncConfig).toBeUndefined();
    expect(fileSync.configureSync).toHaveBeenCalledWith({
      enabled: false,
      provider: 'custom',
      folderPath: '',
      filename: '',
    });
  });

  it('is safe to call when sync is not active', async () => {
    const { result } = renderHook(() => useStore());

    await act(async () => {
      await result.current.disableFileSync();
    });

    expect(result.current.fileSyncActive).toBe(false);
  });
});

// ─── File sync init on mount (Electron mode) ──────────────────────────────

describe('file sync initialization', () => {
  it('does not initialize file sync when not in Electron', () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(false);
    renderHook(() => useStore());
    expect(fileSync.configureSync).not.toHaveBeenCalled();
  });

  it('does not initialize when syncConfig is not enabled', () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(true);
    // No syncConfig in localStorage
    renderHook(() => useStore());
    expect(fileSync.configureSync).not.toHaveBeenCalled();
  });

  it('initializes file sync when Electron + syncConfig enabled', async () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(true);
    vi.mocked(fileSync.readSyncFile).mockResolvedValue(null);

    // Pre-populate localStorage with sync config
    const state = {
      transactions: [],
      budgets: [],
      settings: {
        currency: 'USD',
        darkMode: false,
        categories: [],
        startOfMonth: 1,
        defaultAccount: 'personal',
        syncConfig: {
          enabled: true,
          provider: 'dropbox',
          folderPath: '/Users/test/Dropbox',
          filename: 'data.json',
        },
      },
    };
    localStorage.setItem('expense_tracker_v1', JSON.stringify(state));

    const { result } = renderHook(() => useStore());

    // Wait for async setup
    await act(async () => {
      await new Promise(r => setTimeout(r, 50));
    });

    expect(fileSync.configureSync).toHaveBeenCalled();
    expect(result.current.fileSyncActive).toBe(true);
  });

  it('loads data from sync file on startup when available', async () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(true);

    const syncData = {
      transactions: [
        {
          id: 'synced-tx', type: 'expense' as const, amount: 99, currency: 'EUR',
          categoryId: 'food', description: 'Synced item', date: '2024-06-01',
          tags: [], isRecurring: false, accountId: 'personal' as const,
          createdAt: '2024-06-01T00:00:00Z', updatedAt: '2024-06-01T00:00:00Z',
        },
      ],
      budgets: [],
      settings: { currency: 'EUR' },
    };
    vi.mocked(fileSync.readSyncFile).mockResolvedValue(syncData as any);

    const state = {
      transactions: [],
      budgets: [],
      settings: {
        currency: 'USD',
        darkMode: false,
        categories: [],
        startOfMonth: 1,
        defaultAccount: 'personal',
        syncConfig: {
          enabled: true,
          provider: 'icloud',
          folderPath: '/Users/test/iCloud',
          filename: 'data.json',
        },
      },
    };
    localStorage.setItem('expense_tracker_v1', JSON.stringify(state));

    const { result } = renderHook(() => useStore());

    await act(async () => {
      await new Promise(r => setTimeout(r, 100));
    });

    expect(result.current.transactions).toHaveLength(1);
    expect(result.current.transactions[0].id).toBe('synced-tx');
    expect(result.current.settings.currency).toBe('EUR');
    // syncConfig should be preserved from local, not overwritten by sync file
    expect(result.current.settings.syncConfig?.provider).toBe('icloud');
  });

  it('subscribes to external changes via onSyncFileChanged', async () => {
    vi.mocked(fileSync.isElectronApp).mockReturnValue(true);
    vi.mocked(fileSync.readSyncFile).mockResolvedValue(null);

    const state = {
      transactions: [],
      budgets: [],
      settings: {
        currency: 'USD',
        darkMode: false,
        categories: [],
        startOfMonth: 1,
        defaultAccount: 'personal',
        syncConfig: {
          enabled: true,
          provider: 'dropbox',
          folderPath: '/test',
          filename: 'data.json',
        },
      },
    };
    localStorage.setItem('expense_tracker_v1', JSON.stringify(state));

    renderHook(() => useStore());

    await act(async () => {
      await new Promise(r => setTimeout(r, 50));
    });

    expect(fileSync.onSyncFileChanged).toHaveBeenCalled();
  });
});

// ─── Sync config with different providers ──────────────────────────────────

describe('sync providers', () => {
  const providers = ['dropbox', 'onedrive', 'icloud', 'googledrive', 'custom'] as const;

  providers.forEach(provider => {
    it(`supports ${provider} provider`, async () => {
      const { result } = renderHook(() => useStore());

      await act(async () => {
        await result.current.enableFileSync({
          enabled: true,
          provider,
          folderPath: `/test/${provider}`,
          filename: 'data.json',
        });
      });

      expect(result.current.settings.syncConfig?.provider).toBe(provider);
      expect(result.current.fileSyncActive).toBe(true);
    });
  });
});

// ─── Enable / disable cycle ────────────────────────────────────────────────

describe('enable-disable cycle', () => {
  it('can enable, disable, and re-enable sync', async () => {
    const { result } = renderHook(() => useStore());
    const config = {
      enabled: true,
      provider: 'dropbox' as const,
      folderPath: '/test',
      filename: 'data.json',
    };

    // Enable
    await act(async () => {
      await result.current.enableFileSync(config);
    });
    expect(result.current.fileSyncActive).toBe(true);

    // Disable
    await act(async () => {
      await result.current.disableFileSync();
    });
    expect(result.current.fileSyncActive).toBe(false);

    // Re-enable
    await act(async () => {
      await result.current.enableFileSync(config);
    });
    expect(result.current.fileSyncActive).toBe(true);
  });
});
