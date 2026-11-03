import { describe, expect, it } from "vitest";
import type { Cell } from "../src/godot";
import { blockStamp, eraseRect, fillRect, pickStamp, stampAt } from "../src/paint";

const BOUNDS = { w: 4, h: 3 };
const cell = (x: number, y: number, source: number, ax: number, ay: number): Cell => ({ x, y, source, atlas: [ax, ay], alternative: 0 });
const at = (cells: Cell[], x: number, y: number) => cells.find((c) => c.x === x && c.y === y);
// The sand's top edge and its interior, as a 2-wide block on the ground sheet.
const SAND = blockStamp(0, [2, 1], [3, 2], new Set(["2,1", "3,1", "2,2", "3,2"]));

describe("a stamp", () => {
  it("is a block of tiles picked from a sheet, leaving out tiles the sheet doesn't have", () => {
    expect(SAND).toEqual({ source: 0, tiles: [[[2, 1], [3, 1]], [[2, 2], [3, 2]]] });
    const holed = blockStamp(0, [6, 1], [7, 1], new Set(["7,1"]));
    expect(holed.tiles).toEqual([[null, [7, 1]]]);
  });

  it("paints its tiles with its top-left where it is put, over what was there", () => {
    const before = [cell(0, 0, 9, 9, 9), cell(3, 2, 1, 1, 1)];
    const after = stampAt(before, [0, 0], SAND, BOUNDS);
    expect(at(after, 0, 0)).toEqual(cell(0, 0, 0, 2, 1));
    expect(at(after, 1, 1)).toEqual(cell(1, 1, 0, 3, 2));
    expect(at(after, 3, 2)).toEqual(cell(3, 2, 1, 1, 1));
    expect(after).toHaveLength(5);
    expect(before).toHaveLength(2);
  });

  it("paints nothing outside the Room", () => {
    const after = stampAt([], [3, 2], SAND, BOUNDS);
    expect(after).toEqual([cell(3, 2, 0, 2, 1)]);
  });

  it("is picked back up from the Room with the eyedropper", () => {
    const painted = stampAt([], [1, 0], SAND, BOUNDS);
    expect(pickStamp(painted, { x: 1, y: 0, w: 2, h: 2 })).toEqual(SAND);
    expect(pickStamp(painted, { x: 0, y: 0, w: 1, h: 1 })).toBeNull();
  });
});

describe("an area", () => {
  it("is filled with the stamp repeated from its top-left, inside the Room", () => {
    const filled = fillRect([], { x: 0, y: 0, w: 4, h: 3 }, SAND, BOUNDS);
    expect(filled).toHaveLength(12);
    expect(at(filled, 2, 0)!.atlas).toEqual([2, 1]);
    expect(at(filled, 3, 1)!.atlas).toEqual([3, 2]);
    expect(at(filled, 0, 2)!.atlas).toEqual([2, 1]);
  });

  it("is erased", () => {
    const filled = fillRect([], { x: 0, y: 0, w: 4, h: 3 }, SAND, BOUNDS);
    const erased = eraseRect(filled, { x: 1, y: 1, w: 2, h: 2 });
    expect(erased).toHaveLength(8);
    expect(at(erased, 1, 1)).toBeUndefined();
    expect(at(erased, 0, 0)).toBeDefined();
  });
});

describe("painting bounds that start above or left of zero", () => {
  it("keeps tiles inside a box that may begin at a negative cell", () => {
    const stamp = { source: 0, tiles: [[[1, 1], [2, 1]]] as ([number, number] | null)[][] };
    const cells = stampAt([], [-1, -3], stamp, { x: 0, y: -2, w: 4, h: 4 });
    expect(cells).toEqual([]);
    const placed = stampAt([], [0, -2], stamp, { x: 0, y: -2, w: 4, h: 4 });
    expect(placed.map((cell) => [cell.x, cell.y])).toEqual([[0, -2], [1, -2]]);
  });
});
