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

interface Section {
  kind: string;
  attributes: Record<string, string>;
  properties: Record<string, string>;
}

function sections(text: string): Section[] {
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
function numbers(value: string): number[] {
  const inside = /\(([^)]*)\)/.exec(value)?.[1] ?? value;
  return [...inside.matchAll(/-?\d+(?:\.\d+)?/g)].map((match) => Number(match[0]));
}

function quoted(value: string): string {
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

export function parseRoomScene(text: string): RoomScene {
  const all = sections(text);
  const paths = new Map<string, string>();
  for (const section of all) {
    if (section.kind === "ext_resource") {
      paths.set(section.attributes.id, section.attributes.path);
    }
  }
  const layers: TileLayer[] = [];
  for (const section of all) {
    if (section.kind !== "node" || section.attributes.type !== "TileMapLayer") {
      continue;
    }
    const { name, parent } = section.attributes;
    const props = section.properties;
    const position = props.position ? numbers(props.position) : [0, 0];
    layers.push({
      name: parent === "." ? name : `${parent}/${name}`,
      tileSet: paths.get(quoted(props.tile_set ?? "")) ?? "",
      position: [position[0], position[1]],
      opacity: props.modulate ? numbers(props.modulate)[3] : 1,
      cells: props.tile_map_data ? decodeTileMapData(quoted(props.tile_map_data)) : [],
    });
  }
  return { layers };
}

export function parseTileSet(text: string): TileSet {
  const all = sections(text);
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
