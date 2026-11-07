import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { parse as parseYaml } from "yaml";
import { isCall, isName, isRef, type DictEntry, type Value } from "./gdscript.ts";
import { readScene, type Scene } from "./tscn.ts";

// What the Codex's readers share: the repo's files, its built Rooms, the docs' frontmatter, and
// the values read from Godot's files.

export interface World {
  regions: Record<string, { name: string; colour: string }>;
  rooms: Record<
    string,
    { scene?: string; region: string; size: [number, number]; markers?: Record<string, unknown> }
  >;
}

// A built Room, as the Codex needs it: its Region (by id and by name), its markers, and its scene.
export interface Room {
  id: string;
  regionId: string;
  region: string;
  size: [number, number];
  markers: string[];
  scene: Scene;
}

export class Files {
  constructor(private readonly repo: string) {}

  text(path: string): Promise<string> {
    return readFile(resolve(this.repo, local(path)), "utf8");
  }

  async textOrNull(path: string): Promise<string | null> {
    try {
      return await this.text(path);
    } catch {
      return null;
    }
  }

  async list(folder: string, extension: string): Promise<string[]> {
    try {
      const names = await readdir(resolve(this.repo, folder), { recursive: true });
      return names
        .filter((name) => name.endsWith(extension))
        .map((name) => `${folder}/${name}`)
        .sort();
    } catch {
      return [];
    }
  }
}

// A path from the repo's root, for a res:// one.
export function local(path: string): string {
  return path.startsWith("res://") ? path.slice("res://".length) : path;
}

export async function readRooms(files: Files, world: World): Promise<Room[]> {
  const rooms: Room[] = [];
  for (const [id, room] of Object.entries(world.rooms)) {
    if (!room.scene) {
      continue;
    }
    const text = await files.textOrNull(room.scene);
    if (text === null) {
      continue;
    }
    rooms.push({
      id,
      regionId: room.region,
      region: world.regions[room.region]?.name ?? room.region,
      size: room.size,
      markers: Object.keys(room.markers ?? {}),
      scene: readScene(text),
    });
  }
  return rooms;
}

// --- Docs ----------------------------------------------------------------------------------------

export interface Doc {
  path: string;
  data: Record<string, unknown>;
  body: string;
}

export async function readDocs(files: Files, folder: string): Promise<Doc[]> {
  const docs: Doc[] = [];
  for (const path of await files.list(folder, ".md")) {
    const text = await files.text(path);
    const match = /^---\n([\s\S]*?)\n---\n?([\s\S]*)$/.exec(text);
    if (!match) {
      continue;
    }
    try {
      docs.push({ path, data: (parseYaml(match[1]) ?? {}) as Record<string, unknown>, body: match[2] });
    } catch {
      // A doc whose frontmatter does not parse is left out.
    }
  }
  return docs;
}

export function field(data: Record<string, unknown>, name: string): string {
  const value = data[name];
  return typeof value === "string" || typeof value === "number" || typeof value === "boolean"
    ? String(value)
    : "";
}

// --- Values --------------------------------------------------------------------------------------

export function preloadPath(value: Value | undefined): string | null {
  return isCall(value, "preload") && typeof value.args[0] === "string" ? local(value.args[0]) : null;
}

export function vector(value: Value | undefined): [number, number] | null {
  if (isCall(value, "Vector2i") || isCall(value, "Vector2")) {
    const [x, y] = value.args;
    return typeof x === "number" && typeof y === "number" ? [x, y] : null;
  }
  return null;
}

export function entries(value: Value | undefined): DictEntry[] {
  return Array.isArray(value) && value.every((entry) => entry && typeof entry === "object" && "key" in entry)
    ? (value as DictEntry[])
    : [];
}

export function record(value: Value | undefined): Record<string, Value> {
  return value && typeof value === "object" && !Array.isArray(value) && !isCall(value) && !isRef(value)
    ? (value as Record<string, Value>)
    : {};
}

// A StringName key, or a const naming one, as its plain name.
export function keyName(key: Value, consts: Record<string, Value>): string | null {
  if (isName(key)) {
    return key.name;
  }
  if (isRef(key)) {
    const named = consts[key.ref];
    return named !== undefined && isName(named) ? named.name : null;
  }
  return null;
}

// A kind's name for one of it: Accessories, an Accessory; Weapons, a Weapon.
export function singular(kind: string): string {
  if (kind.endsWith("ies")) {
    return `${kind.slice(0, -3)}y`;
  }
  return kind.endsWith("s") && !kind.endsWith("ss") ? kind.slice(0, -1) : kind;
}

export function titled(id: string): string {
  return id
    .split(/[_-]/)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
}
