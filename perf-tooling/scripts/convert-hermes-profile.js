#!/usr/bin/env node
/**
 * Standalone Hermes-sampling-profile -> Chrome-trace converter.
 *
 * Replaces `npx react-native-release-profiler` (whose CLI hard-depends on
 * @react-native-community/cli-tools, which Expo apps do not ship). We only
 * need the profile transformer + a sourcemap, both resolvable from the app's
 * node_modules.
 *
 * Usage:
 *   node convert-hermes-profile.js \
 *     --in <raw.cpuprofile.txt> --out <converted.json> \
 *     --sourcemap <index.android.bundle.map> [--app-dir <dir>]
 */
const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const a = {};
  for (let i = 2; i < argv.length; i += 2) {
    const k = argv[i].replace(/^--/, '');
    a[k] = argv[i + 1];
  }
  return a;
}

// Mirror of react-native-release-profiler's maybeAddLineAndColumn: Hermes
// emits funcVirtAddr/offset; the transformer wants line/column.
function maybeAddLineAndColumn(file) {
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  const frames = json.stackFrames;
  if (!frames) return;
  for (const key of Object.keys(frames)) {
    const f = frames[key];
    if (f.funcVirtAddr && f.offset) {
      f.line = '1';
      f.column = `${parseInt(f.funcVirtAddr, 10) + parseInt(f.offset, 10) + 1}`;
      delete f.funcVirtAddr;
      delete f.offset;
    }
  }
  fs.writeFileSync(file, JSON.stringify(json));
}

async function main() {
  const args = parseArgs(process.argv);
  const inFile = args.in;
  const outFile = args.out;
  const sourcemap = args.sourcemap || undefined;
  const appDir = args['app-dir'] || process.cwd();

  if (!inFile || !outFile) {
    console.error('usage: convert-hermes-profile.js --in <raw> --out <json> [--sourcemap <map>] [--app-dir <dir>]');
    process.exit(2);
  }

  const transformerPath = require.resolve('@margelo/hermes-profile-transformer', {
    paths: [
      path.join(appDir, 'node_modules', 'react-native-release-profiler'),
      appDir,
    ],
  });
  const mod = require(transformerPath);
  const transform = mod.default || mod;

  maybeAddLineAndColumn(inFile);
  const events = await transform(inFile, sourcemap, 'index.bundle');

  const out = events.map((e) => JSON.stringify(e, undefined, 4)).join(',');
  fs.writeFileSync(outFile, '[' + out + ']', 'utf8');
  console.error(`[convert] wrote ${outFile} (${events.length} events)`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
