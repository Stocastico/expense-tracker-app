/**
 * @vitest-environment node
 */
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { FileSyncManager } from '../../../electron/fileSync';

let tmpDir: string;
let manager: FileSyncManager;

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'filesync-test-'));
  manager = new FileSyncManager(tmpDir, 'test-data.json');
});

afterEach(() => {
  manager.stopWatching();
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

// ─── Constructor ───────────────────────────────────────────────────────────

describe('constructor', () => {
  it('sets folderPath and filename', () => {
    expect(manager.folderPath).toBe(tmpDir);
    expect(manager.filename).toBe('test-data.json');
  });

  it('accepts custom filenames', () => {
    const custom = new FileSyncManager('/tmp', 'custom.json');
    expect(custom.filename).toBe('custom.json');
  });
});

// ─── read ──────────────────────────────────────────────────────────────────

describe('read', () => {
  it('returns null when file does not exist', async () => {
    const result = await manager.read();
    expect(result).toBeNull();
  });

  it('returns file content when file exists', async () => {
    const filePath = path.join(tmpDir, 'test-data.json');
    const content = JSON.stringify({ hello: 'world' });
    fs.writeFileSync(filePath, content, 'utf-8');
    const result = await manager.read();
    expect(result).toBe(content);
  });

  it('returns raw string content (does not parse JSON)', async () => {
    const filePath = path.join(tmpDir, 'test-data.json');
    fs.writeFileSync(filePath, 'not json', 'utf-8');
    const result = await manager.read();
    expect(result).toBe('not json');
  });

  it('throws for non-ENOENT errors', async () => {
    // Create a directory with the same name as the file to cause EISDIR
    const filePath = path.join(tmpDir, 'test-data.json');
    fs.mkdirSync(filePath);
    await expect(manager.read()).rejects.toThrow();
  });
});

// ─── write ─────────────────────────────────────────────────────────────────

describe('write', () => {
  it('creates the file when it does not exist', async () => {
    await manager.write('{"test": true}');
    const filePath = path.join(tmpDir, 'test-data.json');
    expect(fs.existsSync(filePath)).toBe(true);
    expect(fs.readFileSync(filePath, 'utf-8')).toBe('{"test": true}');
  });

  it('overwrites existing file content', async () => {
    await manager.write('first');
    await manager.write('second');
    const filePath = path.join(tmpDir, 'test-data.json');
    expect(fs.readFileSync(filePath, 'utf-8')).toBe('second');
  });

  it('uses atomic write (no .tmp file left behind)', async () => {
    await manager.write('data');
    const tmpFile = path.join(tmpDir, 'test-data.json.tmp');
    expect(fs.existsSync(tmpFile)).toBe(false);
  });

  it('writes large content correctly', async () => {
    const largeContent = JSON.stringify({ data: 'x'.repeat(100000) });
    await manager.write(largeContent);
    const result = await manager.read();
    expect(result).toBe(largeContent);
  });
});

// ─── onExternalChange / startWatching / stopWatching ───────────────────────

describe('watching', () => {
  it('startWatching does not throw when file does not exist', () => {
    expect(() => manager.startWatching()).not.toThrow();
  });

  it('startWatching is idempotent (can be called multiple times)', async () => {
    const filePath = path.join(tmpDir, 'test-data.json');
    fs.writeFileSync(filePath, 'init', 'utf-8');
    manager.startWatching();
    manager.startWatching(); // second call should not create another watcher
    manager.stopWatching();
  });

  it('stopWatching is safe to call when not watching', () => {
    expect(() => manager.stopWatching()).not.toThrow();
  });

  it('stopWatching cleans up the watcher', async () => {
    const filePath = path.join(tmpDir, 'test-data.json');
    fs.writeFileSync(filePath, 'init', 'utf-8');
    manager.startWatching();
    manager.stopWatching();
    // Should be safe to call again
    expect(() => manager.stopWatching()).not.toThrow();
  });

  it('ignores self-writes within 2s window', async () => {
    const callback = vi.fn();
    const filePath = path.join(tmpDir, 'test-data.json');
    fs.writeFileSync(filePath, 'init', 'utf-8');

    manager.onExternalChange(callback);
    manager.startWatching();

    // Write via manager (should be ignored)
    await manager.write('self-update');

    // Wait for debounce to pass
    await new Promise(r => setTimeout(r, 700));
    expect(callback).not.toHaveBeenCalled();
    manager.stopWatching();
  });

  it('detects external file changes', async () => {
    const callback = vi.fn();
    const filePath = path.join(tmpDir, 'test-data.json');
    fs.writeFileSync(filePath, 'init', 'utf-8');

    manager.onExternalChange(callback);
    manager.startWatching();

    // Simulate external change (e.g. from cloud sync)
    // Need to wait past the self-write window
    await new Promise(r => setTimeout(r, 100));
    fs.writeFileSync(filePath, 'external-update', 'utf-8');

    // Wait for debounce (500ms) + extra buffer
    await new Promise(r => setTimeout(r, 1000));
    expect(callback).toHaveBeenCalledWith('external-update');
    manager.stopWatching();
  }, 5000);

  it('does not fire callback for non-change events', async () => {
    const callback = vi.fn();
    const filePath = path.join(tmpDir, 'test-data.json');
    fs.writeFileSync(filePath, 'init', 'utf-8');

    manager.onExternalChange(callback);
    manager.startWatching();

    // Just read — should not trigger
    await manager.read();
    await new Promise(r => setTimeout(r, 700));
    expect(callback).not.toHaveBeenCalled();
    manager.stopWatching();
  });
});

// ─── Integration ───────────────────────────────────────────────────────────

describe('read-write roundtrip', () => {
  it('roundtrips JSON data', async () => {
    const state = {
      transactions: [{ id: 'tx1', amount: 42.5 }],
      budgets: [],
      settings: { currency: 'EUR' },
    };
    await manager.write(JSON.stringify(state));
    const raw = await manager.read();
    expect(JSON.parse(raw!)).toEqual(state);
  });

  it('handles unicode content', async () => {
    const content = JSON.stringify({ description: 'Café ☕ résumé 日本語' });
    await manager.write(content);
    const result = await manager.read();
    expect(result).toBe(content);
  });

  it('handles empty JSON object', async () => {
    await manager.write('{}');
    expect(await manager.read()).toBe('{}');
  });
});
