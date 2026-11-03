// A Room's layers as one stack, front to back: the Room's own, then its Background's down to the
// back. Picking a layer to paint peels away every layer in front of it; the layers whose tiles
// collide are marked, and each tile says how it collides.

import type { Background } from "./background";
import type { Cell, RoomScene, TileSet } from "./godot";

export interface StackEntry {
  // The key the view shows, peels and paints a layer by.
  key: string;
  paintable: boolean;
  background: boolean;
  collides: boolean;
}

export const fillKey = (layer: string) => `Background/${layer}`;
export const tilesKey = (tiles: string) => `Background/${tiles}`;

const collides = (set: TileSet | undefined) =>
  [...(set?.sources.values() ?? [])].some((source) => [...source.tiles.values()].some((tile) => tile.collides));

export function layerStack(scene: RoomScene, background: Background | null, sets: Map<string, TileSet>): StackEntry[] {
  const stack: StackEntry[] = [...scene.layers].reverse().map((layer) => ({
    key: layer.name,
    paintable: true,
    background: false,
    collides: collides(sets.get(layer.tileSet)),
  }));
  for (const layer of [...(background?.layers ?? [])].reverse()) {
    for (const tiles of [...layer.tiles].reverse()) {
      stack.push({ key: tilesKey(tiles.name), paintable: true, background: true, collides: false });
    }
    if (layer.fills.length > 0) {
      stack.push({ key: fillKey(layer.name), paintable: false, background: true, collides: false });
    }
  }
  return stack;
}

// Every layer in front of the one picked.
export function peeled(stack: StackEntry[], key: string): Set<string> {
  const at = stack.findIndex((entry) => entry.key === key);
  return new Set(stack.slice(0, Math.max(at, 0)).map((entry) => entry.key));
}

export type Collision = "solid" | "one-way" | "none";

export function collisionOf(set: TileSet, cell: Cell): Collision {
  const tile = set.sources.get(cell.source)?.tiles.get(`${cell.atlas[0]},${cell.atlas[1]}`);
  if (!tile?.collides) {
    return "none";
  }
  return tile.oneWay ? "one-way" : "solid";
}
