import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { parseBackground } from "../src/background";
import { parseRoomScene, parseTileSet, type TileSet } from "../src/godot";
import { collisionOf, layerStack, peeled } from "../src/layers";

const REPO = resolve(__dirname, "../../..");
const read = (path: string) => readFileSync(resolve(REPO, path), "utf8");
const sets = new Map<string, TileSet>(
  ["waking_coast/tiles/terrain.tres", "waking_coast/tiles/scenery.tres"].map((path) => [
    `res://assets/regions/${path}`,
    parseTileSet(read(`assets/regions/${path}`)),
  ]),
);

describe("a Room's layers, front to back", () => {
  const beach = parseRoomScene(read("scenes/rooms/waking_coast_1.tscn"));
  const sky = parseBackground(read("scenes/regions/waking_coast/background.tscn"));
  const stack = layerStack(beach, sky, sets);

  it("run from the Room's front layer back through its Background to the sky", () => {
    expect(stack.map((entry) => entry.key)).toEqual([
      "Surf",
      "Props",
      "Terrain",
      "FarTrees",
      "Background/Sea/Tiles",
      "Background/Ships/Tiles",
      "Background/NearClouds/Tiles",
      "Background/FarClouds/Tiles",
      "Background/Sun/Beams",
      "Background/Sun/Tiles",
      "Background/Haze/Tiles",
      "Background/Sky/Tiles",
    ]);
    expect(stack.filter((entry) => entry.background).length).toBe(8);
  });

  it("can paint every tile layer, but not a plain colour fill", () => {
    expect(stack.every((entry) => entry.paintable)).toBe(true);
    const cave = parseBackground(read("scenes/regions/waking_coast/cave_background.tscn"));
    const fills = layerStack(beach, cave, sets).filter((entry) => !entry.paintable);
    expect(fills.map((entry) => entry.key)).toEqual(["Background/Glints", "Background/Wall"]);
  });

  it("marks only the layers whose tiles collide", () => {
    expect(stack.filter((entry) => entry.collides).map((entry) => entry.key)).toEqual(["Terrain"]);
  });

  it("peels away every layer in front of the one picked", () => {
    const keys = stack.map((entry) => entry.key);
    expect([...peeled(stack, "Terrain")]).toEqual(["Surf", "Props"]);
    expect([...peeled(stack, "Background/Sky/Tiles")]).toEqual(keys.slice(0, -1));
    expect([...peeled(stack, "Surf")]).toEqual([]);
  });
});

describe("a tile's collision", () => {
  const terrain = sets.get("res://assets/regions/waking_coast/tiles/terrain.tres")!;

  it("is solid, one-way, or none", () => {
    expect(collisionOf(terrain, { x: 0, y: 0, source: 0, atlas: [2, 1], alternative: 0 })).toBe("solid");
    expect(collisionOf(terrain, { x: 0, y: 0, source: 2, atlas: [4, 4], alternative: 0 })).toBe("one-way");
    const scenery = sets.get("res://assets/regions/waking_coast/tiles/scenery.tres")!;
    expect(collisionOf(scenery, { x: 0, y: 0, source: 0, atlas: [1, 1], alternative: 0 })).toBe("none");
  });
});
