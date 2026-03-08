import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  isElectronApp,
  pickSyncFolder,
  configureSync,
  readSyncFile,
  writeSyncFile,
  onSyncFileChanged,
} from '../../store/fileSync';
import type { AppState } from '../../types';
import { DEFAULT_SETTINGS } from '../../store/defaults';

const mockState: AppState = {
  transactions: [],
  budgets: [],
  settings: { ...DEFAULT_SETTINGS },
};

beforeEach(() => {
  // Reset window properties between tests
  delete (window as any).isElectron;
  delete (window as any).electronSync;
});

// ─── isElectronApp ─────────────────────────────────────────────────────────

describe('isElectronApp', () => {
  it('returns false when not in Electron', () => {
    expect(isElectronApp()).toBe(false);
  });

  it('returns false when isElectron is true but electronSync is missing', () => {
    (window as any).isElectron = true;
    expect(isElectronApp()).toBe(false);
  });

  it('returns true when both isElectron and electronSync are set', () => {
    (window as any).isElectron = true;
    (window as any).electronSync = {};
    expect(isElectronApp()).toBe(true);
  });
});

// ─── pickSyncFolder ────────────────────────────────────────────────────────

describe('pickSyncFolder', () => {
  it('returns null when not in Electron', async () => {
    const result = await pickSyncFolder();
    expect(result).toBeNull();
  });

  it('calls electronSync.pickFolder when available', async () => {
    const mockPickFolder = vi.fn().mockResolvedValue('/Users/test/Dropbox');
    (window as any).electronSync = { pickFolder: mockPickFolder };
    const result = await pickSyncFolder();
    expect(mockPickFolder).toHaveBeenCalled();
    expect(result).toBe('/Users/test/Dropbox');
  });

  it('returns null when user cancels folder picker', async () => {
    (window as any).electronSync = { pickFolder: vi.fn().mockResolvedValue(null) };
    const result = await pickSyncFolder();
    expect(result).toBeNull();
  });
});

// ─── configureSync ─────────────────────────────────────────────────────────

describe('configureSync', () => {
  it('returns error when not in Electron', async () => {
    const result = await configureSync({
      enabled: true,
      provider: 'dropbox',
      folderPath: '/test',
      filename: 'data.json',
    });
    expect(result.ok).toBe(false);
    expect(result.error).toContain('Not running in Electron');
  });

  it('calls stop when config.enabled is false', async () => {
    const mockStop = vi.fn().mockResolvedValue({ ok: true });
    (window as any).electronSync = { stop: mockStop };
    const result = await configureSync({
      enabled: false,
      provider: 'dropbox',
      folderPath: '',
      filename: '',
    });
    expect(mockStop).toHaveBeenCalled();
    expect(result.ok).toBe(true);
  });

  it('calls configure with folder and filename when enabled', async () => {
    const mockConfigure = vi.fn().mockResolvedValue({ ok: true });
    (window as any).electronSync = { configure: mockConfigure };
    const result = await configureSync({
      enabled: true,
      provider: 'onedrive',
      folderPath: '/Users/test/OneDrive',
      filename: 'expenses.json',
    });
    expect(mockConfigure).toHaveBeenCalledWith({
      folderPath: '/Users/test/OneDrive',
      filename: 'expenses.json',
    });
    expect(result.ok).toBe(true);
  });

  it('propagates error from configure', async () => {
    (window as any).electronSync = {
      configure: vi.fn().mockResolvedValue({ ok: false, error: 'Folder not found' }),
    };
    const result = await configureSync({
      enabled: true,
      provider: 'custom',
      folderPath: '/nonexistent',
      filename: 'data.json',
    });
    expect(result.ok).toBe(false);
    expect(result.error).toBe('Folder not found');
  });
});

// ─── readSyncFile ──────────────────────────────────────────────────────────

