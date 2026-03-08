import { app, BrowserWindow, ipcMain, dialog, shell } from 'electron';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { FileSyncManager } from './fileSync.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let mainWindow: BrowserWindow | null = null;
let syncManager: FileSyncManager | null = null;

const DIST = path.join(__dirname, '../dist');
const VITE_DEV_SERVER_URL = process.env.VITE_DEV_SERVER_URL;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 750,
    minWidth: 420,
    minHeight: 600,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 16, y: 16 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: path.join(DIST, 'pwa-512x512.png'),
    backgroundColor: '#ffffff',
    show: false,
  });

  mainWindow.once('ready-to-show', () => mainWindow?.show());

  if (VITE_DEV_SERVER_URL) {
    mainWindow.loadURL(VITE_DEV_SERVER_URL);
  } else {
    mainWindow.loadFile(path.join(DIST, 'index.html'));
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Open external links in default browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
}

// ── File Sync IPC handlers ──────────────────────────────────────────────────

ipcMain.handle('sync:pick-folder', async () => {
  if (!mainWindow) return null;
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory', 'createDirectory'],
    title: 'Choose sync folder (e.g. your Dropbox or OneDrive folder)',
    buttonLabel: 'Select Folder',
  });
  if (result.canceled || result.filePaths.length === 0) return null;
  return result.filePaths[0];
});

ipcMain.handle('sync:configure', async (_event, config: { folderPath: string; filename?: string }) => {
  try {
    if (syncManager) {
      syncManager.stopWatching();
    }
    syncManager = new FileSyncManager(config.folderPath, config.filename ?? 'expense-tracker-data.json');
    syncManager.onExternalChange((data) => {
      mainWindow?.webContents.send('sync:external-change', data);
    });
    syncManager.startWatching();
    return { ok: true };
  } catch (err) {
    return { ok: false, error: String(err) };
  }
});

ipcMain.handle('sync:read', async () => {
  if (!syncManager) return null;
  try {
    return await syncManager.read();
  } catch {
    return null;
  }
});

ipcMain.handle('sync:write', async (_event, data: string) => {
  if (!syncManager) return { ok: false, error: 'Sync not configured' };
  try {
    await syncManager.write(data);
    return { ok: true };
  } catch (err) {
    return { ok: false, error: String(err) };
  }
});

ipcMain.handle('sync:stop', async () => {
  if (syncManager) {
    syncManager.stopWatching();
    syncManager = null;
  }
  return { ok: true };
});

ipcMain.handle('sync:get-status', async () => {
  if (!syncManager) return { active: false };
  return { active: true, folderPath: syncManager.folderPath, filename: syncManager.filename };
});

// ── App lifecycle ───────────────────────────────────────────────────────────

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (syncManager) syncManager.stopWatching();
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
