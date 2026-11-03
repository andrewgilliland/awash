import { describe, expect, it } from "vitest";
import { parseRoomScene, parseSections } from "../src/godot";
import { buildRoom, sceneRootName } from "../src/build";
import type { WorldData } from "../src/world";

// Made-up: a built beach; a planned cove beside it, with a planned cave east of it and a pit it
// drops into; a reef in a Region not ready to build in; a room whose Exit leads nowhere; and a
// tall room with two Exits east into a tall neighbour.
const COAST = { name: "Coast", colour: "#183931", theme: "res://theme.wav", background: "res://bg.tscn", floor: [0, 2, 1] as [number, number, number] };
const WORLD: WorldData = {
  regions: { coast: COAST, reef: { name: "Reef", colour: "#31254a" } },
  rooms: {
    beach: { scene: "res://scenes/rooms/beach.tscn", cell: [0, 0], size: [1, 1], region: "coast", exits: [{ screen: [0, 0], side: "east" }] },
    cove: {
      cell: [1, 0],
      size: [2, 1],
      region: "coast",
      exits: [
        { screen: [0, 0], side: "west" },
        { screen: [1, 0], side: "east" },
        { screen: [1, 0], side: "south" },
      ],
    },
    cave: { cell: [3, 0], size: [1, 1], region: "coast", exits: [{ screen: [0, 0], side: "west" }] },
    pit: { cell: [2, 1], size: [1, 1], region: "coast", exits: [] },
    reef_1: { cell: [5, 0], size: [1, 1], region: "reef", exits: [] },
    lonely: { cell: [7, 0], size: [1, 1], region: "coast", exits: [{ screen: [0, 0], side: "east" }] },
    tall: {
      cell: [9, 0],
      size: [1, 2],
      region: "coast",
      exits: [
        { screen: [0, 0], side: "east" },
        { screen: [0, 1], side: "east" },
      ],
    },
    side_room: {
      cell: [10, 0],
      size: [1, 2],
      region: "coast",
      exits: [
        { screen: [0, 0], side: "west" },
        { screen: [0, 1], side: "west" },
      ],
    },
  },
};

function built(id: string) {
  const result = buildRoom(WORLD, id);
  if ("error" in result) {
    throw new Error(result.error);
  }
  return { ...result, nodes: parseSections(result.scene).filter((s) => s.kind === "node") };
}

const node = (nodes: ReturnType<typeof built>["nodes"], name: string, parent: string) =>
  nodes.find((n) => n.attributes.name === name && n.attributes.parent === parent);

describe("building a Planned Room", () => {
  it("makes its scene, and gives the Room that scene in the World", () => {
    const { path, world } = built("cove");
    expect(path).toBe("scenes/rooms/cove.tscn");
    expect(world.rooms.cove.scene).toBe("res://scenes/rooms/cove.tscn");
    expect(WORLD.rooms.cove.scene).toBeUndefined();
  });

  it("draws a Room in a Region that shares another's tile sets from that Region's folder", () => {
    const village = { ...COAST, name: "Village", colour: "#5c3d1e", tiles: "coast" };
    const sharing: WorldData = { ...WORLD, regions: { ...WORLD.regions, village }, rooms: { ...WORLD.rooms, cove: { ...WORLD.rooms.cove, region: "village" } } };
    const result = buildRoom(sharing, "cove");
    const scene = parseRoomScene("scene" in result ? result.scene : "");
    expect(scene.layers.map((layer) => layer.tileSet)).toEqual([
      "res://assets/regions/coast/tiles/terrain.tres",
      "res://assets/regions/coast/tiles/scenery.tres",
    ]);
  });

  it("starts the Room with a floor of its Region's ground along its bottom, open under a Drop", () => {
    const scene = parseRoomScene(built("cove").scene);
    expect(scene.layers.map((layer) => layer.name)).toEqual(["Terrain", "Props"]);
    const terrain = scene.layers[0];
    expect(terrain.tileSet).toBe("res://assets/regions/coast/tiles/terrain.tres");
    expect(scene.layers[1].tileSet).toBe("res://assets/regions/coast/tiles/scenery.tres");
    expect(terrain.cells.every((cell) => cell.y === 8 && cell.source === 0 && cell.atlas.join() === "2,1")).toBe(true);
    const columns = terrain.cells.map((cell) => cell.x);
    expect(columns).toContain(0);
    expect(columns).toContain(19);
    expect(columns).not.toContain(14);
    expect(columns).not.toContain(15);
  });

  it("gives each Exit an Exit leading to the Entry it arrives by next door, and an Entry", () => {
    const { nodes } = built("cove");
    const west = node(nodes, "west", "Exits")!;
    expect(west.properties.position).toBe("Vector2(-4, 72)");
    expect(west.properties.room_id).toBe('&"beach"');
    expect(west.properties.entry_id).toBe('&"east"');
    expect(node(nodes, "east", "Exits")!.properties.entry_id).toBe('&"west"');
    const south = node(nodes, "south", "Exits")!;
    expect(south.properties.room_id).toBe('&"pit"');
    expect(south.properties.entry_id).toBe('&"north"');
    expect(south.properties.position).toBe("Vector2(240, 148)");
    expect(node(nodes, "west", "Entries")!.properties.position).toBe("Vector2(12, 128)");
    expect(node(nodes, "east", "Entries")!.properties.position).toBe("Vector2(308, 128)");
  });

  it("names Exits by their screen when a side has more than one", () => {
    const { nodes } = built("tall");
    expect(node(nodes, "east_0_1", "Exits")!.properties.entry_id).toBe('&"west_0_1"');
    expect(node(nodes, "east_0_0", "Exits")!.properties.position).toBe("Vector2(164, 72)");
    expect(node(nodes, "east_0_1", "Exits")!.properties.position).toBe("Vector2(164, 216)");
  });

  it("walls a side with no Exit, and leaves sides with one open", () => {
    expect(node(built("cove").nodes, "West", "Bounds")).toBeUndefined();
    const cave = built("cave").nodes;
    expect(node(cave, "West", "Bounds")).toBeUndefined();
    expect(node(cave, "East", "Bounds")!.properties.position).toBe("Vector2(160, 0)");
  });

  it("has what every Room has, in order, with the Player last at its first Entry", () => {
    const { nodes } = built("cove");
    const top = nodes.filter((n) => n.attributes.parent === "." || !n.attributes.parent).map((n) => n.attributes.name);
    expect(top).toEqual(["Cove", "CanvasLayer", "Terrain", "Props", "Bounds", "Exits", "Entries", "Player"]);
    expect(node(nodes, "Player", ".")!.properties.position).toBe("Vector2(12, 128)");
    expect(sceneRootName("waking_coast_10")).toBe("WakingCoast10");
  });

  it("gives a Room that's dropped into an Entry for the Drop, though it has no Exit back up", () => {
    const { nodes } = built("pit");
    expect(node(nodes, "north", "Entries")!.properties.position).toBe("Vector2(80, 16)");
    expect(node(nodes, "north", "Exits")).toBeUndefined();
  });

  it("refuses a built Room, a Region not ready to build in, and an Exit into no Room", () => {
    expect(buildRoom(WORLD, "beach")).toEqual({ error: "beach is built already." });
    expect(buildRoom(WORLD, "reef_1")).toEqual({
      error: "Reef isn't ready to build in: it has no ground tile, theme or Background yet.",
    });
    expect(buildRoom(WORLD, "lonely")).toEqual({ error: "lonely's east Exit leads into no Room." });
  });
});
