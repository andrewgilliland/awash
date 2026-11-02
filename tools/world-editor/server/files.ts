import { isAbsolute, relative, resolve } from "node:path";

// The folders the World editor may read from: the art, the World's data, and the Rooms.
const READABLE = ["assets", "scenes"];

// The file on disk for a res:// path, or one from the repo's root; null for anything outside the
// folders the editor may read.
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
