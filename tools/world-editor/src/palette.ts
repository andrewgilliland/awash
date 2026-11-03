// The palette: the sheets a layer may be painted from, one shown at a time, and a block of its tiles
// picked by dragging over them. Tiles the layer can't take are dimmed; with Collisions on, solid
// tiles are filled and one-way tiles barred, as they are on the Room.

import { canvas, el, outline, rect } from "./dom";
import type { TileSet, Vec } from "./godot";
import { collisionOf, type Collision } from "./layers";
import { areaBetween, blockStamp, type Area, type Stamp } from "./paint";

const PALETTE_SCALE = 2;
const PICKED = "#ffff8b";
const SOLID = "rgba(255, 70, 70, 0.45)";
const ONE_WAY = "rgba(255, 190, 40, 0.95)";

export function markCollision(g: CanvasRenderingContext2D, collision: Collision, x: number, y: number) {
  if (collision === "solid") {
    rect(g, { x, y, w: 16, h: 16 }, SOLID);
  } else if (collision === "one-way") {
    rect(g, { x, y, w: 16, h: 3 }, ONE_WAY);
  }
}

export interface Palette {
  // The picked layer's tile set, the sheets in it it may be painted from, and the one shown.
  set: TileSet;
  sources: { src: number; texture: string }[];
  source: number;
  paintable: (src: number) => Set<string>;
  sheet: (texture: string) => Promise<HTMLImageElement>;
  stamp: Stamp | null;
  collisions: boolean;
  // What to say when the layer has nothing to paint with.
  empty: string;
  chooseSource: (src: number) => void;
  pick: (stamp: Stamp) => void;
}

export async function showPalette(p: Palette): Promise<Node[]> {
  const chooser = el(
    "select",
    { onchange: (e: Event) => p.chooseSource(Number((e.target as HTMLSelectElement).value)) },
    ...p.sources.map((s) => el("option", { value: String(s.src), selected: s.src === p.source }, s.texture.split("/").slice(-2).join("/"))),
  );
  if (p.source < 0) {
    return [el("p", { className: "muted" }, p.empty)];
  }
  const sheet = await p.sheet(p.set.sources.get(p.source)!.texture);
  const has = p.paintable(p.source);
  const [pc, pg] = canvas(sheet.width, sheet.height, PALETTE_SCALE);
  pc.className = "palette";
  const draw = (dragged?: Area) => {
    rect(pg, { x: 0, y: 0, w: sheet.width, h: sheet.height }, "#2a2d40");
    pg.drawImage(sheet, 0, 0);
    for (let y = 0; y < sheet.height / 16; y++) {
      for (let x = 0; x < sheet.width / 16; x++) {
        if (!has.has(`${x},${y}`)) {
          rect(pg, { x: x * 16, y: y * 16, w: 16, h: 16 }, "rgba(14, 14, 22, 0.75)");
        }
      }
    }
    if (p.collisions) {
      for (const coords of has) {
        const [x, y] = coords.split(",").map(Number);
        markCollision(pg, collisionOf(p.set, { x, y, source: p.source, atlas: [x, y], alternative: 0 }), x * 16, y * 16);
      }
    }
    const shown = dragged ?? (p.stamp && p.stamp.source === p.source ? pickedArea(p.stamp) : null);
    if (shown) {
      outline(pg, { x: shown.x * 16, y: shown.y * 16, w: shown.w * 16, h: shown.h * 16 }, PICKED);
    }
  };
  let start: Vec | null = null;
  const tileAt = (event: PointerEvent): Vec => {
    const box = pc.getBoundingClientRect();
    return [Math.floor((event.clientX - box.left) / PALETTE_SCALE / 16), Math.floor((event.clientY - box.top) / PALETTE_SCALE / 16)];
  };
  pc.addEventListener("pointerdown", (event) => {
    start = tileAt(event);
    pc.setPointerCapture(event.pointerId);
    draw(areaBetween(start, start));
  });
  pc.addEventListener("pointermove", (event) => start && draw(areaBetween(start, tileAt(event))));
  pc.addEventListener("pointerup", (event) => {
    if (!start) {
      return;
    }
    const picked = blockStamp(p.source, start, tileAt(event), has);
    start = null;
    if (picked.tiles.flat().some((tile) => tile)) {
      p.pick(picked);
    } else {
      draw();
    }
  });
  draw();
  return [el("label", { className: "field" }, "Sheet", chooser), el("div", { className: "palette-box" }, pc)];
}

// Where on its sheet a stamp was picked from.
function pickedArea(stamp: Stamp): Area | null {
  for (let y = 0; y < stamp.tiles.length; y++) {
    for (let x = 0; x < stamp.tiles[y].length; x++) {
      const tile = stamp.tiles[y][x];
      if (tile) {
        return { x: tile[0] - x, y: tile[1] - y, w: stamp.tiles[0].length, h: stamp.tiles.length };
      }
    }
  }
  return null;
}
