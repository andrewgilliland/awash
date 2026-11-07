import { describe, expect, it } from "vitest";
import { readConsts, readVars } from "../server/gdscript";

const SCRIPT = `extends CharacterBody2D

# A comment, and a const in it: const NOT_THIS := 1
const Supplies := preload("res://scripts/items/supplies.gd")
const MAX_HEALTH := 30
const DROP_CHANCE := 0.25
const DROP := &"glowroe"
const GOT := "GOT %s"
const FRAME_SIZE := Vector2i(16, 16)
const STOCK := [
	[Supplies.MEAT_PIE, 15],
	[&"brinecap", 8],
]
const KINDS := {
	MEAT_PIE:
	{
		name = "Meat Pie",
		description = "Still warm. Restores 20 Health.",
		restores = 20,
	},
	&"mourning_salt": {name = "Mourning Salt", restores_share = 0.5},
}
const TYPED: int = 7
const MEAT_PIE := &"meat_pie"

var drop_damage: int = 15
var gravity: float = 980.0
var state: State = State.CLINGING
`;

describe("reading a GDScript's consts", () => {
  const consts = readConsts(SCRIPT);

  it("reads numbers, strings, StringNames and typed consts", () => {
    expect(consts.MAX_HEALTH).toBe(30);
    expect(consts.DROP_CHANCE).toBe(0.25);
    expect(consts.DROP).toEqual({ name: "glowroe" });
    expect(consts.GOT).toBe("GOT %s");
    expect(consts.TYPED).toBe(7);
  });

  it("reads calls such as preload and Vector2i", () => {
    expect(consts.Supplies).toEqual({ call: "preload", args: ["res://scripts/items/supplies.gd"] });
    expect(consts.FRAME_SIZE).toEqual({ call: "Vector2i", args: [16, 16] });
  });

  it("reads arrays and dictionaries over many lines, keyed by name or by value", () => {
    expect(consts.STOCK).toEqual([
      [{ ref: "Supplies.MEAT_PIE" }, 15],
      [{ name: "brinecap" }, 8],
    ]);
    const kinds = consts.KINDS as { key: unknown; value: Record<string, unknown> }[];
    expect(kinds).toEqual([
      {
        key: { ref: "MEAT_PIE" },
        value: { name: "Meat Pie", description: "Still warm. Restores 20 Health.", restores: 20 },
      },
      { key: { name: "mourning_salt" }, value: { name: "Mourning Salt", restores_share: 0.5 } },
    ]);
  });

  it("leaves comments alone", () => {
    expect(consts.NOT_THIS).toBeUndefined();
  });
});

describe("reading a GDScript's plain vars", () => {
  it("reads the ones set to a literal", () => {
    expect(readVars(SCRIPT)).toEqual({ drop_damage: 15, gravity: 980 });
  });
});
