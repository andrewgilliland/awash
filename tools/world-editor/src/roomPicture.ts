// A Room's tiles as a picture: its Background behind, as the camera frames each of its screens, and
// its layers drawn from the real sheets in the order the game draws them. The Room view paints over
// it; the World view can show it in the Room's cells.

import { parseRoomScene, type Cell, type RoomScene, type TileLayer, type TileSet, type Vec } from "./godot";
import { backgroundOf, layerOrigin, parseBackground, type Background, type BackgroundLayer } from "./background";
import { canvas, image, readRepo, rect, tileSet } from "./dom";
import { fillKey, tilesKey } from "./layers";
import { SCREEN, type WorldData } from "./world";

const SKY = "#0cf1ff";
// Godot's flips on an alternative tile.
const FLIP_H = 4096;
const FLIP_V = 8192;
// How much of a peeled layer still shows, to line things up by.
export const FADED = 0.25;

// The tile sets a scene's layers name, and the sheets its tiles come from.
export interface RoomArt {
  sets: Map<string, TileSet>;
  sheets: Map<string, HTMLImageElement>;
}

export async function loadArt(layers: TileLayer[]): Promise<RoomArt> {
  const sets = new Map<string, TileSet>();
  for (const layer of layers) {
    if (!sets.has(layer.tileSet)) {
      sets.set(layer.tileSet, await tileSet(layer.tileSet));
    }
  }
  const used = new Set(layers.flatMap((layer) => layer.cells.map((cell) => sets.get(layer.tileSet)!.sources.get(cell.source)?.texture ?? "")));
  used.delete("");
  const sheets = new Map<string, HTMLImageElement>();
  await Promise.all([...used].map(async (texture) => sheets.set(texture, await image(texture))));
  return { sets, sheets };
}

export const loadRoomArt = (scene: RoomScene) => loadArt(scene.layers);

// A Room's Background, read from its scene, with the art to draw it and where the Room sits in the
// World, which sets where each layer lands.
export interface Backdrop {
  path: string;
  text: string;
  version: string;
  background: Background;
  art: RoomArt;
  roomOrigin: Vec;
}

const backdrops = new Map<string, Promise<Omit<Backdrop, "roomOrigin"> | null>>();

export async function loadBackdrop(world: WorldData, id: string): Promise<Backdrop | null> {
  const path = backgroundOf(world, id);
  if (!path) {
    return null;
  }
  if (!backdrops.has(path)) {
    backdrops.set(
      path,
      (async () => {
        const file = await readRepo(path);
        const background = parseBackground(file.text);
        const art = await loadArt(background.layers.flatMap((layer) => layer.tiles));
        return { path, text: file.text, version: file.version, background, art };
      })().catch(() => null),
    );
  }
  const loaded = await backdrops.get(path)!;
  const cell = world.rooms[id].cell;
  return loaded && { ...loaded, roomOrigin: [cell[0] * SCREEN.w, cell[1] * SCREEN.h] };
}


export interface Showing {
  hidden?: Set<string>;
  faded?: Set<string>;
}

// Tiles a tile set tints, each drawn tinted once and kept.
const tinted = new Map<string, HTMLCanvasElement>();

function tintedTile(sheet: HTMLImageElement, texture: string, atlas: Vec, size: Vec, tint: number[]): HTMLCanvasElement {
  const key = `${texture}:${atlas}:${tint}`;
  if (!tinted.has(key)) {
    const [c, tg] = canvas(size[0], size[1], 1);
    tg.drawImage(sheet, atlas[0] * size[0], atlas[1] * size[1], size[0], size[1], 0, 0, size[0], size[1]);
    tg.globalCompositeOperation = "multiply";
    rect(tg, { x: 0, y: 0, w: size[0], h: size[1] }, css([tint[0], tint[1], tint[2], 1]));
    tg.globalCompositeOperation = "destination-in";
    tg.drawImage(sheet, atlas[0] * size[0], atlas[1] * size[1], size[0], size[1], 0, 0, size[0], size[1]);
    tinted.set(key, c);
  }
  return tinted.get(key)!;
}

function drawCell(g: CanvasRenderingContext2D, set: TileSet, sheets: Map<string, HTMLImageElement>, cell: Cell, x: number, y: number) {
  const source = set.sources.get(cell.source);
  const sheet = sheets.get(source?.texture ?? "");
  if (!source || !sheet) {
    return;
  }
  const [tw, th] = set.tileSize;
  const tint = source.tiles.get(`${cell.atlas[0]},${cell.atlas[1]}`)?.tint;
  g.save();
  g.translate(x + tw / 2, y + th / 2);
  g.scale(cell.alternative & FLIP_H ? -1 : 1, cell.alternative & FLIP_V ? -1 : 1);
  if (tint) {
    g.globalAlpha *= tint[3];
    g.drawImage(tintedTile(sheet, source.texture, cell.atlas, set.tileSize, tint), -tw / 2, -th / 2);
  } else {
    g.drawImage(sheet, cell.atlas[0] * tw, cell.atlas[1] * th, tw, th, -tw / 2, -th / 2, tw, th);
  }
  g.restore();
}

function drawLayerCells(g: CanvasRenderingContext2D, layer: TileLayer, art: RoomArt, at: Vec = [0, 0]) {
  const set = art.sets.get(layer.tileSet);
  if (!set) {
    return;
  }
  const [tw, th] = set.tileSize;
  for (const cell of layer.cells) {
    drawCell(g, set, art.sheets, cell, at[0] + cell.x * tw + layer.position[0], at[1] + cell.y * th + layer.position[1]);
  }
}

