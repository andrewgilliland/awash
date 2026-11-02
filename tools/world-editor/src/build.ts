// Building a Planned Room: its scene, made from a template, and the World giving the Room that scene.
// The scene has what every Room has: the Room script, its tile layers with a starter floor of its
// Region's ground, walls on sides with no Exit, an Exit for each of its Exits leading to the Entry it
// arrives by next door, an Entry for each way in, and the Player at the first.

import { encodeTileMapData, type Cell } from "./godot";
import { asPlanned, type Exit, type Side, type Vec, type WorldData } from "./world";
import { roomAt } from "./worldEdit";

const SCREEN = { w: 160, h: 144 };
const TILE = 16;
const STEP: Record<Side, Vec> = { north: [0, -1], east: [1, 0], south: [0, 1], west: [-1, 0] };
const OPPOSITE: Record<Side, Side> = { north: "south", south: "north", east: "west", west: "east" };
// The gap left in the floor under a Drop: two tiles in the middle of its screen.
const DROP_GAP = [4, 5];

export type BuildResult = { path: string; scene: string; world: WorldData } | { error: string };

export function sceneRootName(id: string): string {
  return id
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join("");
}

// Every way into a Room: back through each of its own Exits, and down each Drop that lands in it.
function arrivals(world: WorldData, id: string): Exit[] {
  const room = asPlanned(world.rooms[id]);
  const found: Exit[] = room.exits.map((exit) => ({ screen: exit.screen, side: exit.side }));
  for (const [other, record] of Object.entries(world.rooms)) {
    if (other === id) {
      continue;
    }
    const there = asPlanned(record);
    for (const exit of there.exits) {
      const beyond: Vec = [
        there.cell[0] + exit.screen[0] + STEP[exit.side][0],
        there.cell[1] + exit.screen[1] + STEP[exit.side][1],
      ];
      if (roomAt(world, beyond) !== id) {
        continue;
      }
      const screen: Vec = [beyond[0] - room.cell[0], beyond[1] - room.cell[1]];
      const side = OPPOSITE[exit.side];
      if (!found.some((known) => known.side === side && known.screen.join() === screen.join())) {
        found.push({ screen, side });
      }
    }
  }
  return found;
}

// An Exit or Entry is named for its side, and for its screen too when its side has more than one.
function nameOf(all: Exit[], exit: Exit): string {
  const onSide = all.filter((other) => other.side === exit.side).length;
  return onSide > 1 ? `${exit.side}_${exit.screen[0]}_${exit.screen[1]}` : exit.side;
}

const v = (x: number, y: number) => `Vector2(${x}, ${y})`;

