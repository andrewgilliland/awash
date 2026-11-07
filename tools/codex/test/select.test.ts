import { describe, expect, it } from "vitest";
import { byKind, formatRoute, frameRect, parseRoute, shown } from "../src/select";

describe("where the page is", () => {
  it("reads a section and an entry from the address, defaulting to the enemies", () => {
    expect(parseRoute("#/items/meat_pie")).toEqual({ section: "items", id: "meat_pie" });
    expect(parseRoute("#/regions")).toEqual({ section: "regions", id: null });
    expect(parseRoute("")).toEqual({ section: "enemies", id: null });
    expect(parseRoute("#/nowhere/x")).toEqual({ section: "enemies", id: null });
  });

  it("writes one back", () => {
    expect(formatRoute({ section: "characters", id: "mara_venn" })).toBe("#/characters/mara_venn");
    expect(formatRoute({ section: "items", id: null })).toBe("#/items");
  });
});

describe("which entries the list shows", () => {
  const entries = [
    { name: "Scavenger", planned: false },
    { name: "Silt Crab", planned: false },
    { name: "Stalker", planned: true },
  ];

  it("shows those in the game, planned, or all", () => {
    expect(shown(entries, "game", "").map((entry) => entry.name)).toEqual(["Scavenger", "Silt Crab"]);
    expect(shown(entries, "planned", "").map((entry) => entry.name)).toEqual(["Stalker"]);
    expect(shown(entries, "all", "").length).toBe(3);
  });

  it("narrows them by a search, in any case, anywhere in the name", () => {
    expect(shown(entries, "all", "CRAB").map((entry) => entry.name)).toEqual(["Silt Crab"]);
    expect(shown(entries, "all", " s ").length).toBe(3);
  });
});

describe("the items, split by type", () => {
  const items = [
    { name: "Meat Pie", kind: "Supply" },
    { name: "Scale Mail", kind: "Armor" },
    { name: "Bomb", kind: "Sub Weapon" },
    { name: "Bracer", kind: "Accessory" },
    { name: "Short Sword", kind: "Weapon" },
    { name: "Brinecap", kind: "Supply" },
    { name: "Throwing Knives", kind: "Ammunition" },
    { name: "Tidewalk Relic", kind: "Traversal Relic" },
    { name: "Worn Leather Tunic", kind: "Armor" },
    { name: "Drowned Key", kind: "Key" },
  ];
  const groups = byKind(items);

  it("puts the Equipment first, then what you carry, then what you use up, then the rest A to Z", () => {
    expect(groups.map((group) => group.title)).toEqual([
      "Weapons",
      "Armor",
      "Accessories",
      "Sub Weapons",
      "Ammunition",
      "Supplies",
      "Keys",
      "Traversal Relics",
    ]);
  });

  it("keeps each type's items in the order they came", () => {
    expect(groups.find((group) => group.title === "Armor")?.entries.map((item) => item.name)).toEqual([
      "Scale Mail",
      "Worn Leather Tunic",
    ]);
    expect(groups.find((group) => group.title === "Supplies")?.entries.length).toBe(2);
  });

  it("leaves out a type with nothing in it", () => {
    expect(byKind([{ name: "Bomb", kind: "Sub Weapon" }]).map((group) => group.title)).toEqual(["Sub Weapons"]);
    expect(byKind([])).toEqual([]);
  });
});

describe("cutting a sheet into frames", () => {
  it("cuts frames of a size along a row", () => {
    expect(frameRect({ sheet: "x.png", frame: [16, 16] }, 176, 16, 3)).toEqual({ x: 48, y: 0, w: 16, h: 16 });
  });

  it("cuts a grid across and down", () => {
    expect(frameRect({ sheet: "x.png", grid: [6, 2] }, 192, 64, 7)).toEqual({ x: 32, y: 32, w: 32, h: 32 });
  });

  it("takes a square frame the sheet's height when it says nothing", () => {
    expect(frameRect({ sheet: "x.png" }, 32, 16, 1)).toEqual({ x: 16, y: 0, w: 16, h: 16 });
  });
});
