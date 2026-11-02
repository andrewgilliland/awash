// A Room's tiles as a picture: its layers drawn from the real sheets in the order the game draws
// them, on a flat sky. The Room view paints over it; the World view can show it in the Room's cells.

import { parseRoomScene, type RoomScene, type TileSet } from "./godot";
import { canvas, image, readRepo, rect, tileSet } from "./dom";
import { SCREEN, type WorldData } from "./world";

const SKY = "#0cf1ff";
// Godot's flips on an alternative tile.
const FLIP_H = 4096;
const FLIP_V = 8192;

// The tile sets a Room's layers name, and the sheets its tiles come from.
export interface RoomArt {
  sets: Map<string, TileSet>;
  sheets: Map<string, HTMLImageElement>;
}

export async function loadRoomArt(scene: RoomScene): Promise<RoomArt> {
  const sets = new Map<string, TileSet>();
  for (const layer of scene.layers) {
    sets.set(layer.tileSet, await tileSet(layer.tileSet));
  }
  const used = new Set(
    scene.layers.flatMap((layer) => layer.cells.map((cell) => sets.get(layer.tileSet)!.sources.get(cell.source)?.texture ?? "")),
  );
  used.delete("");
  const sheets = new Map<string, HTMLImageElement>();
  await Promise.all([...used].map(async (texture) => sheets.set(texture, await image(texture))));
  return { sets, sheets };
}

// Draws the sky and every layer not hidden, at the Room's own pixels.
export function drawTiles(
  g: CanvasRenderingContext2D,
  scene: RoomScene,
  art: RoomArt,
  size: { w: number; h: number },
  hidden: Set<string> = new Set(),
) {
  rect(g, { x: 0, y: 0, ...size }, SKY);
  for (const layer of scene.layers) {
    if (hidden.has(layer.name)) {
      continue;
    }
    const set = art.sets.get(layer.tileSet)!;
    const [tw, th] = set.tileSize;
    g.globalAlpha = layer.opacity;
    for (const cell of layer.cells) {
      const sheet = art.sheets.get(set.sources.get(cell.source)?.texture ?? "");
      if (!sheet) {
        continue;
      }
      const x = cell.x * tw + layer.position[0];
      const y = cell.y * th + layer.position[1];
      g.save();
      g.translate(x + tw / 2, y + th / 2);
      g.scale(cell.alternative & FLIP_H ? -1 : 1, cell.alternative & FLIP_V ? -1 : 1);
      g.drawImage(sheet, cell.atlas[0] * tw, cell.atlas[1] * th, tw, th, -tw / 2, -th / 2, tw, th);
      g.restore();
    }
    g.globalAlpha = 1;
  }
}

const pictures = new Map<string, Promise<HTMLCanvasElement>>();

// A built Room's picture, drawn once and kept until the Room is painted and saved again.
export function roomPicture(world: WorldData, id: string): Promise<HTMLCanvasElement> {
  if (!pictures.has(id)) {
    const record = world.rooms[id];
    pictures.set(
      id,
      (async () => {
        const scene = parseRoomScene((await readRepo(record.scene!)).text);
        const size = { w: record.size[0] * SCREEN.w, h: record.size[1] * SCREEN.h };
        const [c, g] = canvas(size.w, size.h, 1);
        drawTiles(g, scene, await loadRoomArt(scene), size);
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
