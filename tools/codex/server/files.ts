import { isAbsolute, relative, resolve } from "node:path";

// The folder the Codex's page may load files from: the art.
const READABLE = ["assets"];

// The file on disk for a path from the repo's root, or a res:// path; null for anything outside
// the folders the page may load.
export function repoPath(repo: string, path: string): string | null {
  const plain = path.startsWith("res://") ? path.slice("res://".length) : path;
  if (isAbsolute(plain)) {
    return null;
  }
  const full = resolve(repo, plain);
  const inside = relative(repo, full);
  if (inside.startsWith("..") || isAbsolute(inside)) {
    return null;
  }
  const top = inside.split(/[\\/]/)[0];
  return READABLE.includes(top) ? full : null;
}
