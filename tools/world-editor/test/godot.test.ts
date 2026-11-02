import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { decodeTileMapData, parseRoomScene, parseTileSet } from "../src/godot";

const REPO = resolve(__dirname, "../../..");
const read = (path: string) => readFileSync(resolve(REPO, path), "utf8");

describe("a Room scene", () => {
  const room = parseRoomScene(read("scenes/rooms/waking_coast_1.tscn"));

  it("lists its tile layers in the order the game draws them", () => {
    expect(room.layers.map((layer) => layer.name)).toEqual(["FarTrees", "Terrain", "Props", "Surf"]);
  });

  it("names each layer's tile set by its path", () => {
    const terrain = room.layers.find((layer) => layer.name === "Terrain")!;
    expect(terrain.tileSet).toBe("res://assets/regions/waking_coast/tiles/terrain.tres");
    expect(room.layers.find((layer) => layer.name === "Props")!.tileSet).toBe(
      "res://assets/regions/waking_coast/tiles/scenery.tres",
    );
  });

  it("keeps a layer's offset and see-through", () => {
    const surf = room.layers.find((layer) => layer.name === "Surf")!;
    expect(surf.position).toEqual([0, 8]);
    expect(surf.opacity).toBeCloseTo(0.75);
    expect(room.layers.find((layer) => layer.name === "Terrain")!.opacity).toBe(1);
  });

  it("decodes each layer's cells: the low shelf at the west wall, and a slope", () => {
    const terrain = room.layers.find((layer) => layer.name === "Terrain")!;
    const at = (x: number, y: number) => terrain.cells.find((cell) => cell.x === x && cell.y === y);
    expect(at(0, 8)).toMatchObject({ source: 0, atlas: [2, 1], alternative: 0 });
    expect(at(7, 6)).toMatchObject({ source: 0, atlas: [8, 1] });
    expect(at(0, 6)).toBeUndefined();
  });
});

describe("tile map data", () => {
  it("decodes nothing from an empty layer", () => {
    expect(decodeTileMapData("AAA=")).toEqual([]);
  });
});

describe("a tile set", () => {
  const terrain = parseTileSet(read("assets/regions/waking_coast/tiles/terrain.tres"));

  it("lists each source by its id, with its sheet", () => {
    expect(terrain.tileSize).toEqual([16, 16]);
    expect(terrain.sources.get(0)!.texture).toBe("res://assets/packs/tropical_island/ground.png");
    expect(terrain.sources.get(1)!.texture).toBe("res://assets/packs/tropical_island/water.png");
  });

  it("knows which tiles collide, and which are one-way ledges", () => {
    const ground = terrain.sources.get(0)!;
    expect(ground.tiles.get("8,1")).toEqual({ collides: true, oneWay: false });
    const bridges = terrain.sources.get(2)!;
    expect(bridges.tiles.get("4,4")).toEqual({ collides: true, oneWay: true });
  });

  it("lists scenery tiles, which never collide", () => {
    const scenery = parseTileSet(read("assets/regions/waking_coast/tiles/scenery.tres"));
    const water = scenery.sources.get(7)!;
    expect(water.texture).toBe("res://assets/packs/tropical_island/water.png");
    expect(water.tiles.get("1,1")).toEqual({ collides: false, oneWay: false });
  });
});
