import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { backgroundOf, layerCell, layerOrigin, parseBackground, roomsSharing } from "../src/background";
import type { WorldData } from "../src/world";

const REPO = resolve(__dirname, "../../..");
const read = (path: string) => readFileSync(resolve(REPO, path), "utf8");

describe("a Region's Background", () => {
  const coast = parseBackground(read("scenes/regions/waking_coast/background.tscn"));

  it("lists its layers back to front, each with how fast it scrolls and how often it repeats", () => {
    expect(coast.layers.map((layer) => layer.name)).toEqual(["Sky", "Haze", "Sun", "FarClouds", "NearClouds", "Ships", "Sea"]);
    const clouds = coast.layers.find((layer) => layer.name === "FarClouds")!;
    expect(clouds.scrollScale).toEqual([0.1, 0.1]);
    expect(clouds.repeat).toEqual([480, 0]);
  });

  it("names each layer's tile layers as Godot does, with their tile set and cells", () => {
    const sun = coast.layers.find((layer) => layer.name === "Sun")!;
    expect(sun.tiles.map((tiles) => tiles.name)).toEqual(["Sun/Tiles", "Sun/Beams"]);
    expect(sun.tiles[0].tileSet).toBe("res://assets/regions/waking_coast/tiles/scenery.tres");
    expect(sun.tiles[0].cells.length).toBeGreaterThan(0);
    const ships = coast.layers.find((layer) => layer.name === "Ships")!;
    expect(ships.tiles[0].position).toEqual([0, 2]);
  });

  it("keeps a layer's plain colour fills, and its tint", () => {
    const cave = parseBackground(read("scenes/regions/waking_coast/cave_background.tscn"));
    const wall = cave.layers.find((layer) => layer.name === "Wall")!;
    expect(wall.fills[0].rect).toEqual({ x: -32, y: -75.2, w: 752, h: 294.4 });
    expect(wall.fills[0].colour).toEqual([0.109804, 0.0941176, 0.141176, 1]);
    expect(cave.layers.find((layer) => layer.name === "Glints")!.fills.length).toBeGreaterThan(10);
    const undertow = parseBackground(read("scenes/regions/undertow/background.tscn"));
    expect(undertow.layers.find((layer) => layer.name === "Ridge")!.modulate).toEqual([0.25, 0.35, 0.55, 1]);
    expect(coast.layers[0].modulate).toEqual([1, 1, 1, 1]);
  });
});

describe("where a Background layer lands", () => {
  const layer = { name: "Clouds", scrollScale: [0.5, 0.25] as [number, number], repeat: [160, 0] as [number, number], modulate: [1, 1, 1, 1] as [number, number, number, number], tiles: [], fills: [] };

  it("is shifted by its scroll speed from where the camera is in the World, framing each screen", () => {
    // A Room at (320, 144) in the World, its second screen framed: the camera is at (480, 144).
    expect(layerOrigin(layer, [320, 144], [160, 0])).toEqual([160 - 240, 0 - 36]);
    // Fixed to the screen, it sits at the screen's corner; moving with the World, at the World's.
    expect(layerOrigin({ ...layer, scrollScale: [0, 0] }, [320, 144], [160, 0])).toEqual([160, 0]);
    expect(layerOrigin({ ...layer, scrollScale: [1, 1] }, [320, 144], [160, 0])).toEqual([-320, -144]);
  });

  it("traces a point in the Room back to the layer's own cell, through its repeat", () => {
    const tiles = { name: "Clouds/Tiles", tileSet: "", position: [0, 0] as [number, number], opacity: 1, cells: [] };
    // Framed from the Room's first screen at the World's origin, the layer sits at the Room's corner.
    expect(layerCell(layer, tiles, [0, 0], [40, 20])).toEqual([2, 1]);
    // A screen along, the layer has moved half a screen less: the point is 80 pixels further in, and
    // past the repeat it comes round again.
    expect(layerCell(layer, tiles, [0, 0], [200, 20])).toEqual([7, 1]);
    expect(layerCell({ ...layer, scrollScale: [0, 0] }, tiles, [0, 0], [200, 20])).toEqual([2, 1]);
    // Above the layer's top it is a row up; and a tile layer's own offset counts.
    expect(layerCell({ ...layer, scrollScale: [0, 0] }, { ...tiles, position: [0, 8] }, [0, 0], [40, 4])).toEqual([2, -1]);
  });
});

describe("which Background a Room shows", () => {
  const world: WorldData = {
    regions: {
      coast: { name: "Coast", colour: "#183931", background: "res://coast.tscn", backgrounds: { cave: "res://cave.tscn" } },
      reef: { name: "Reef", colour: "#31254a" },
    },
    rooms: {
      beach: { scene: "res://beach.tscn", cell: [0, 0], size: [1, 1], region: "coast", exits: [] },
      cliffs: { scene: "res://cliffs.tscn", cell: [1, 0], size: [1, 1], region: "coast", exits: [] },
      cave: { scene: "res://cave_room.tscn", cell: [1, 1], size: [1, 1], region: "coast", exits: [], background: "cave" },
      shelf: { cell: [2, 0], size: [1, 1], region: "coast", exits: [] },
      reef: { scene: "res://reef.tscn", cell: [3, 0], size: [1, 1], region: "reef", exits: [] },
    },
  };

  it("is its Region's, or the other one the Room names; none for a Region without one", () => {
    expect(backgroundOf(world, "beach")).toBe("res://coast.tscn");
    expect(backgroundOf(world, "cave")).toBe("res://cave.tscn");
    expect(backgroundOf(world, "reef")).toBe("");
  });

  it("is shared by every built Room that shows it", () => {
    expect(roomsSharing(world, "res://coast.tscn")).toEqual(["beach", "cliffs"]);
    expect(roomsSharing(world, "res://cave.tscn")).toEqual(["cave"]);
  });
});
