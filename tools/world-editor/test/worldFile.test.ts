import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { serializeWorld } from "../src/worldFile";

const REPO = resolve(__dirname, "../../..");
const text = readFileSync(resolve(REPO, "assets/world.json"), "utf8");

describe("writing the World's data", () => {
  it("writes the file back exactly as it is laid out, so saving with no edits changes nothing", () => {
    expect(serializeWorld(JSON.parse(text))).toBe(text);
  });

  it("writes a new Room's fields in the file's order, its note first", () => {
    const world = JSON.parse(text);
    world.rooms.reef_1 = { exits: [], region: "undertow", size: [1, 1], cell: [0, 5], note: "A reef." };
    const written = serializeWorld(world);
    expect(written).toContain(
      '\t\t"reef_1": {\n\t\t\t"note": "A reef.",\n\t\t\t"cell": [0, 5],\n\t\t\t"size": [1, 1],\n\t\t\t"region": "undertow",\n\t\t\t"exits": []\n\t\t}\n',
    );
    expect(JSON.parse(written)).toEqual(world);
  });
});
