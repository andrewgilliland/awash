// Reads the parts of Godot's text files the World editor needs: a Room scene's tile layers, and a
// tile set's sources. Everything else in those files is left to Godot.

export type Vec = [number, number];

export interface Cell {
  x: number;
  y: number;
  source: number;
  atlas: Vec;
  alternative: number;
}

export interface TileLayer {
  // As Godot names the node: its name, or its parent's path and its name.
  name: string;
  tileSet: string;
  position: Vec;
  opacity: number;
  cells: Cell[];
}

export interface RoomScene {
  layers: TileLayer[];
}

export interface Tile {
  collides: boolean;
  oneWay: boolean;
  // The colour the tile set multiplies it by, when it has one.
  tint?: [number, number, number, number];
}

export interface TileSource {
  texture: string;
  // By "x,y" on the sheet.
  tiles: Map<string, Tile>;
}

export interface TileSet {
  tileSize: Vec;
  sources: Map<number, TileSource>;
}

// One cell of a TileMapLayer's tile_map_data: x, y, source, atlas x, atlas y, alternative.
const CELL_BYTES = 12;
const HEADER_BYTES = 2;

export interface Section {
  kind: string;
  attributes: Record<string, string>;
  properties: Record<string, string>;
}

// A Godot text file's [sections], each with its header's attributes and its property lines.
export function parseSections(text: string): Section[] {
  const found: Section[] = [];
  let current: Section | null = null;
  for (const line of text.split("\n")) {
    const header = /^\[(\w+)(.*)\]$/.exec(line);
    if (header) {
      const attributes: Record<string, string> = {};
      for (const [, key, value] of header[2].matchAll(/(\w+)="([^"]*)"/g)) {
        attributes[key] = value;
      }
      current = { kind: header[1], attributes, properties: {} };
      found.push(current);
      continue;
    }
    const property = /^([\w/:]+) = (.*)$/.exec(line);
    if (property && current) {
      current.properties[property[1]] = property[2];
    }
  }
  return found;
}

// The numbers inside a constructor's brackets: Vector2(0, 8) gives [0, 8].
export function numbers(value: string): number[] {
  const inside = /\(([^)]*)\)/.exec(value)?.[1] ?? value;
  return [...inside.matchAll(/-?\d+(?:\.\d+)?/g)].map((match) => Number(match[0]));
}

export function quoted(value: string): string {
  return /"([^"]*)"/.exec(value)?.[1] ?? "";
}

export function decodeTileMapData(base64: string): Cell[] {
  const bytes = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));
  const view = new DataView(bytes.buffer);
  const cells: Cell[] = [];
  for (let at = HEADER_BYTES; at + CELL_BYTES <= bytes.length; at += CELL_BYTES) {
    cells.push({
      x: view.getInt16(at, true),
      y: view.getInt16(at + 2, true),
      source: view.getUint16(at + 4, true),
      atlas: [view.getUint16(at + 6, true), view.getUint16(at + 8, true)],
      alternative: view.getUint16(at + 10, true),
    });
  }
  return cells;
}

// Each ext_resource's id, to the path it names.
export function resourcePaths(all: Section[]): Map<string, string> {
  const paths = new Map<string, string>();
  for (const section of all) {
    if (section.kind === "ext_resource") {
      paths.set(section.attributes.id, section.attributes.path);
    }
  }
  return paths;
}

// A node's path as Godot names it: its name, or its parent's path and its name.
export function nodePath(section: Section): string {
  const { name, parent } = section.attributes;
  return parent === "." || parent === undefined ? name : `${parent}/${name}`;
}

// Where each node sits in its scene's root: its own position on top of its parents'.
export function nodePositions(all: Section[]): Map<string, Vec> {
  const placed = new Map<string, Vec>();
  for (const section of all) {
    if (section.kind !== "node" || section.attributes.parent === undefined) {
      continue;
    }
    const own = section.properties.position ? numbers(section.properties.position) : [0, 0];
    const parent = placed.get(section.attributes.parent) ?? [0, 0];
    placed.set(nodePath(section), [parent[0] + own[0], parent[1] + own[1]]);
  }
  return placed;
}

