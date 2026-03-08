/**
 * File-based sync adapter for the renderer process.
 * Talks to the Electron main process via the preload-exposed `electronSync` API.
 * In the browser (non-Electron), all operations are no-ops.
 */
import type { AppState, SyncConfig } from '../types';

export function isElectronApp(): boolean {
  return !!window.isElectron && !!window.electronSync;
}

/** Open a native folder picker and return the selected path. */
export async function pickSyncFolder(): Promise<string | null> {
  if (!window.electronSync) return null;
  return window.electronSync.pickFolder();
}

/** Configure the file sync in the main process. */
export async function configureSync(config: SyncConfig): Promise<{ ok: boolean; error?: string }> {
  if (!window.electronSync) return { ok: false, error: 'Not running in Electron' };
  if (!config.enabled) {
    await window.electronSync.stop();
    return { ok: true };
  }
  return window.electronSync.configure({
    folderPath: config.folderPath,
    filename: config.filename,
  });
}

/** Read the full state from the sync file. */
export async function readSyncFile(): Promise<AppState | null> {
  if (!window.electronSync) return null;
  const raw = await window.electronSync.read();
  if (!raw) return null;
  try {
    return JSON.parse(raw) as AppState;
  } catch {
    return null;
  }
}

/** Write the full state to the sync file. */
export async function writeSyncFile(state: AppState): Promise<void> {
  if (!window.electronSync) return;
  const data = JSON.stringify(state, null, 2);
  await window.electronSync.write(data);
}

/** Subscribe to external changes (from other devices via cloud sync). */
export function onSyncFileChanged(callback: (state: AppState) => void): () => void {
  if (!window.electronSync) return () => {};
  return window.electronSync.onExternalChange((raw: string) => {
    try {
      const state = JSON.parse(raw) as AppState;
      callback(state);
    } catch {
      // Invalid JSON, skip
    }
  });
}
