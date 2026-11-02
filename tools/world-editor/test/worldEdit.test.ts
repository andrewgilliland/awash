import { describe, expect, it } from "vitest";
import type { WorldData } from "../src/world";
import { asPlanned } from "../src/world";
import {
  addPlannedRoom,
  moveRoom,
  removePlannedRoom,
  resizeRoom,
  roomAt,
  setMarker,
  setNote,
  setRegion,
  toggleExit,
} from "../src/worldEdit";

// Made-up: a built cove that the Plan moves one screen up, a built two-screen shore, and a planned
// reef in its own Region, east of the shore.
const WORLD: WorldData = {
  regions: { coast: { name: "Coast", colour: "#183931" }, reef: { name: "Reef", colour: "#31254a" } },
  rooms: {
    cove: {
      scene: "res://cove.tscn",
      cell: [0, 0],
      size: [1, 1],
      region: "coast",
      exits: [{ screen: [0, 0], side: "east" }],
      plan: { cell: [0, -1] },
    },
    shore: {
      scene: "res://shore.tscn",
      cell: [1, 0],
      size: [2, 1],
      region: "coast",
      exits: [{ screen: [0, 0], side: "west" }],
    },
    reef_1: { cell: [3, 0], size: [1, 1], region: "reef", exits: [] },
  },
};
const frozen = structuredClone(WORLD);

describe("a Planned Room", () => {
  it("is added on empty screens, named after its Region", () => {
    const { world, id } = addPlannedRoom(WORLD, "reef", [3, 1], [2, 1])!;
    expect(id).toBe("reef_2");
    expect(world.rooms.reef_2).toEqual({ cell: [3, 1], size: [2, 1], region: "reef", exits: [] });
    expect(WORLD).toEqual(frozen);
  });

  it("can't be added over another Room", () => {
    expect(addPlannedRoom(WORLD, "reef", [2, 0], [1, 1])).toBeNull();
  });

  it("moves and resizes, keeping its Exits and marks on screens it still has", () => {
    const marked = setMarker(toggleExit(WORLD, "reef_1", [0, 0], "south"), "reef_1", "boss", [0, 0]);
    const moved = moveRoom(marked, "reef_1", [4, 2])!;
    expect(moved.rooms.reef_1.cell).toEqual([4, 2]);
    const grown = resizeRoom(moved, "reef_1", [2, 2])!;
    expect(grown.rooms.reef_1.size).toEqual([2, 2]);
    const shrunk = resizeRoom(setMarker(grown, "reef_1", "boss", [1, 1]), "reef_1", [1, 1])!;
    expect(shrunk.rooms.reef_1.markers ?? {}).toEqual({});
    expect(shrunk.rooms.reef_1.exits).toEqual([{ screen: [0, 0], side: "south" }]);
  });

  it("can't move onto another Room", () => {
    expect(moveRoom(WORLD, "reef_1", [2, 0])).toBeNull();
  });

  it("is removed, with the Exits that led into it", () => {
    const linked = toggleExit(WORLD, "shore", [1, 0], "east");
    const gone = removePlannedRoom(linked, "reef_1")!;
    expect(gone.rooms.reef_1).toBeUndefined();
    expect(asPlanned(gone.rooms.shore).exits).toEqual([{ screen: [0, 0], side: "west" }]);
  });

  it("is the only kind of Room that can be removed or resized", () => {
    expect(removePlannedRoom(WORLD, "shore")).toBeNull();
    expect(resizeRoom(WORLD, "shore", [3, 1])).toBeNull();
  });
});

describe("a built Room", () => {
  it("moves only in its plan, never where it is today", () => {
    const moved = moveRoom(WORLD, "shore", [1, 2])!;
    expect(moved.rooms.shore.cell).toEqual([1, 0]);
    expect(moved.rooms.shore.plan).toEqual({ cell: [1, 2] });
  });

  it("drops its plan when the plan comes back to where it is", () => {
    const back = moveRoom(WORLD, "cove", [0, 0])!;
    expect(back.rooms.cove.plan).toBeUndefined();
  });

  it("takes a new Region in its plan", () => {
    expect(setRegion(WORLD, "shore", "reef").rooms.shore.plan).toEqual({ region: "reef" });
    expect(setRegion(WORLD, "reef_1", "coast").rooms.reef_1.region).toBe("coast");
  });
});

describe("an Exit", () => {
  it("from a side adds the one back from the Room next door, and goes with it", () => {
    const added = toggleExit(WORLD, "shore", [1, 0], "east");
    expect(asPlanned(added.rooms.shore).exits).toContainEqual({ screen: [1, 0], side: "east" });
    expect(added.rooms.reef_1.exits).toEqual([{ screen: [0, 0], side: "west" }]);
    const removed = toggleExit(added, "reef_1", [0, 0], "west");
    expect(removed.rooms.reef_1.exits).toEqual([]);
    expect(removed.rooms.shore.plan).toBeUndefined();
  });

  it("down as a Drop leads into the Room below with no way back up", () => {
    const below = addPlannedRoom(WORLD, "reef", [3, 1], [1, 1])!;
    const dropped = toggleExit(below.world, "reef_1", [0, 0], "south", { drop: true });
    expect(dropped.rooms.reef_1.exits).toEqual([{ screen: [0, 0], side: "south" }]);
    expect(dropped.rooms[below.id].exits).toEqual([]);
    const climb = toggleExit(below.world, "reef_1", [0, 0], "south");
    expect(climb.rooms[below.id].exits).toEqual([{ screen: [0, 0], side: "north" }]);
  });

  it("on a built Room changes its plan, starting from the Exits it has today", () => {
    const added = toggleExit(WORLD, "shore", [1, 0], "east");
    expect(added.rooms.shore.exits).toEqual([{ screen: [0, 0], side: "west" }]);
    expect(added.rooms.shore.plan!.exits).toEqual([
      { screen: [0, 0], side: "west" },
      { screen: [1, 0], side: "east" },
    ]);
  });
});

describe("the planned World", () => {
  it("tells which Room is on a screen", () => {
    expect(roomAt(WORLD, [0, -1])).toBe("cove");
    expect(roomAt(WORLD, [0, 0])).toBeNull();
    expect(roomAt(WORLD, [2, 0])).toBe("shore");
  });

  it("keeps a Room's note", () => {
    expect(setNote(WORLD, "reef_1", "A reef.").rooms.reef_1.note).toBe("A reef.");
    expect(setNote(setNote(WORLD, "reef_1", "A reef."), "reef_1", "").rooms.reef_1.note).toBeUndefined();
  });
});
