// What the page shows, worked out without the page: where it is, which entries its list holds,
// and where each frame of a sheet lies.

import type { Sprite } from "../server/codex";

export const SECTIONS = ["enemies", "items", "characters", "regions"] as const;
export type Section = (typeof SECTIONS)[number];
export type Route = { section: Section; id: string | null };
// Entries in the game, only in the docs, or both.
export type Filter = "game" | "planned" | "all";

export function parseRoute(hash: string): Route {
  const [section, id] = hash.replace(/^#\/?/, "").split("/");
  if (!SECTIONS.includes(section as Section)) {
    return { section: "enemies", id: null };
  }
  return { section: section as Section, id: id ? decodeURIComponent(id) : null };
}

export function formatRoute(route: Route): string {
  return `#/${route.section}${route.id ? `/${encodeURIComponent(route.id)}` : ""}`;
}

export function shown<T extends { name: string; planned?: boolean }>(entries: T[], filter: Filter, query: string): T[] {
  const words = query.trim().toLowerCase();
  return entries.filter((entry) => {
    const planned = entry.planned ?? false;
    if ((filter === "game" && planned) || (filter === "planned" && !planned)) {
      return false;
    }
    return words === "" || entry.name.toLowerCase().includes(words);
  });
}

// The Items list's types: the Equipment first, then what you carry, then what you use up. Any other
// type follows, A to Z.
const KIND_ORDER = ["Weapon", "Armor", "Accessory", "Sub Weapon", "Ammunition", "Supply"];
const PLURALS: Record<string, string> = {
  Weapon: "Weapons",
  Armor: "Armor",
  Accessory: "Accessories",
  "Sub Weapon": "Sub Weapons",
  Ammunition: "Ammunition",
  Supply: "Supplies",
};

export type Group<T> = { kind: string; title: string; entries: T[] };

// Items split by their type, in the list's order, each keeping its items in the order they came.
export function byKind<T extends { kind: string }>(items: T[]): Group<T>[] {
  const groups = new Map<string, T[]>();
  for (const item of items) {
    groups.set(item.kind, [...(groups.get(item.kind) ?? []), item]);
  }
  const rank = (kind: string) => (KIND_ORDER.includes(kind) ? KIND_ORDER.indexOf(kind) : KIND_ORDER.length);
  return [...groups.keys()]
    .sort((a, b) => rank(a) - rank(b) || a.localeCompare(b))
    .map((kind) => ({ kind, title: PLURALS[kind] ?? `${kind}s`, entries: groups.get(kind) ?? [] }));
}

export type Rect = { x: number; y: number; w: number; h: number };

// Where a frame lies on its sheet: by a frame's size along one row, by a grid across and down, or
// as squares the sheet's height.
export function frameRect(sprite: Sprite, width: number, height: number, index: number): Rect {
  if (sprite.grid) {
    const [across, down] = sprite.grid;
    const w = width / across;
    const h = height / down;
    return { x: (index % across) * w, y: Math.floor(index / across) * h, w, h };
  }
  const [w, h] = sprite.frame ?? [height, height];
  const across = Math.max(1, Math.floor(width / w));
  return { x: (index % across) * w, y: Math.floor(index / across) * h, w, h };
}

// How many frames a sheet holds.
export function frameCount(sprite: Sprite, width: number, height: number): number {
  if (sprite.grid) {
    return sprite.grid[0] * sprite.grid[1];
  }
  const [w, h] = sprite.frame ?? [height, height];
  return Math.max(1, Math.floor(width / w)) * Math.max(1, Math.floor(height / h));
}
