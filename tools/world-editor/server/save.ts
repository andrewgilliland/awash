import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

// The files the World editor writes. Room scenes join when it paints their tiles.
const WRITABLE = ["assets/world.json"];

export type SaveResult = { saved: true; version: string } | { saved: false; reason: "changed" | "not writable" };

// A file's version: a hash of its contents, so a save can tell if it changed since it was loaded.
export function versionOf(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

// Writes a file the editor owns, but only over the version it was loaded from: if it changed on
// disk since (Godot saved it, or another edit), nothing is written.
export async function saveFile(repo: string, path: string, base: string, text: string): Promise<SaveResult> {
  if (!WRITABLE.includes(path)) {
    return { saved: false, reason: "not writable" };
  }
  const full = resolve(repo, path);
  const current = await readFile(full, "utf8").catch(() => "");
  if (versionOf(current) !== base) {
    return { saved: false, reason: "changed" };
  }
  await writeFile(full, text);
  return { saved: true, version: versionOf(text) };
}
