import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
await build({
  entryPoints: ['runtime/server.ts'], outfile: 'dist-node/server.mjs',
  bundle: true, platform: 'node', format: 'esm', target: 'node24',
  packages: 'external', sourcemap: false,
  alias: { 'cloudflare:workers': fileURLToPath(new URL('../runtime/env.ts', import.meta.url)) },
});
