import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { CELL, layoutWorld, type WorldData } from "../src/world";

const REPO = resolve(__dirname, "../../..");
const world: WorldData = JSON.parse(readFileSync(resolve(REPO, "assets/world.json"), "utf8"));

// Made-up: a one-screen cove, then two-screen cliffs with a Boss and a Drop, and a planned reef.
const MADE_UP: WorldData = {
  regions: { coast: { name: "Coast", colour: "#183931" }, reef: { name: "Reef", colour: "#31254a" } },
  rooms: {
    cove: { scene: "res://cove.tscn", cell: [0, 0], size: [1, 1], region: "coast", exits: [{ screen: [0, 0], side: "east" }] },
    cliffs: {
      scene: "res://cliffs.tscn",
      cell: [1, 0],
      size: [2, 1],
      region: "coast",
      exits: [
        { screen: [0, 0], side: "west" },
        { screen: [1, 0], side: "south" },
      ],
      markers: { boss: [1, 0] },
    },
    reef: { cell: [3, 0], size: [1, 1], region: "reef", exits: [] },
  },
};

const walled = (walls: { x: number; y: number; w: number; h: number }[], x: number, y: number) =>
  walls.some((wall) => x >= wall.x && x < wall.x + wall.w && y >= wall.y && y < wall.y + wall.h);

describe("the World as it is", () => {
  const today = layoutWorld(world, false);

  it("shows only built Rooms, each where it sits today", () => {
    const ids = today.rooms.map((room) => room.id);
    expect(ids).toContain("waking_coast_1");
    expect(ids).not.toContain("undertow_1");
    const one = today.rooms.find((room) => room.id === "waking_coast_1")!.block;
    const two = today.rooms.find((room) => room.id === "waking_coast_2")!.block;
    expect(two.x - one.x).toBe(2 * CELL.w);
    expect(two.y).toBe(one.y);
  });
});

describe("the World as planned", () => {
  const planned = layoutWorld(world, true);

  it("shows every Room, the Planned ones in outline, the built ones where they are to go", () => {
    const undertow = planned.rooms.find((room) => room.id === "undertow_1")!;
    expect(undertow.built).toBe(false);
    const beach = planned.rooms.find((room) => room.id === "waking_coast_1")!;
    const graveyard = planned.rooms.find((room) => room.id === "waking_coast_4")!;
    expect(beach.built).toBe(true);
    // the graveyard up on the cliff tops: (9, -2) against the beach's (-1, 0)
    expect(graveyard.block.x - beach.block.x).toBe(10 * CELL.w);
    expect(graveyard.block.y - beach.block.y).toBe(-2 * CELL.h);
  });

  it("names each Region above its top-left Room", () => {
    expect(planned.labels.map((label) => label.text).sort()).toEqual(["Undertow", "Waking Coast"]);
  });
});

describe("a Room on the Map", () => {
  const layout = layoutWorld(MADE_UP, true);
  const cove = layout.rooms.find((room) => room.id === "cove")!;
  const cliffs = layout.rooms.find((room) => room.id === "cliffs")!;

  it("is filled with its Region's colour", () => {
    expect(cove.colour).toBe("#183931");
    expect(layout.rooms.find((room) => room.id === "reef")!.colour).toBe("#31254a");
  });

  it("is walled round, with a gap at each Exit", () => {
    const b = cove.block;
    const middle = { x: b.x + b.w / 2, y: b.y + b.h / 2 };
    expect(walled(cove.walls, b.x + b.w - 0.5, middle.y)).toBe(false);
    expect(walled(cove.walls, b.x + b.w - 0.5, b.y + 1.5)).toBe(true);
    expect(walled(cove.walls, b.x + 0.5, middle.y)).toBe(true);
    const c = cliffs.block;
    expect(walled(cliffs.walls, c.x + 0.5, middle.y)).toBe(false);
    expect(walled(cliffs.walls, c.x + 30, c.y + c.h - 0.5)).toBe(false);
    expect(walled(cliffs.walls, c.x + 20.5, middle.y)).toBe(false);
  });

  it("has faint lines between its screens", () => {
    expect(cove.lines).toEqual([]);
    expect(cliffs.lines).toHaveLength(1);
    expect(cliffs.lines[0].x).toBe(cliffs.block.x + CELL.w);
  });

  it("marks a Boss on its screen", () => {
    expect(cliffs.markers).toHaveLength(1);
    const marker = cliffs.markers[0];
    expect(marker.kind).toBe("boss");
    expect(marker.x).toBeGreaterThanOrEqual(cliffs.block.x + CELL.w);
  });

  it("tells which screen of the World a point in the picture is on, with room to add around it", () => {
    const padded = layoutWorld(MADE_UP, true, 2);
    expect(padded.screenAt(padded.rooms.find((room) => room.id === "cove")!.block.x + 1, padded.rooms[0].block.y + 1)).toEqual([0, 0]);
    expect(padded.screenAt(5, 13)).toEqual([-2, -2]);
    expect(padded.size.w).toBe(layout.size.w + 4 * CELL.w);
    expect(padded.blockAt([1, 0], [2, 1])).toEqual(padded.rooms.find((room) => room.id === "cliffs")!.block);
  });

  it("fits inside the picture", () => {
    for (const room of layout.rooms) {
      expect(room.block.x).toBeGreaterThanOrEqual(0);
      expect(room.block.x + room.block.w).toBeLessThanOrEqual(layout.size.w);
    }
  });
});
