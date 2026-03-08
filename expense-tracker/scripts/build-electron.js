/**
 * Build script for Electron main + preload.
 * Uses esbuild to bundle the electron/ directory into dist-electron/.
 * This runs after `vite build` so the renderer (dist/) is already ready.
 */
import { build } from 'esbuild';
import { rmSync } from 'node:fs';

const outDir = 'dist-electron';

// Clean previous build
try { rmSync(outDir, { recursive: true }); } catch { /* noop */ }

const shared = {
  platform: 'node',
  format: 'esm',
  target: 'node20',
  outdir: outDir,
  bundle: true,
  external: ['electron'],
  sourcemap: true,
  minify: false,
};

await Promise.all([
  build({
    ...shared,
    entryPoints: ['electron/main.ts'],
  }),
  build({
    ...shared,
    entryPoints: ['electron/preload.ts'],
  }),
  build({
    ...shared,
    entryPoints: ['electron/fileSync.ts'],
  }),
]);

console.log('Electron build complete → dist-electron/');