// A TileMapLayer node as a layer: its tile set, where it sits, how see-through, and its cells.
export function tileLayerOf(section: Section, paths: Map<string, string>, position: Vec): TileLayer {
  const props = section.properties;
  return {
    name: nodePath(section),
    tileSet: paths.get(quoted(props.tile_set ?? "")) ?? "",
    position,
    opacity: props.modulate ? numbers(props.modulate)[3] : 1,
    cells: props.tile_map_data ? decodeTileMapData(quoted(props.tile_map_data)) : [],
  };
}

export function parseRoomScene(text: string): RoomScene {
  const all = parseSections(text);
  const paths = resourcePaths(all);
  const positions = nodePositions(all);
  const layers = all
    .filter((section) => section.kind === "node" && section.attributes.type === "TileMapLayer")
    .map((section) => tileLayerOf(section, paths, positions.get(nodePath(section)) ?? [0, 0]));
  return { layers };
}

export function parseTileSet(text: string): TileSet {
  const all = parseSections(text);
  const textures = new Map<string, string>();
  const atlases = new Map<string, Section>();
  let resource: Section | undefined;
  for (const section of all) {
    if (section.kind === "ext_resource") {
      textures.set(section.attributes.id, section.attributes.path);
    } else if (section.kind === "sub_resource" && section.attributes.type === "TileSetAtlasSource") {
      atlases.set(section.attributes.id, section);
    } else if (section.kind === "resource") {
      resource = section;
    }
  }
  const sources = new Map<number, TileSource>();
  for (const [key, value] of Object.entries(resource?.properties ?? {})) {
    const id = /^sources\/(\d+)$/.exec(key);
    const atlas = atlases.get(quoted(value));
    if (!id || !atlas) {
      continue;
    }
    const tiles = new Map<string, Tile>();
    for (const [property, setting] of Object.entries(atlas.properties)) {
      const tile = /^(\d+):(\d+)\/0(.*)$/.exec(property);
      if (!tile) {
        continue;
      }
      const coords = `${tile[1]},${tile[2]}`;
      const known = tiles.get(coords) ?? { collides: false, oneWay: false };
      if (tile[3].endsWith("/points")) {
        known.collides = true;
      } else if (tile[3].endsWith("/one_way")) {
        known.oneWay = setting === "true";
      } else if (tile[3] === "/modulate") {
        const [r, g, b, a] = numbers(setting);
        known.tint = [r, g, b, a ?? 1];
      }
      tiles.set(coords, known);
    }
    sources.set(Number(id[1]), { texture: textures.get(quoted(atlas.properties.texture ?? "")) ?? "", tiles });
  }
  const size = resource?.properties.tile_size ? numbers(resource.properties.tile_size) : [16, 16];
  return { tileSize: [size[0], size[1]], sources };
}

export function encodeTileMapData(cells: Cell[]): string {
  const bytes = new Uint8Array(HEADER_BYTES + cells.length * CELL_BYTES);
  const view = new DataView(bytes.buffer);
  cells.forEach((cell, i) => {
    const at = HEADER_BYTES + i * CELL_BYTES;
    view.setInt16(at, cell.x, true);
    view.setInt16(at + 2, cell.y, true);
    view.setUint16(at + 4, cell.source, true);
    view.setUint16(at + 6, cell.atlas[0], true);
    view.setUint16(at + 8, cell.atlas[1], true);
    view.setUint16(at + 10, cell.alternative, true);
  });
  let binary = "";
  bytes.forEach((byte) => (binary += String.fromCharCode(byte)));
  return btoa(binary);
}

// The scene with one tile layer's cells replaced, and every other line as it was. The layer is
// named as parseRoomScene names it.
export function setLayerCells(text: string, layerName: string, cells: Cell[]): string {
  const slash = layerName.lastIndexOf("/");
  const name = slash === -1 ? layerName : layerName.slice(slash + 1);
  const parent = slash === -1 ? "." : layerName.slice(0, slash);
  const lines = text.split("\n");
  const header = lines.findIndex(
    (line) => line.startsWith(`[node name="${name}" type="TileMapLayer"`) && line.includes(`parent="${parent}"`),
  );
  if (header === -1) {
    throw new Error(`The scene has no tile layer ${layerName}`);
  }
  const data = `tile_map_data = PackedByteArray("${encodeTileMapData(cells)}")`;
  for (let i = header + 1; i < lines.length && !lines[i].startsWith("["); i++) {
    if (lines[i].startsWith("tile_map_data = ")) {
      lines[i] = data;
      return lines.join("\n");
    }
  }
  lines.splice(header + 1, 0, data);
  return lines.join("\n");
}