export function buildRoom(world: WorldData, id: string): BuildResult {
  const record = world.rooms[id];
  if (record.scene !== undefined) {
    return { error: `${id} is built already.` };
  }
  const room = asPlanned(record);
  const region = world.regions[room.region];
  if (!region?.floor || !region.theme || !region.background) {
    return { error: `${region?.name ?? room.region} isn't ready to build in: it has no ground tile, theme or Background yet.` };
  }
  const size = { w: room.size[0] * SCREEN.w, h: room.size[1] * SCREEN.h };

  const exits: { name: string; position: string; shape: string; to: string; entry: string }[] = [];
  for (const exit of room.exits) {
    const beyond: Vec = [
      room.cell[0] + exit.screen[0] + STEP[exit.side][0],
      room.cell[1] + exit.screen[1] + STEP[exit.side][1],
    ];
    const to = roomAt(world, beyond, id);
    if (!to) {
      return { error: `${id}'s ${exit.side} Exit leads into no Room.` };
    }
    const there = asPlanned(world.rooms[to]);
    const arrival: Exit = { screen: [beyond[0] - there.cell[0], beyond[1] - there.cell[1]], side: OPPOSITE[exit.side] };
    const sx = exit.screen[0] * SCREEN.w;
    const sy = exit.screen[1] * SCREEN.h;
    const position = {
      west: v(-4, sy + SCREEN.h / 2),
      east: v(size.w + 4, sy + SCREEN.h / 2),
      north: v(sx + SCREEN.w / 2, -4),
      south: v(sx + SCREEN.w / 2, size.h + 4),
    }[exit.side];
    exits.push({
      name: nameOf(room.exits, exit),
      position,
      shape: exit.side === "west" || exit.side === "east" ? "RectangleShape2D_side" : "RectangleShape2D_drop",
      to,
      entry: nameOf(arrivals(world, to), arrival),
    });
  }

  const ways = arrivals(world, id);
  const entries = ways.map((way) => {
    const sx = way.screen[0] * SCREEN.w;
    const sy = way.screen[1] * SCREEN.h;
    const floor = sy + SCREEN.h - TILE;
    const at = {
      west: [12, floor],
      east: [size.w - 12, floor],
      north: [sx + SCREEN.w / 2, sy + TILE],
      south: [sx + SCREEN.w / 4, floor],
    }[way.side];
    return { name: nameOf(ways, way), position: v(at[0], at[1]) };
  });

  // The starter floor: the Room's bottom row, open under each Drop out of it.
  const bottom = room.size[1] * (SCREEN.h / TILE) - 1;
  const gaps = new Set(
    room.exits
      .filter((exit) => exit.side === "south")
      .flatMap((exit) => DROP_GAP.map((x) => exit.screen[0] * (SCREEN.w / TILE) + x)),
  );
  const [source, ax, ay] = region.floor;
  const floor: Cell[] = [];
  for (let x = 0; x < room.size[0] * (SCREEN.w / TILE); x++) {
    if (!gaps.has(x)) {
      floor.push({ x, y: bottom, source, atlas: [ax, ay], alternative: 0 });
    }
  }

  const sides = new Set(room.exits.map((exit) => exit.side));
  const walls = (["west", "east"] as Side[]).filter((side) => !sides.has(side));
  const shapes = [
    ...(exits.some((e) => e.shape === "RectangleShape2D_side") ? [`[sub_resource type="RectangleShape2D" id="RectangleShape2D_side"]\nsize = ${v(8, SCREEN.h)}`] : []),
    ...(exits.some((e) => e.shape === "RectangleShape2D_drop") ? [`[sub_resource type="RectangleShape2D" id="RectangleShape2D_drop"]\nsize = ${v(DROP_GAP.length * TILE, 8)}`] : []),
    ...walls.map((side) => `[sub_resource type="WorldBoundaryShape2D" id="WorldBoundaryShape2D_${side}"]\nnormal = ${side === "west" ? v(1, 0) : v(-1, 0)}`),
  ];
  const tiles = `res://assets/regions/${room.region}/tiles`;
  const resources = [
    `[ext_resource type="Script" path="res://scripts/core/main.gd" id="1_room"]`,
    `[ext_resource type="TileSet" path="${tiles}/terrain.tres" id="terrain_tiles"]`,
    `[ext_resource type="TileSet" path="${tiles}/scenery.tres" id="scenery_tiles"]`,
    `[ext_resource type="Script" path="res://scripts/core/room_exit.gd" id="4_exit"]`,
    `[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="5_player"]`,
  ];
  const nodes = [
    `[node name="${sceneRootName(id)}" type="Node2D"]\nscript = ExtResource("1_room")`,
    `[node name="CanvasLayer" type="CanvasLayer" parent="."]`,
    `[node name="Terrain" type="TileMapLayer" parent="."]\ntile_map_data = PackedByteArray("${encodeTileMapData(floor)}")\ntile_set = ExtResource("terrain_tiles")`,
    `[node name="Props" type="TileMapLayer" parent="."]\ntile_set = ExtResource("scenery_tiles")`,
    `[node name="Bounds" type="StaticBody2D" parent="."]\ncollision_mask = 0`,
    ...walls.map((side) =>
      [
        `[node name="${side === "west" ? "West" : "East"}" type="CollisionShape2D" parent="Bounds"]`,
        ...(side === "east" ? [`position = ${v(size.w, 0)}`] : []),
        `shape = SubResource("WorldBoundaryShape2D_${side}")`,
      ].join("\n"),
    ),
    `[node name="Exits" type="Node2D" parent="."]`,
    ...exits.flatMap((exit) => [
      [
        `[node name="${exit.name}" type="Area2D" parent="Exits"]`,
        `position = ${exit.position}`,
        "collision_layer = 128",
        "collision_mask = 2",
        `script = ExtResource("4_exit")`,
        `room_id = &"${exit.to}"`,
        `entry_id = &"${exit.entry}"`,
      ].join("\n"),
      `[node name="Edge" type="CollisionShape2D" parent="Exits/${exit.name}"]\nshape = SubResource("${exit.shape}")`,
    ]),
    `[node name="Entries" type="Node2D" parent="."]`,
    ...entries.map((entry) => `[node name="${entry.name}" type="Marker2D" parent="Entries"]\nposition = ${entry.position}`),
    `[node name="Player" parent="." instance=ExtResource("5_player")]${entries.length ? `\nposition = ${entries[0].position}` : ""}`,
  ];
  const scene = [
    `[gd_scene load_steps=${resources.length + shapes.length + 1} format=4]`,
    resources.join("\n"),
    ...shapes,
    ...nodes,
  ].join("\n\n") + "\n";

  const path = `scenes/rooms/${id}.tscn`;
  const next = structuredClone(world);
  const builtRoom = next.rooms[id];
  builtRoom.scene = `res://${path}`;
  delete builtRoom.plan;
  return { path, scene, world: next };
}
