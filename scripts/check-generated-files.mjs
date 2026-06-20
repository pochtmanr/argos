// /Users/roman/Developer/iosbrowser/scripts/check-generated-files.mjs
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const ignored = new Set(["node_modules", ".git", "dist", ".build", ".pnpm-store"]);

async function walk(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    if (ignored.has(entry.name)) continue;
    const absolute = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...await walk(absolute));
    else files.push(absolute);
  }
  return files;
}

const files = await walk(root);
const missing = [];
for (const file of files) {
  const text = await readFile(file, "utf8");
  if (!text.includes(file)) missing.push(file);
}

if (missing.length > 0) {
  console.error("Files missing exact path marker:");
  for (const file of missing) console.error(file);
  process.exit(1);
}

console.log(`Checked ${files.length} generated files.`);
