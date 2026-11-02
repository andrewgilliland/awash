// What the page's views share: making elements, drawing on a canvas, and reading the repo's files.

import { parseTileSet, type TileSet } from "./godot";

export const MARKERS: Record<string, { colour: string; rows: string[] }> = {
  rest: { colour: "#f2f2f2", rows: ["..#..", ".###.", ".###.", "#####", "..#.."] },
  boss: { colour: "#e8584c", rows: [".....", "#.#.#", "#####", "#####", "....."] },
};

export type Rect = { x: number; y: number; w: number; h: number };

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props: Record<string, unknown> = {},
  ...children: (Node | string)[]
): HTMLElementTagNameMap[K] {
  const node = Object.assign(document.createElement(tag), props);
  node.append(...children);
  return node;
}

export function canvas(w: number, h: number, scale: number): [HTMLCanvasElement, CanvasRenderingContext2D] {
  const c = el("canvas", { width: w * scale, height: h * scale });
  const g = c.getContext("2d")!;
  g.imageSmoothingEnabled = false;
  g.scale(scale, scale);
  return [c, g];
}

export function rect(g: CanvasRenderingContext2D, r: Rect, colour: string) {
  g.fillStyle = colour;
  g.fillRect(r.x, r.y, r.w, r.h);
}

export function outline(g: CanvasRenderingContext2D, r: Rect, colour: string) {
  g.strokeStyle = colour;
  g.lineWidth = 1;
  g.strokeRect(r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1);
}

export function drawMarker(g: CanvasRenderingContext2D, kind: string, x: number, y: number) {
  const marker = MARKERS[kind];
  marker?.rows.forEach((row, dy) =>
    [...row].forEach((pixel, dx) => pixel === "#" && rect(g, { x: x + dx, y: y + dy, w: 1, h: 1 }, marker.colour)),
  );
}

export const repoUrl = (path: string) => `/repo/${path.replace(/^res:\/\//, "")}`;

// A repo file's text, and the version it was loaded at.
export async function readRepo(path: string): Promise<{ text: string; version: string }> {
  const response = await fetch(repoUrl(path), { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Could not read ${path}`);
  }
  return { text: await response.text(), version: response.headers.get("X-Version") ?? "" };
}

const images = new Map<string, Promise<HTMLImageElement>>();
const tileSets = new Map<string, Promise<TileSet>>();

export function image(path: string): Promise<HTMLImageElement> {
  if (!images.has(path)) {
    images.set(
      path,
      new Promise((done, fail) => {
        const img = new Image();
        img.onload = () => done(img);
        img.onerror = () => fail(new Error(`Could not load ${path}`));
        img.src = repoUrl(path);
      }),
    );
  }
  return images.get(path)!;
}

export function tileSet(path: string): Promise<TileSet> {
  if (!tileSets.has(path)) {
    tileSets.set(path, readRepo(path).then((file) => parseTileSet(file.text)));
  }
  return tileSets.get(path)!;
}
