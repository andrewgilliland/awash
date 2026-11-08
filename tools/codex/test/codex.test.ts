import { resolve } from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import { buildCodex, type Codex } from "../server/codex";

const REPO = resolve(__dirname, "../../..");
let codex: Codex;

beforeAll(async () => {
  codex = await buildCodex(REPO);
});

const enemy = (id: string) => codex.enemies.find((entry) => entry.id === id);
const item = (id: string) => codex.items.find((entry) => entry.id === id);

describe("the Codex's enemies", () => {
  it("reads an enemy's stats, drops and hits from its scripts and scene", () => {
    const scavenger = enemy("scavenger");
    expect(scavenger?.planned).toBe(false);
    expect(scavenger?.stats).toEqual({ health: 30, experience: 10, gold: 2 });
    expect(scavenger?.drops).toEqual([{ item: "brinecap", chance: 0.25 }]);
    expect(scavenger?.hits).toEqual([{ name: "Spear", damage: 10 }]);
  });

  it("reads named drops, a Weapon drop, and a hitbox's own damage", () => {
    const wraith = enemy("wraith");
    expect(wraith?.drops).toEqual([
      { item: "mourning_salt", chance: 0.35 },
      { item: "oathblade", chance: 0.1 },
    ]);
    expect(wraith?.hits).toEqual([{ name: "Lash", damage: 15 }]);
  });

  it("reads hits a script sets, and those of the scenes it sends out", () => {
    expect(enemy("silt_crab")?.hits).toEqual([
      { name: "Drop", damage: 15 },
      { name: "Touch", damage: 10 },
    ]);
    const warden = enemy("nameless_warden");
    expect(warden?.boss).toBe(true);
    expect(warden?.drops).toEqual([]);
    expect(warden?.hits).toEqual([
      { name: "Touch", damage: 10 },
      { name: "Bash", damage: 15 },
      { name: "Shockwave", damage: 10 },
    ]);
  });

  it("finds every Room an enemy stands in, with its Region", () => {
    const rooms = enemy("silt_crab")?.rooms.map((room) => room.id);
    expect(rooms).toEqual(["undertow_2", "undertow_3", "undertow_5"]);
    expect(enemy("silt_crab")?.rooms[0].region).toBe("Undertow");
  });

  it("takes its lore from its doc", () => {
    const crab = enemy("silt_crab");
    expect(crab?.name).toBe("Silt Crab");
    expect(crab?.category).toBe("Beast");
    expect(crab?.encounters[0].region).toBe("Undertow");
  });

  it("draws it from its sheet, by frame size or by the scene's grid", () => {
    expect(enemy("scavenger")?.sprite).toMatchObject({
      sheet: "assets/enemies/scavenger/scavenger_1.png",
      frame: [16, 16],
    });
    expect(enemy("scavenger")?.sprite?.animations?.patrol).toEqual([0, 1]);
    expect(enemy("nameless_warden")?.sprite).toMatchObject({
      sheet: "assets/enemies/nameless_warden/nameless_warden_1.png",
      grid: [6, 2],
    });
  });

  it("lists enemies only in the docs as planned, with no stats", () => {
    const stalker = enemy("stalker");
    expect(stalker?.planned).toBe(true);
    expect(stalker?.stats).toBeNull();
    expect(stalker?.sprite).toBeNull();
  });
});

