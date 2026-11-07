import { describe, expect, it } from "vitest";
import { formatRoute, frameRect, parseRoute, shown } from "../src/select";

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
