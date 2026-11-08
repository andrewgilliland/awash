// The World map's maths, worked out without the page: where each Room sits, how the view pans and
// zooms, and which symbols a Room shows.

import type { MapRoom, Mark, MarkKind } from "../server/codex";

// One screen of a Room, in map units: the game's 160 by 144 pixels, an eighth the size.
export const SCREEN = { w: 20, h: 18 };
export const MIN_SCALE = 0.5;
export const MAX_SCALE = 12;
// The zoom from which a Room's id fits inside it.
const LABEL_SCALE = 2.5;

// The legend's kinds, in the order a Room shows them.
export const MARK_ORDER: MarkKind[] = ["cache", "rest", "shop", "character", "boss", "enemy"];

export type Box = { x: number; y: number; w: number; h: number };
// Where the map's origin lands on the page, and how many pixels a map unit takes.
export type View = { scale: number; x: number; y: number };

export function roomBox(room: Pick<MapRoom, "cell" | "size">): Box {
  return { x: room.cell[0] * SCREEN.w, y: room.cell[1] * SCREEN.h, w: room.size[0] * SCREEN.w, h: room.size[1] * SCREEN.h };
}

export function bounds(boxes: Box[]): Box {
  const left = Math.min(...boxes.map((box) => box.x));
  const top = Math.min(...boxes.map((box) => box.y));
  const right = Math.max(...boxes.map((box) => box.x + box.w));
  const bottom = Math.max(...boxes.map((box) => box.y + box.h));
  return { x: left, y: top, w: right - left, h: bottom - top };
}

// An exit as a short line across the middle of its screen's edge.
export function exitLine(
  room: Pick<MapRoom, "cell" | "size">,
  exit: MapRoom["exits"][number],
): { x1: number; y1: number; x2: number; y2: number } {
  const box = roomBox(room);
  const left = box.x + exit.screen[0] * SCREEN.w;
  const top = box.y + exit.screen[1] * SCREEN.h;
  const across = SCREEN.w * 0.2;
  const down = SCREEN.h * 0.2;
  switch (exit.side) {
    case "east":
    case "west": {
      const x = exit.side === "east" ? left + SCREEN.w : left;
      const y = top + SCREEN.h / 2;
      return { x1: x, y1: y - down, x2: x, y2: y + down };
    }
    case "north":
    case "south": {
      const y = exit.side === "south" ? top + SCREEN.h : top;
      const x = left + SCREEN.w / 2;
      return { x1: x - across, y1: y, x2: x + across, y2: y };
    }
  }
}

function clampScale(scale: number): number {
  return Math.min(MAX_SCALE, Math.max(MIN_SCALE, scale));
}

// The view that shows a box whole in a width and height, centred, with a margin all round.
export function fit(box: Box, width: number, height: number, margin = 24): View {
  const scale = clampScale(Math.min((width - 2 * margin) / box.w, (height - 2 * margin) / box.h));
  return { scale, x: (width - box.w * scale) / 2 - box.x * scale, y: (height - box.h * scale) / 2 - box.y * scale };
}

// Zooms by a factor toward a point on the page, keeping the map under that point where it is.
export function zoomAt(view: View, factor: number, px: number, py: number): View {
  const scale = clampScale(view.scale * factor);
  if (scale === view.scale) {
    return view;
  }
  return { scale, x: px - ((px - view.x) / view.scale) * scale, y: py - ((py - view.y) / view.scale) * scale };
}

export function pan(view: View, dx: number, dy: number): View {
  return { scale: view.scale, x: view.x + dx, y: view.y + dy };
}

export function labelsShown(scale: number): boolean {
  return scale >= LABEL_SCALE;
}

// One symbol per kind a Room holds and the legend shows, in the legend's order.
export function symbols(marks: Mark[], shown: Set<MarkKind>): { kind: MarkKind; marks: Mark[] }[] {
  return MARK_ORDER.filter((kind) => shown.has(kind))
    .map((kind) => ({ kind, marks: marks.filter((mark) => mark.kind === kind) }))
    .filter((symbol) => symbol.marks.length > 0);
}
