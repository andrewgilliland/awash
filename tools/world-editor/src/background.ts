// A Region's Background: layers behind every Room in the Region, each scrolling slower the farther
// back, as the game sets them. Read from its scene, placed for a Room as the camera frames each of
// its screens, and traced back from a point in the Room to the cell a layer holds there.

import {
  nodePath,
  nodePositions,
  numbers,
  parseSections,
  resourcePaths,
  tileLayerOf,
  type Section,
  type TileLayer,
  type Vec,
} from "./godot";
import { SCREEN, type WorldData } from "./world";

export type Colour = [number, number, number, number];

// A plain colour across a box, as a ColorRect draws one.
export interface Fill {
  rect: { x: number; y: number; w: number; h: number };
  colour: Colour;
}

export interface BackgroundLayer {
  // The Parallax2D's name.
  name: string;
  scrollScale: Vec;
  // How far apart its copies are, across and down; 0 for no repeat.
  repeat: Vec;
  modulate: Colour;
  tiles: TileLayer[];
  fills: Fill[];
}

export interface Background {
  layers: BackgroundLayer[];
}

const WHITE: Colour = [1, 1, 1, 1];

function colour(value: string | undefined): Colour {
  if (!value) {
    return WHITE;
  }
  const [r, g, b, a] = numbers(value);
  return [r, g, b, a ?? 1];
}

const vec = (value: string | undefined): Vec => {
  const [x, y] = value ? numbers(value) : [0, 0];
  return [x, y];
};

// The layer a node belongs to: the top-level Parallax2D its path starts with.
const layerOfPath = (path: string) => path.split("/")[0];

export function parseBackground(text: string): Background {
  const all = parseSections(text);
  const paths = resourcePaths(all);
  const positions = nodePositions(all);
  const nodes = all.filter((section) => section.kind === "node");
  const layers: BackgroundLayer[] = nodes
    .filter((section) => section.attributes.type === "Parallax2D" && section.attributes.parent === ".")
    .map((section) => ({
      name: section.attributes.name,
      scrollScale: vec(section.properties.scroll_scale ?? "Vector2(1, 1)"),
      repeat: vec(section.properties.repeat_size),
      modulate: colour(section.properties.modulate),
      tiles: [],
      fills: [],
    }));
  const byName = new Map(layers.map((layer) => [layer.name, layer]));
  const within = (section: Section) => byName.get(layerOfPath(nodePath(section)));
  // Places inside a layer are from its own origin: the Parallax2D's place is the game's to set.
  const placeIn = (section: Section): Vec => {
    const at = positions.get(nodePath(section)) ?? [0, 0];
    const layerAt = positions.get(layerOfPath(nodePath(section))) ?? [0, 0];
    return [at[0] - layerAt[0], at[1] - layerAt[1]];
  };
  for (const section of nodes) {
    const layer = within(section);
    if (!layer || section.attributes.parent === ".") {
      continue;
    }
    if (section.attributes.type === "TileMapLayer") {
      layer.tiles.push(tileLayerOf(section, paths, placeIn(section)));
    } else if (section.attributes.type === "ColorRect") {
      const parentAt = positions.get(section.attributes.parent) ?? [0, 0];
      const layerAt = positions.get(layer.name) ?? [0, 0];
      const left = Number(section.properties.offset_left ?? 0) + parentAt[0] - layerAt[0];
      const top = Number(section.properties.offset_top ?? 0) + parentAt[1] - layerAt[1];
      const right = Number(section.properties.offset_right ?? 0) + parentAt[0] - layerAt[0];
      const bottom = Number(section.properties.offset_bottom ?? 0) + parentAt[1] - layerAt[1];
      layer.fills.push({
        rect: { x: left, y: top, w: round(right - left), h: round(bottom - top) },
        colour: colour(section.properties.color),
      });
    }
  }
  return { layers };
}

const round = (n: number) => Math.round(n * 1000) / 1000;

// Where a layer's own origin sits in a Room's pixels, with the Room at roomOrigin in the World and
// the camera framing the screen whose corner is at screen in the Room. The game shifts each layer
// against the camera's place in the World by its scroll speed, so it carries on across Exits.
export function layerOrigin(layer: BackgroundLayer, roomOrigin: Vec, screen: Vec): Vec {
  return [0, 1].map((axis) => screen[axis] - (roomOrigin[axis] + screen[axis]) * layer.scrollScale[axis]) as Vec;
}

// The screen of a Room a point is on, by its corner.
export const screenOf = (point: Vec): Vec => [
  Math.floor(point[0] / SCREEN.w) * SCREEN.w,
  Math.floor(point[1] / SCREEN.h) * SCREEN.h,
];

// The cell of one of a layer's tile layers under a point in the Room: undoing the layer's place for
// the screen the point is on, the tile layer's own offset, then the layer's repeat across.
export function layerCell(layer: BackgroundLayer, tiles: TileLayer, roomOrigin: Vec, point: Vec): Vec {
  const origin = layerOrigin(layer, roomOrigin, screenOf(point));
  let x = point[0] - origin[0] - tiles.position[0];
  const y = point[1] - origin[1] - tiles.position[1];
  if (layer.repeat[0] > 0) {
    x = ((x % layer.repeat[0]) + layer.repeat[0]) % layer.repeat[0];
  }
  return [Math.floor(x / 16), Math.floor(y / 16)];
}

// The Background a Room shows: its Region's, or the other one the Room names; "" for none.
export function backgroundOf(world: WorldData, id: string): string {
  const room = world.rooms[id];
  const region = world.regions[room.region];
  if (!region) {
    return "";
  }
  return room.background ? (region.backgrounds?.[room.background] ?? "") : (region.background ?? "");
}

// Every built Room that shows a Background, so painting it says who it changes.
export function roomsSharing(world: WorldData, path: string): string[] {
  return Object.keys(world.rooms).filter((id) => world.rooms[id].scene && backgroundOf(world, id) === path);
}

// The cells a layer's tiles may be painted into: one repeat across, or a screen either side of its
// own without one; and a screen above and below its own, as far as the camera can carry it.
export function layerBounds(layer: BackgroundLayer): { x: number; y: number; w: number; h: number } {
  const across = SCREEN.w / 16;
  const down = SCREEN.h / 16;
  return layer.repeat[0] > 0
    ? { x: 0, y: -down, w: layer.repeat[0] / 16, h: down * 3 }
    : { x: -across, y: -down, w: across * 3, h: down * 3 };
}
