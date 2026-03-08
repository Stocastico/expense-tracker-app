import { contextBridge, ipcRenderer } from 'electron';

export interface SyncAPI {
  pickFolder: () => Promise<string | null>;
  configure: (config: { folderPath: string; filename?: string }) => Promise<{ ok: boolean; error?: string }>;
  read: () => Promise<string | null>;
  write: (data: string) => Promise<{ ok: boolean; error?: string }>;
  stop: () => Promise<{ ok: boolean }>;
  getStatus: () => Promise<{ active: boolean; folderPath?: string; filename?: string }>;
  onExternalChange: (callback: (data: string) => void) => () => void;
}

const syncAPI: SyncAPI = {
  pickFolder: () => ipcRenderer.invoke('sync:pick-folder'),
  configure: (config) => ipcRenderer.invoke('sync:configure', config),
  read: () => ipcRenderer.invoke('sync:read'),
  write: (data) => ipcRenderer.invoke('sync:write', data),
  stop: () => ipcRenderer.invoke('sync:stop'),
  getStatus: () => ipcRenderer.invoke('sync:get-status'),
  onExternalChange: (callback) => {
    const handler = (_event: Electron.IpcRendererEvent, data: string) => callback(data);
    ipcRenderer.on('sync:external-change', handler);
    return () => ipcRenderer.removeListener('sync:external-change', handler);
  },
};

contextBridge.exposeInMainWorld('electronSync', syncAPI);
contextBridge.exposeInMainWorld('isElectron', true);
