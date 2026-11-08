import { describe, expect, it } from "vitest";
import { bounds, exitLine, fit, labelsShown, MAX_SCALE, MIN_SCALE, pan, roomBox, SCREEN, symbols, zoomAt } from "../src/mapView";
import type { Mark } from "../server/codex";

describe("where Rooms sit on the World map", () => {
  it("boxes a Room by its cell and size, a screen at a time", () => {
    expect(roomBox({ cell: [2, -1], size: [3, 1] })).toEqual({ x: 2 * SCREEN.w, y: -SCREEN.h, w: 3 * SCREEN.w, h: SCREEN.h });
  });

  it("finds the box around every Room", () => {
    const boxes = [roomBox({ cell: [-1, 0], size: [2, 1] }), roomBox({ cell: [3, 2], size: [1, 2] })];
    expect(bounds(boxes)).toEqual({ x: -SCREEN.w, y: 0, w: 5 * SCREEN.w, h: 4 * SCREEN.h });
  });

  it("draws an exit as a line across the middle of its screen's edge", () => {
    const room = { cell: [0, 0] as [number, number], size: [2, 1] as [number, number] };
    const east = exitLine(room, { screen: [1, 0], side: "east" });
    expect(east.x1).toBe(2 * SCREEN.w);
    expect(east.x2).toBe(2 * SCREEN.w);
    expect((east.y1 + east.y2) / 2).toBe(SCREEN.h / 2);
    const north = exitLine(room, { screen: [1, 0], side: "north" });
    expect(north.y1).toBe(0);
    expect((north.x1 + north.x2) / 2).toBe(1.5 * SCREEN.w);
  });
});

describe("panning and zooming", () => {
  const box = { x: 0, y: 0, w: 200, h: 100 };

  it("fits a box into the view, centred, with a margin", () => {
    const view = fit(box, 640, 400, 20);
    expect(view.scale).toBe(3);
    expect(view.x).toBe(20);
    expect(view.y).toBe(50);
  });

  it("zooms toward a point, keeping what is under it in place", () => {
    const view = { scale: 2, x: 10, y: 20 };
    const zoomed = zoomAt(view, 2, 110, 60);
    expect(zoomed.scale).toBe(4);
    expect((110 - zoomed.x) / zoomed.scale).toBe((110 - view.x) / view.scale);
    expect((60 - zoomed.y) / zoomed.scale).toBe((60 - view.y) / view.scale);
  });

  it("keeps the zoom between its limits, never moving when held at one", () => {
    expect(zoomAt({ scale: MAX_SCALE, x: 0, y: 0 }, 2, 50, 50)).toEqual({ scale: MAX_SCALE, x: 0, y: 0 });
    expect(zoomAt({ scale: 1, x: 0, y: 0 }, 0.001, 0, 0).scale).toBe(MIN_SCALE);
    expect(fit({ x: 0, y: 0, w: 1, h: 1 }, 2000, 2000, 0).scale).toBe(MAX_SCALE);
  });

  it("pans by how far the pointer moved", () => {
    expect(pan({ scale: 2, x: 10, y: 20 }, 5, -3)).toEqual({ scale: 2, x: 15, y: 17 });
  });

  it("names Rooms only once zoomed in far enough to read them", () => {
    expect(labelsShown(1)).toBe(false);
    expect(labelsShown(MAX_SCALE)).toBe(true);
  });
});

describe("what a Room shows", () => {
  const marks: Mark[] = [
    { kind: "enemy", id: "scavenger", label: "Scavenger ×2" },
    { kind: "cache", id: "brinecap", label: "Cache a: Brinecap" },
    { kind: "enemy", id: "wraith", label: "Wraith" },
    { kind: "rest", id: "", label: "Rest point" },
  ];

  it("shows one symbol per kind, in the legend's order, holding each mark of that kind", () => {
    const shown = symbols(marks, new Set(["cache", "rest", "enemy"]));
    expect(shown.map((symbol) => symbol.kind)).toEqual(["cache", "rest", "enemy"]);
    expect(shown[2].marks.map((mark) => mark.id)).toEqual(["scavenger", "wraith"]);
  });

  it("leaves out a kind the legend has hidden", () => {
    expect(symbols(marks, new Set(["cache"])).map((symbol) => symbol.kind)).toEqual(["cache"]);
    expect(symbols([], new Set(["cache"]))).toEqual([]);
  });
});