describe('readSyncFile', () => {
  it('returns null when not in Electron', async () => {
    expect(await readSyncFile()).toBeNull();
  });

  it('returns null when sync file has no content', async () => {
    (window as any).electronSync = { read: vi.fn().mockResolvedValue(null) };
    expect(await readSyncFile()).toBeNull();
  });

  it('parses valid JSON from the sync file', async () => {
    const data = JSON.stringify(mockState);
    (window as any).electronSync = { read: vi.fn().mockResolvedValue(data) };
    const result = await readSyncFile();
    expect(result).toEqual(mockState);
  });

  it('returns null for invalid JSON', async () => {
    (window as any).electronSync = { read: vi.fn().mockResolvedValue('not json {{{') };
    expect(await readSyncFile()).toBeNull();
  });

  it('returns null for empty string', async () => {
    (window as any).electronSync = { read: vi.fn().mockResolvedValue('') };
    // Empty string is falsy, so returns null
    expect(await readSyncFile()).toBeNull();
  });
});

// ─── writeSyncFile ─────────────────────────────────────────────────────────

describe('writeSyncFile', () => {
  it('does nothing when not in Electron', async () => {
    // Should not throw
    await expect(writeSyncFile(mockState)).resolves.toBeUndefined();
  });

  it('calls electronSync.write with stringified state', async () => {
    const mockWrite = vi.fn().mockResolvedValue({ ok: true });
    (window as any).electronSync = { write: mockWrite };
    await writeSyncFile(mockState);
    expect(mockWrite).toHaveBeenCalledTimes(1);
    const writtenData = JSON.parse(mockWrite.mock.calls[0][0]);
    expect(writtenData).toEqual(mockState);
  });

  it('writes formatted JSON (pretty-printed)', async () => {
    const mockWrite = vi.fn().mockResolvedValue({ ok: true });
    (window as any).electronSync = { write: mockWrite };
    await writeSyncFile(mockState);
    const raw = mockWrite.mock.calls[0][0];
    // Pretty-printed JSON has newlines
    expect(raw).toContain('\n');
  });
});

// ─── onSyncFileChanged ────────────────────────────────────────────────────

describe('onSyncFileChanged', () => {
  it('returns a no-op unsubscribe when not in Electron', () => {
    const callback = vi.fn();
    const unsub = onSyncFileChanged(callback);
    expect(typeof unsub).toBe('function');
    unsub(); // should not throw
    expect(callback).not.toHaveBeenCalled();
  });

  it('registers callback via electronSync.onExternalChange', () => {
    const mockUnsub = vi.fn();
    const mockOnChange = vi.fn().mockReturnValue(mockUnsub);
    (window as any).electronSync = { onExternalChange: mockOnChange };

    const callback = vi.fn();
    const unsub = onSyncFileChanged(callback);
    expect(mockOnChange).toHaveBeenCalledTimes(1);

    // Simulate an external change by calling the registered handler
    const handler = mockOnChange.mock.calls[0][0];
    handler(JSON.stringify(mockState));
    expect(callback).toHaveBeenCalledWith(mockState);

    // Unsubscribe
    unsub();
    expect(mockUnsub).toHaveBeenCalled();
  });

  it('ignores invalid JSON from external changes', () => {
    const mockOnChange = vi.fn().mockReturnValue(vi.fn());
    (window as any).electronSync = { onExternalChange: mockOnChange };

    const callback = vi.fn();
    onSyncFileChanged(callback);
    const handler = mockOnChange.mock.calls[0][0];

    // Send invalid JSON — callback should NOT be called
    handler('broken json {{{');
    expect(callback).not.toHaveBeenCalled();
  });

  it('handles multiple external change events', () => {
    const mockOnChange = vi.fn().mockReturnValue(vi.fn());
    (window as any).electronSync = { onExternalChange: mockOnChange };

    const callback = vi.fn();
    onSyncFileChanged(callback);
    const handler = mockOnChange.mock.calls[0][0];

    const state1 = { ...mockState, transactions: [{ id: 'tx1' }] };
    const state2 = { ...mockState, transactions: [{ id: 'tx1' }, { id: 'tx2' }] };

    handler(JSON.stringify(state1));
    handler(JSON.stringify(state2));
    expect(callback).toHaveBeenCalledTimes(2);
  });
});
