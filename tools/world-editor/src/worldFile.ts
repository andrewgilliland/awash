// Writes the World's data as assets/world.json lays it out: one Room per block, its note first,
// vectors and small records inline, one Exit per line. Saving with no edits changes nothing.

import type { WorldData } from "./world";

// Each record's fields in the file's order; anything else follows in its own order.
const ROOM_ORDER = ["note", "scene", "cell", "size", "region", "background", "exits", "markers", "plan"];
const REGION_ORDER = ["note", "name", "colour", "theme", "background", "backgrounds"];

function inline(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(inline).join(", ")}]`;
  }
  if (value !== null && typeof value === "object") {
    return `{${Object.entries(value).map(([k, v]) => `${JSON.stringify(k)}: ${inline(v)}`).join(", ")}}`;
  }
  return JSON.stringify(value);
}

function ordered(record: Record<string, unknown>, order: string[]): [string, unknown][] {
  const known = order.filter((key) => key in record).map((key): [string, unknown] => [key, record[key]]);
  const rest = Object.entries(record).filter(([key]) => !order.includes(key));
  return [...known, ...rest];
}

function record(fields: Record<string, unknown>, order: string[], depth: number): string {
  const pad = "\t".repeat(depth);
  return ordered(fields, order)
    .map(([key, value]) => {
      if (key === "exits" && Array.isArray(value) && value.length > 0) {
        const lines = value.map((exit) => `${pad}\t${inline(exit)}`).join(",\n");
        return `${pad}"exits": [\n${lines}\n${pad}]`;
      }
      if (key === "plan" && value && typeof value === "object") {
        return `${pad}"plan": {\n${record(value as Record<string, unknown>, ROOM_ORDER, depth + 1)}\n${pad}}`;
      }
      return `${pad}${JSON.stringify(key)}: ${inline(value)}`;
    })
    .join(",\n");
}

function table(name: string, rows: Record<string, object>, order: string[]): string {
  const blocks = Object.entries(rows).map(
    ([id, row]) => `\t\t${JSON.stringify(id)}: {\n${record(row as Record<string, unknown>, order, 3)}\n\t\t}`,
  );
  return `\t${JSON.stringify(name)}: {\n${blocks.join(",\n")}\n\t}`;
}

export function serializeWorld(world: WorldData): string {
  return `{\n${table("regions", world.regions, REGION_ORDER)},\n${table("rooms", world.rooms, ROOM_ORDER)}\n}\n`;
}