// How far a layer's drawing reaches across, from its own origin.
function extent(layer: BackgroundLayer): [number, number] {
  const xs = [
    ...layer.tiles.flatMap((tiles) => tiles.cells.flatMap((cell) => [tiles.position[0] + cell.x * 16, tiles.position[0] + cell.x * 16 + 16])),
    ...layer.fills.flatMap((fill) => [fill.rect.x, fill.rect.x + fill.rect.w]),
  ];
  return xs.length ? [Math.min(...xs), Math.max(...xs)] : [0, 0];
}

const css = ([r, g, b, a]: number[]) => `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${a})`;

// One layer of the Background as it shows on one screen, tinted by the layer's colour.
function drawBackdropLayer(g: CanvasRenderingContext2D, layer: BackgroundLayer, backdrop: Backdrop, screen: Vec, showing: Showing) {
  const [off, og] = canvas(SCREEN.w, SCREEN.h, 1);
  const origin = layerOrigin(layer, backdrop.roomOrigin, screen);
  const [left, right] = extent(layer);
  const repeat = layer.repeat[0];
  const first = repeat > 0 ? Math.floor((screen[0] - origin[0] - right) / repeat) : 0;
  const last = repeat > 0 ? Math.ceil((screen[0] + SCREEN.w - origin[0] - left) / repeat) : 0;
  const hidden = showing.hidden ?? new Set();
  const faded = showing.faded ?? new Set();
  for (let copy = first; copy <= last; copy++) {
    const at: Vec = [origin[0] + copy * repeat - screen[0], origin[1] - screen[1]];
    if (!hidden.has(fillKey(layer.name))) {
      og.globalAlpha = faded.has(fillKey(layer.name)) ? FADED : 1;
      for (const fill of layer.fills) {
        rect(og, { x: at[0] + fill.rect.x, y: at[1] + fill.rect.y, w: fill.rect.w, h: fill.rect.h }, css(fill.colour));
      }
    }
    for (const tiles of layer.tiles) {
      if (hidden.has(tilesKey(tiles.name))) {
        continue;
      }
      og.globalAlpha = tiles.opacity * (faded.has(tilesKey(tiles.name)) ? FADED : 1);
      drawLayerCells(og, tiles, backdrop.art, at);
    }
  }
  const [r, gr, b, a] = layer.modulate;
  if (r !== 1 || gr !== 1 || b !== 1) {
    // Multiply by the tint, then keep only what was drawn.
    const [tinted, tg] = canvas(SCREEN.w, SCREEN.h, 1);
    tg.drawImage(off, 0, 0);
    tg.globalCompositeOperation = "multiply";
    rect(tg, { x: 0, y: 0, w: SCREEN.w, h: SCREEN.h }, css([r, gr, b, 1]));
    tg.globalCompositeOperation = "destination-in";
    tg.drawImage(off, 0, 0);
    g.globalAlpha = a;
    g.drawImage(tinted, screen[0], screen[1], SCREEN.w, SCREEN.h);
  } else {
    g.globalAlpha = a;
    g.drawImage(off, screen[0], screen[1], SCREEN.w, SCREEN.h);
  }
  g.globalAlpha = 1;
}

// The Background, screen by screen, each as the camera framing it shows it.
export function drawBackdrop(g: CanvasRenderingContext2D, backdrop: Backdrop, size: { w: number; h: number }, showing: Showing = {}) {
  for (let y = 0; y < size.h; y += SCREEN.h) {
    for (let x = 0; x < size.w; x += SCREEN.w) {
      rect(g, { x, y, w: SCREEN.w, h: SCREEN.h }, "#000");
      for (const layer of backdrop.background.layers) {
        drawBackdropLayer(g, layer, backdrop, [x, y], showing);
      }
    }
  }
}

// Draws the Background, or a flat sky without one, and every layer not hidden, at the Room's own
// pixels; peeled layers faintly.
export function drawTiles(
  g: CanvasRenderingContext2D,
  scene: RoomScene,
  art: RoomArt,
  size: { w: number; h: number },
  showing: Showing = {},
  backdrop: Backdrop | null = null,
) {
  if (backdrop) {
    drawBackdrop(g, backdrop, size, showing);
  } else {
    rect(g, { x: 0, y: 0, ...size }, SKY);
  }
  for (const layer of scene.layers) {
    if (showing.hidden?.has(layer.name)) {
      continue;
    }
    g.globalAlpha = layer.opacity * (showing.faded?.has(layer.name) ? FADED : 1);
    drawLayerCells(g, layer, art);
    g.globalAlpha = 1;
  }
}

const pictures = new Map<string, Promise<HTMLCanvasElement>>();

// A built Room's picture, drawn once and kept until the Room or its Background is painted and saved.
export function roomPicture(world: WorldData, id: string): Promise<HTMLCanvasElement> {
  if (!pictures.has(id)) {
    const record = world.rooms[id];
    pictures.set(
      id,
      (async () => {
        const scene = parseRoomScene((await readRepo(record.scene!)).text);
        const size = { w: record.size[0] * SCREEN.w, h: record.size[1] * SCREEN.h };
        const [c, g] = canvas(size.w, size.h, 1);
        drawTiles(g, scene, await loadRoomArt(scene), size, {}, await loadBackdrop(world, id));
        return c;
      })(),
    );
  }
  return pictures.get(id)!;
}

// Drops a Room's picture, so the next one shows what it is now.
export function forgetPicture(id: string) {
  pictures.delete(id);
}

// Drops a Background and every picture, so the next ones show what it is now.
export function forgetBackdrop(path: string) {
  backdrops.delete(path);
  pictures.clear();
}
