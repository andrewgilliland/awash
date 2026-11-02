// A Room's tiles, read-only: its layers drawn from the real sheets in the order the game draws them.

import { parseRoomScene, type RoomScene, type TileSet } from "./godot";
import { el, canvas, image, readRepo, rect, tileSet } from "./dom";
import { SCREEN, type WorldData } from "./world";

const ROOM_SCALE = 2;
const SKY = "#0cf1ff";
const EXIT_MARK = "#ffff8b";
// Godot's flips on an alternative tile.
const FLIP_H = 4096;
const FLIP_V = 8192;

// A Room's tile layers drawn from the real sheets in the order the game draws them, on a flat sky,
// with its screens' edges and its Exits marked.
export async function showRoom(
  world: WorldData,
  id: string,
  stage: HTMLElement,
  side: HTMLElement,
  back: () => void,
) {
  const record = world.rooms[id];
  stage.replaceChildren(el("p", { className: "muted" }, `Loading ${id}…`));
  const scene: RoomScene = parseRoomScene((await readRepo(record.scene!)).text);
  const size = { w: record.size[0] * SCREEN.w, h: record.size[1] * SCREEN.h };
  const hidden = new Set<string>();
  // Every tile set and sheet the Room draws from, loaded before the first draw.
  const sets = new Map<string, TileSet>();
  const sheets = new Map<string, HTMLImageElement>();
  for (const layer of scene.layers) {
    sets.set(layer.tileSet, await tileSet(layer.tileSet));
  }
  const textures = new Set(
    scene.layers.flatMap((layer) =>
      layer.cells.map((cell) => sets.get(layer.tileSet)!.sources.get(cell.source)?.texture ?? ""),
    ),
  );
  textures.delete("");
  await Promise.all([...textures].map(async (texture) => sheets.set(texture, await image(texture))));

  const draw = () => {
    const [c, g] = canvas(size.w, size.h, ROOM_SCALE);
    rect(g, { x: 0, y: 0, ...size }, SKY);
    for (const layer of scene.layers) {
      if (hidden.has(layer.name)) {
        continue;
      }
      const set = sets.get(layer.tileSet)!;
      const [tw, th] = set.tileSize;
      g.globalAlpha = layer.opacity;
      for (const cell of layer.cells) {
        const sheet = sheets.get(set.sources.get(cell.source)?.texture ?? "");
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
    for (let x = 1; x < record.size[0]; x++) {
      rect(g, { x: x * SCREEN.w, y: 0, w: 1, h: size.h }, "rgba(0, 0, 0, 0.35)");
    }
    for (let y = 1; y < record.size[1]; y++) {
      rect(g, { x: 0, y: y * SCREEN.h, w: size.w, h: 1 }, "rgba(0, 0, 0, 0.35)");
    }
    for (const exit of record.exits ?? []) {
      const sx = exit.screen[0] * SCREEN.w;
      const sy = exit.screen[1] * SCREEN.h;
      const mark = {
        north: { x: sx + SCREEN.w / 2 - 12, y: 0, w: 24, h: 3 },
        south: { x: sx + SCREEN.w / 2 - 12, y: size.h - 3, w: 24, h: 3 },
        west: { x: 0, y: sy + SCREEN.h / 2 - 12, w: 3, h: 24 },
        east: { x: size.w - 3, y: sy + SCREEN.h / 2 - 12, w: 3, h: 24 },
      }[exit.side];
      rect(g, mark, EXIT_MARK);
    }
    stage.replaceChildren(c);
  };

  side.replaceChildren(
    el("h2", {}, id),
    el("p", { className: "muted" }, `${record.size[0]} × ${record.size[1]} screens · ${record.scene}`),
    el("p", {}, "Layers, in the order the game draws them:"),
    ...scene.layers.map((layer) => {
      const box = el("input", { type: "checkbox", checked: true });
      box.addEventListener("change", () => {
        if (box.checked) {
          hidden.delete(layer.name);
        } else {
          hidden.add(layer.name);
        }
        draw();
      });
      return el("label", { className: "layer" }, box, ` ${layer.name} (${layer.cells.length} tiles)`);
    }),
    el("p", { className: "muted" }, "Yellow marks are Exits; dark lines are screen edges."),
    el("button", { type: "button", onclick: back }, "Back to the World"),
  );
  draw();
}
