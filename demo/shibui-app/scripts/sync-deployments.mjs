#!/usr/bin/env node
// Copies deployments/sepolia.json from the repo root into lib/_deployments.generated.json
// so TypeScript can `import` it with strict resolveJsonModule semantics.
// The repo-root file remains the canonical source of truth.

import { copyFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const src = resolve(__dirname, "../../../deployments/sepolia.json");
const dest = resolve(__dirname, "../lib/_deployments.generated.json");

if (!existsSync(src)) {
  console.error(`[sync-deployments] canonical file missing: ${src}`);
  process.exit(1);
}

mkdirSync(dirname(dest), { recursive: true });
copyFileSync(src, dest);
console.log(`[sync-deployments] ${src} -> ${dest}`);
