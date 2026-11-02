import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { decodeTileMapData, encodeTileMapData, parseRoomScene, setLayerCells } from "../src/godot";

const REPO = resolve(__dirname, "../../..");
const ROOMS = resolve(REPO, "scenes/rooms");
const scenes = readdirSync(ROOMS).filter((name) => name.endsWith(".tscn"));

describe("writing a layer's tiles", () => {
  it("encodes every layer of every Room back exactly as Godot wrote it", () => {
    let layers = 0;
    for (const name of scenes) {
      const text = readFileSync(resolve(ROOMS, name), "utf8");
      for (const [, data] of text.matchAll(/^tile_map_data = PackedByteArray\("([^"]*)"\)$/gm)) {
        expect(encodeTileMapData(decodeTileMapData(data))).toBe(data);
        layers++;
      }
    }
    expect(layers).toBeGreaterThan(20);
  });

  it("changes only that layer's tiles in the scene", () => {
    const text = readFileSync(resolve(ROOMS, "waking_coast_1.tscn"), "utf8");
    const before = parseRoomScene(text);
    const props = before.layers.find((layer) => layer.name === "Props")!;
    const cells = [...props.cells, { x: 3, y: 5, source: 16, atlas: [1, 1] as [number, number], alternative: 0 }];
    const written = setLayerCells(text, "Props", cells);
    const after = parseRoomScene(written);
    expect(after.layers.find((layer) => layer.name === "Props")!.cells).toEqual(cells);
    for (const layer of before.layers.filter((layer) => layer.name !== "Props")) {
      expect(after.layers.find((other) => other.name === layer.name)).toEqual(layer);
    }
    const changed = text.split("\n").filter((line, i) => line !== written.split("\n")[i]);
    expect(changed).toHaveLength(1);
    expect(changed[0]).toMatch(/^tile_map_data = /);
  });

  it("gives a layer with no tiles yet a line for them", () => {
    const text = '[node name="Props" type="TileMapLayer" parent="."]\ntile_set = ExtResource("scenery_tiles")\n\n[node name="Player" parent="."]\n';
    const cell = { x: 1, y: 2, source: 3, atlas: [4, 5] as [number, number], alternative: 0 };
    const written = setLayerCells(text, "Props", [cell]);
    expect(parseRoomScene(written).layers[0].cells).toEqual([cell]);
    expect(written).toContain('[node name="Player" parent="."]');
  });
});