describe("the Codex's items", () => {
  it("reads a Supply's effect, and where to get it: a Shop and Caches", () => {
    const pie = item("meat_pie");
    expect(pie?.kind).toBe("Supply");
    expect(pie?.effect).toBe("Restores 20 Health");
    expect(pie?.price).toBe(15);
    expect(pie?.caches.map((cache) => [cache.room, cache.count])).toEqual([
      ["waking_coast_3", 2],
      ["waking_coast_5", 2],
    ]);
    expect(pie?.icon).toBe("assets/items/meat_pie.png");
  });

  it("names a share of Health, and every enemy that drops it", () => {
    const salt = item("mourning_salt");
    expect(salt?.effect).toBe("Restores half your Health");
    expect(salt?.droppedBy).toEqual([{ enemy: "wraith", chance: 0.35 }]);
    // The docs' word on it, without the files they point at.
    expect(item("brinecap")?.lore).toContain("salt-crusted mushroom");
    expect(item("brinecap")?.lore).not.toContain("assets/");
    const brinecap = item("brinecap")?.droppedBy.map((drop) => drop.enemy);
    expect(brinecap).toEqual(["scavenger", "silt_crab", "storm_wisp"]);
  });

  it("reads Sub Weapons, Weapons and Armor", () => {
    expect(item("bomb")?.kind).toBe("Sub Weapon");
    expect(item("bomb")?.caches).toEqual([{ id: "bomb_crate", room: "tidefen_village_1", count: 5 }]);
    expect(item("oathblade")?.kind).toBe("Weapon");
    expect(item("oathblade")?.effect).toBe("Attack +5");
    expect(item("oathblade")?.droppedBy).toEqual([{ enemy: "wraith", chance: 0.1 }]);
    expect(item("worn_leather_tunic")?.kind).toBe("Armor");
    expect(item("scale_mail")).toMatchObject({ kind: "Armor", effect: "Defense +3", planned: false });
    expect(item("scale_mail")?.caches).toEqual([{ id: "wreck_mail", room: "undertow_5", count: 1 }]);
  });

  it("lists items only in the docs as planned, one of their kind", () => {
    expect(item("blacktide")).toMatchObject({ kind: "Weapon", planned: true, icon: null });
    expect(item("bracer")).toMatchObject({ kind: "Accessory", planned: true });
    expect(item("shoalglass_mail")).toMatchObject({ kind: "Armor", planned: true, icon: null });
    expect(item("galecutter")).toMatchObject({ kind: "Weapon", planned: true, icon: null });
  });
});

describe("the Codex's characters", () => {
  it("joins a story character's doc to them in the game", () => {
    const mara = codex.characters.find((entry) => entry.name === "Mara Venn");
    expect(mara?.planned).toBe(false);
    expect(mara?.sprite).toBe("assets/npcs/mara/mara_venn_1.png");
    expect(mara?.rooms).toEqual(["waking_coast_1"]);
    expect(mara?.details.occupation).toBe("Salvager and mapkeeper");
    // Links to other docs are left out.
    expect(mara?.details.home).toBeUndefined();
  });

  it("lists the people of the Rooms, with their lines", () => {
    const netter = codex.characters.find((entry) => entry.name === "Netter");
    expect(netter?.sprite).toBe("assets/npcs/netter/netter.png");
    expect(netter?.rooms).toEqual(["tidefen_village_1"]);
    expect(netter?.lines.length).toBe(3);
  });
});

describe("the Codex's Regions", () => {
  it("gathers each Region's Rooms, enemies, Caches, Rest points and shops", () => {
    const undertow = codex.regions.find((region) => region.name === "Undertow");
    // Its seven Rooms under the cliffs, and the graveyard's beach the World puts in it too.
    expect(undertow?.rooms.map((room) => room.id)).toContain("waking_coast_9");
    expect(undertow?.rooms.length).toBe(8);
    expect(undertow?.enemies).toEqual(expect.arrayContaining(["lurelight", "silt_crab", "wraith"]));
    expect(undertow?.caches.map((cache) => cache.id)).toEqual(
      expect.arrayContaining(["passage_chest", "lake_chest", "wreck_mail"]),
    );
    const tidefen = codex.regions.find((region) => region.name === "Tidefen Village");
    expect(tidefen?.restPoints).toEqual(["tidefen_village_1"]);
    expect(tidefen?.shops).toEqual(["tidefen_village_1"]);
    expect(tidefen?.colour).toMatch(/^#[0-9a-f]{6}$/);
  });
});
