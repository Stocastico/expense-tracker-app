/** Types exposed by electron/preload.ts via contextBridge */
interface ElectronSyncAPI {
  pickFolder: () => Promise<string | null>;
  configure: (config: { folderPath: string; filename?: string }) => Promise<{ ok: boolean; error?: string }>;
  read: () => Promise<string | null>;
  write: (data: string) => Promise<{ ok: boolean; error?: string }>;
  stop: () => Promise<{ ok: boolean }>;
  getStatus: () => Promise<{ active: boolean; folderPath?: string; filename?: string }>;
  onExternalChange: (callback: (data: string) => void) => () => void;
}

interface Window {
  isElectron?: boolean;
  electronSync?: ElectronSyncAPI;
}
