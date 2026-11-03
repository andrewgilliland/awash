// Painting a tile layer: its cells are changed by stamping a block of tiles, filling or erasing an
// area, and the eyedropper picks a stamp back up. Each returns new cells, inside the Room's bounds.

import type { Cell, Vec } from "./godot";

// A block of tiles from one sheet, row by row; null where the block has no tile.
export interface Stamp {
  source: number;
  tiles: (Vec | null)[][];
}

export type Area = { x: number; y: number; w: number; h: number };
// The cells a layer may hold: from x, y (0, 0 unless given), w across and h down.
export type Bounds = { x?: number; y?: number; w: number; h: number };

const key = (x: number, y: number) => `${x},${y}`;
const inside = (x: number, y: number, { x: left = 0, y: top = 0, w, h }: Bounds) =>
  x >= left && y >= top && x < left + w && y < top + h;

// The block of a sheet between two corners, picked in the palette: only tiles the sheet has.
export function blockStamp(source: number, from: Vec, to: Vec, has: Set<string>): Stamp {
  const [x0, x1] = [Math.min(from[0], to[0]), Math.max(from[0], to[0])];
  const [y0, y1] = [Math.min(from[1], to[1]), Math.max(from[1], to[1])];
  const tiles: (Vec | null)[][] = [];
  for (let y = y0; y <= y1; y++) {
    const row: (Vec | null)[] = [];
    for (let x = x0; x <= x1; x++) {
      row.push(has.has(key(x, y)) ? [x, y] : null);
    }
    tiles.push(row);
  }
  return { source, tiles };
}

// The cells with some replaced or added, keeping the others in their order.
function put(cells: Cell[], placed: Cell[]): Cell[] {
  const byKey = new Map(placed.map((cell) => [key(cell.x, cell.y), cell]));
  const kept = cells.map((cell) => byKey.get(key(cell.x, cell.y)) ?? cell);
  const known = new Set(cells.map((cell) => key(cell.x, cell.y)));
  return [...kept, ...placed.filter((cell) => !known.has(key(cell.x, cell.y)))];
}

function stampCells(stamp: Stamp, at: Vec, area: Area, bounds: Bounds): Cell[] {
  const placed: Cell[] = [];
  for (let y = area.y; y < area.y + area.h; y++) {
    for (let x = area.x; x < area.x + area.w; x++) {
      const row = stamp.tiles[(((y - at[1]) % stamp.tiles.length) + stamp.tiles.length) % stamp.tiles.length];
      const tile = row[(((x - at[0]) % row.length) + row.length) % row.length];
      if (tile && inside(x, y, bounds)) {
        placed.push({ x, y, source: stamp.source, atlas: [tile[0], tile[1]], alternative: 0 });
      }
    }
  }
  return placed;
}

export function stampAt(cells: Cell[], at: Vec, stamp: Stamp, bounds: Bounds): Cell[] {
  const area = { x: at[0], y: at[1], w: stamp.tiles[0].length, h: stamp.tiles.length };
  return put(cells, stampCells(stamp, at, area, bounds));
}

export function fillRect(cells: Cell[], area: Area, stamp: Stamp, bounds: Bounds): Cell[] {
  return put(cells, stampCells(stamp, [area.x, area.y], area, bounds));
}

export function eraseRect(cells: Cell[], area: Area): Cell[] {
  return cells.filter((c) => !(c.x >= area.x && c.y >= area.y && c.x < area.x + area.w && c.y < area.y + area.h));
}

// The stamp an area of the layer holds, if its tiles are all from one sheet; null for none or mixed.
export function pickStamp(cells: Cell[], area: Area): Stamp | null {
  const byKey = new Map(cells.map((cell) => [key(cell.x, cell.y), cell]));
  let source: number | null = null;
  const tiles: (Vec | null)[][] = [];
  for (let y = area.y; y < area.y + area.h; y++) {
    const row: (Vec | null)[] = [];
    for (let x = area.x; x < area.x + area.w; x++) {
      const cell = byKey.get(key(x, y));
      if (cell && source !== null && cell.source !== source) {
        return null;
      }
      source = cell ? cell.source : source;
      row.push(cell ? [cell.atlas[0], cell.atlas[1]] : null);
    }
    tiles.push(row);
  }
  return source === null ? null : { source, tiles };
}
