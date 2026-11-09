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
    const rusk = enemy("rusk");
    expect(rusk?.planned).toBe(true);
    expect(rusk?.stats).toBeNull();
    expect(rusk?.sprite).toBeNull();
    // The Pirate is built, on guard at the root hollow's foot.
    expect(enemy("pirate")?.planned).toBe(false);
    expect(enemy("pirate")?.rooms.map((room) => room.id)).toEqual(["low_canopy_jungle_7"]);
    // The Stalker is built, perched in the canopy walk, the upper terraces and the root hollow.
    expect(enemy("stalker")?.planned).toBe(false);
    expect(enemy("stalker")?.rooms.map((room) => room.id)).toEqual([
      "low_canopy_jungle_3",
      "low_canopy_jungle_4",
      "low_canopy_jungle_7",
    ]);
    // The Spore Beast is built, in its lair.
    expect(enemy("spore_beast")?.planned).toBe(false);
    expect(enemy("spore_beast")?.rooms.map((room) => room.id)).toEqual(["low_canopy_jungle_5"]);
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
    expect(brinecap).toEqual(["scavenger", "silt_crab", "spore_beast", "stalker", "storm_wisp"]);
  });

  it("reads Sub Weapons, Weapons and Armor", () => {
    expect(item("bomb")?.kind).toBe("Sub Weapon");
    expect(item("bomb")?.caches).toEqual([{ id: "bomb_crate", room: "tidefen_village_1", count: 5 }]);
    expect(item("bomb")?.droppedBy).toEqual([{ enemy: "pirate", chance: 0.25 }]);
    expect(item("oathblade")?.kind).toBe("Weapon");
    expect(item("oathblade")?.effect).toBe("Attack +5");
    expect(item("oathblade")?.droppedBy).toEqual([{ enemy: "wraith", chance: 0.1 }]);
    expect(item("worn_leather_tunic")?.kind).toBe("Armor");
    expect(item("scale_mail")).toMatchObject({ kind: "Armor", effect: "Defense +3", planned: false });
    expect(item("scale_mail")?.caches).toEqual([{ id: "wreck_mail", room: "undertow_5", count: 1 }]);
    expect(item("stout_axe")).toMatchObject({ kind: "Weapon", effect: "Attack +6", planned: false, traitBuilt: true });
    expect(item("stout_axe")?.caches).toEqual([{ id: "pools_axe", room: "undertow_4", count: 1 }]);
  });

  it("lists items only in the docs as planned, one of their kind", () => {
    expect(item("blacktide")).toMatchObject({ kind: "Weapon", planned: true });
    expect(item("bracer")).toMatchObject({ kind: "Accessory", planned: true, icon: "assets/items/bracer.png" });
    expect(item("shoalglass_mail")).toMatchObject({ kind: "Armor", planned: true, icon: "assets/items/shoalglass_mail.png" });
    expect(item("galecutter")).toMatchObject({ kind: "Weapon", planned: true, icon: "assets/items/galecutter.png" });
  });

  it("reads a planned item's Attack, Defense or effect, and its trait, from its doc", () => {
    expect(item("galecutter")).toMatchObject({ effect: "Attack +16", trait: "A slash that lands while Vael is jumping or falling takes 50% more of the enemy's Health." });
    expect(item("shoalglass_mail")).toMatchObject({ effect: "Defense +6", trait: "Supplies restore 50% more Health." });
    expect(item("blacktide")?.effect).toBe("Attack +8");
    expect(item("blacktide")?.trait).toContain("quick slashes break a Ward");
    expect(item("bracer")?.effect).toBe("Increases Throwing Knife damage.");
    expect(item("bracer")?.trait).toBe("");
  });

  it("keeps an item in the game's own effect, and adds its doc's trait", () => {
    expect(item("scale_mail")).toMatchObject({ effect: "Defense +3", trait: "Hits push Vael back half as far." });
    expect(item("scale_mail")?.traitBuilt).toBe(false);
    expect(item("galecutter")?.traitBuilt).toBe(false);
    expect(item("oathblade")?.trait).toBe("Its Sword Beam passes through every enemy in its way.");
    expect(item("meat_pie")?.trait).toBe("");
  });

  it("names a planned item by its doc's id, with the icon its doc gives", () => {
    expect(item("corsairs_coat")).toMatchObject({ name: "Corsair's Coat", icon: "assets/items/corsairs_coat.png" });
    expect(item("corsair_s_coat")).toBeUndefined();
    expect(item("marshals_edge")?.icon).toBe("assets/items/marshals_edge.png");
  });

  it("reads an Accessory's id and icon from the top of its doc", () => {
    expect(item("salvagers_coin")).toMatchObject({ name: "Salvager's Coin", icon: "assets/items/salvagers_coin.png" });
    expect(item("salvager_s_coin")).toBeUndefined();
  });

  it("reads a Weapon or Armor as one item, found as it is, with one icon", () => {
    expect(item("blacktide")).toMatchObject({ planned: true, icon: "assets/items/blacktide.png" });
    expect(item("blacktide")).not.toHaveProperty("forms");
    expect(item("worn_leather_tunic")?.lore).not.toContain("Smith");
  });

  it("leaves the trait out of a planned item's words from the docs", () => {
    expect(item("galecutter")?.lore).not.toContain("50% more");
  });
});

describe("the Codex's World", () => {
  const room = (id: string) => codex.rooms.find((entry) => entry.id === id);
  const kinds = (id: string) => room(id)?.marks.map((mark) => mark.kind);

  it("holds every Room in the World, built or planned, with its cell, size and exits", () => {
    expect(codex.rooms.length).toBe(29);
    expect(room("waking_coast_1")).toMatchObject({ region: "waking_coast", cell: [-1, 0], size: [2, 1], planned: false });
    expect(room("undertow_8")).toMatchObject({ region: "undertow", cell: [6, 3], size: [2, 2], planned: true });
    expect(room("undertow_8")?.exits).toEqual([{ screen: [1, 1], side: "east" }]);
    expect(room("shrinekeeper_camp_1")).toMatchObject({ region: "shrinekeeper_camp", cell: [31, -3], planned: false });
  });

  it("marks what each Room holds: its Caches, Rest point, Shop, Characters, Boss and enemies", () => {
    expect(room("undertow_5")?.marks).toContainEqual({ kind: "cache", id: "scale_mail", label: "Cache wreck_mail: Scale Mail" });
    expect(kinds("tidefen_village_1")).toEqual(expect.arrayContaining(["rest", "shop", "character"]));
    expect(kinds("shrinekeeper_camp_1")).toEqual(expect.arrayContaining(["rest", "shop"]));
    expect(room("waking_coast_7")?.marks).toContainEqual({ kind: "boss", id: "nameless_warden", label: "Nameless Warden" });
    expect(codex.rooms.flatMap((entry) => entry.marks).some((mark) => mark.kind === "enemy" && mark.id === "scavenger")).toBe(true);
    expect(room("undertow_8")?.marks).toEqual([]);
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
