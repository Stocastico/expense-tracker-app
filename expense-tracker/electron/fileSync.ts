import fs from 'node:fs';
import path from 'node:path';

/**
 * FileSyncManager – reads/writes a JSON file in a cloud-synced folder.
 *
 * The idea: the user points this at their Dropbox, OneDrive, iCloud Drive,
 * or Google Drive folder. The cloud provider handles syncing the file across
 * devices. This module handles reading, writing, and watching for external
 * changes (i.e. changes made by another device that get pulled in by the
 * cloud client).
 *
 * Conflict resolution: last-write-wins based on the `updatedAt` timestamp
 * embedded in the JSON. A smarter merge is possible but YAGNI for now.
 */
export class FileSyncManager {
  readonly folderPath: string;
  readonly filename: string;
  private filePath: string;
  private watcher: fs.FSWatcher | null = null;
  private changeCallback: ((data: string) => void) | null = null;
  private lastWriteTime = 0;
  private debounceTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(folderPath: string, filename: string) {
    this.folderPath = folderPath;
    this.filename = filename;
    this.filePath = path.join(folderPath, filename);
  }

  /** Read the sync file. Returns null if the file doesn't exist yet. */
  async read(): Promise<string | null> {
    try {
      return await fs.promises.readFile(this.filePath, 'utf-8');
    } catch (err: unknown) {
      if (err instanceof Error && 'code' in err && (err as NodeJS.ErrnoException).code === 'ENOENT') {
        return null;
      }
      throw err;
    }
  }

  /** Write data to the sync file. Creates the file if it doesn't exist. */
  async write(data: string): Promise<void> {
    this.lastWriteTime = Date.now();
    // Write to a temp file then rename for atomicity
    const tmpPath = this.filePath + '.tmp';
    await fs.promises.writeFile(tmpPath, data, 'utf-8');
    await fs.promises.rename(tmpPath, this.filePath);
  }

  /** Register a callback for when the file changes externally. */
  onExternalChange(callback: (data: string) => void) {
    this.changeCallback = callback;
  }

  /** Start watching the sync file for changes from other devices. */
  startWatching() {
    if (this.watcher) return;

    try {
      this.watcher = fs.watch(this.filePath, (eventType) => {
        if (eventType !== 'change') return;

        // Ignore changes we just made ourselves (within 2s window)
        if (Date.now() - this.lastWriteTime < 2000) return;

        // Debounce: cloud providers sometimes trigger multiple events
        if (this.debounceTimer) clearTimeout(this.debounceTimer);
        this.debounceTimer = setTimeout(async () => {
          try {
            const data = await this.read();
            if (data && this.changeCallback) {
              this.changeCallback(data);
            }
          } catch {
            // File may be in the middle of a cloud sync, ignore
          }
        }, 500);
      });
    } catch {
      // File doesn't exist yet, that's fine – it will be created on first write
    }
  }

  /** Stop watching. */
  stopWatching() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }
  }
}
