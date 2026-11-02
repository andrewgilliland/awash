// Edits to the World as planned. Each takes the World's data and returns new data, never changing
// what it was given. A Planned Room is edited in its own record; a built Room only in its plan,
// which folds away again when it comes back to what the Room is today. An edit that would put two
// Rooms on one screen returns null.

import { asPlanned, type Exit, type RoomPlan, type RoomRecord, type Side, type Vec, type WorldData } from "./world";

const STEP: Record<Side, Vec> = { north: [0, -1], east: [1, 0], south: [0, 1], west: [-1, 0] };
const OPPOSITE: Record<Side, Side> = { north: "south", south: "north", east: "west", west: "east" };

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
const sameExit = (a: Exit, b: Exit) => same(a.screen, b.screen) && a.side === b.side;

function screensOf(room: RoomRecord): Vec[] {
  const { cell, size } = asPlanned(room);
  const screens: Vec[] = [];
  for (let y = 0; y < size[1]; y++) {
    for (let x = 0; x < size[0]; x++) {
      screens.push([cell[0] + x, cell[1] + y]);
    }
  }
  return screens;
}

// The Room the Plan puts on a screen of the World, leaving out one Room if asked; null for none.
export function roomAt(world: WorldData, screen: Vec, except?: string): string | null {
  for (const [id, room] of Object.entries(world.rooms)) {
    if (id !== except && screensOf(room).some((at) => same(at, screen))) {
      return id;
    }
  }
  return null;
}

function fits(world: WorldData, cell: Vec, size: Vec, except?: string): boolean {
  for (let y = 0; y < size[1]; y++) {
    for (let x = 0; x < size[0]; x++) {
      if (roomAt(world, [cell[0] + x, cell[1] + y], except)) {
        return false;
      }
    }
  }
  return true;
}

// Writes planned fields: into a Planned Room's record, or a built Room's plan.
function writePlanned(world: WorldData, id: string, changes: RoomPlan): WorldData {
  const next = structuredClone(world);
  const room = next.rooms[id];
  if (room.scene === undefined) {
    Object.assign(room, changes);
    if (room.markers && Object.keys(room.markers).length === 0) {
      delete room.markers;
    }
    return next;
  }
  const today: RoomPlan = {
    cell: room.cell,
    size: room.size,
    region: room.region,
    exits: room.exits ?? [],
    markers: room.markers ?? {},
  };
  const plan: RoomPlan = { ...room.plan };
  for (const key of Object.keys(changes) as (keyof RoomPlan)[]) {
    if (same(changes[key], today[key])) {
      delete plan[key];
    } else {
      Object.assign(plan, { [key]: changes[key] });
    }
  }
  if (Object.keys(plan).length === 0) {
    delete room.plan;
  } else {
    room.plan = plan;
  }
  return next;
}

export function addPlannedRoom(
  world: WorldData,
  region: string,
  cell: Vec,
  size: Vec,
): { world: WorldData; id: string } | null {
  if (!fits(world, cell, size)) {
    return null;
  }
  const taken = Object.keys(world.rooms)
    .map((id) => new RegExp(`^${region}_(\\d+)$`).exec(id))
    .filter((match) => match !== null)
    .map((match) => Number(match[1]));
  const id = `${region}_${Math.max(0, ...taken) + 1}`;
  const next = structuredClone(world);
  next.rooms[id] = { cell, size, region, exits: [] };
  return { world: next, id };
}

export function moveRoom(world: WorldData, id: string, cell: Vec): WorldData | null {
  const room = world.rooms[id];
  return fits(world, cell, asPlanned(room).size, id) ? writePlanned(world, id, { cell }) : null;
}

// Only a Planned Room changes size: a built one's size is its scene's. Exits and marks on screens
// it no longer has go with them.
export function resizeRoom(world: WorldData, id: string, size: Vec): WorldData | null {
  const room = world.rooms[id];
  if (room.scene !== undefined || !fits(world, asPlanned(room).cell, size, id)) {
    return null;
  }
  const inside = (screen: Vec) => screen[0] < size[0] && screen[1] < size[1];
  const planned = asPlanned(room);
  const markers = Object.fromEntries(Object.entries(planned.markers).filter(([, at]) => inside(at)));
  return writePlanned(world, id, { size, exits: planned.exits.filter((exit) => inside(exit.screen)), markers });
}

// Only a Planned Room can be removed, and the Exits that led into it go with it.
export function removePlannedRoom(world: WorldData, id: string): WorldData | null {
  const room = world.rooms[id];
  if (!room || room.scene !== undefined) {
    return null;
  }
  const gone = screensOf(room);
  let next = structuredClone(world);
  delete next.rooms[id];
  for (const [other, record] of Object.entries(next.rooms)) {
    const planned = asPlanned(record);
    const kept = planned.exits.filter((exit) => {
      const beyond: Vec = [
        planned.cell[0] + exit.screen[0] + STEP[exit.side][0],
        planned.cell[1] + exit.screen[1] + STEP[exit.side][1],
      ];
      return !gone.some((at) => same(at, beyond));
    });
    if (kept.length !== planned.exits.length) {
      next = writePlanned(next, other, { exits: kept });
    }
  }
  return next;
}

// Adds an Exit, or takes it away, with the one back from the Room next door. A Drop down into the
// Room below has no way back up.
export function toggleExit(
  world: WorldData,
  id: string,
  screen: Vec,
  side: Side,
  options: { drop?: boolean } = {},
): WorldData {
  const planned = asPlanned(world.rooms[id]);
  const exit: Exit = { screen, side };
  const beyond: Vec = [planned.cell[0] + screen[0] + STEP[side][0], planned.cell[1] + screen[1] + STEP[side][1]];
  const other = roomAt(world, beyond, id);
  const has = planned.exits.some((known) => sameExit(known, exit));
  let next = writePlanned(world, id, {
    exits: has ? planned.exits.filter((known) => !sameExit(known, exit)) : [...planned.exits, exit],
  });
  if (other) {
    const there = asPlanned(next.rooms[other]);
    const back: Exit = { screen: [beyond[0] - there.cell[0], beyond[1] - there.cell[1]], side: OPPOSITE[side] };
    const backHas = there.exits.some((known) => sameExit(known, back));
    if (has && backHas) {
      next = writePlanned(next, other, { exits: there.exits.filter((known) => !sameExit(known, back)) });
    } else if (!has && !backHas && !(side === "south" && options.drop)) {
      next = writePlanned(next, other, { exits: [...there.exits, back] });
    }
  }
  return next;
}

export function setRegion(world: WorldData, id: string, region: string): WorldData {
  return writePlanned(world, id, { region });
}

// Marks a Rest point or a Boss on one of the Room's screens, or takes the mark away.
export function setMarker(world: WorldData, id: string, kind: string, screen: Vec | null): WorldData {
  const markers = { ...asPlanned(world.rooms[id]).markers };
  if (screen) {
    markers[kind] = screen;
  } else {
    delete markers[kind];
  }
  return writePlanned(world, id, { markers });
}

export function setNote(world: WorldData, id: string, note: string): WorldData {
  const next = structuredClone(world);
  if (note.trim()) {
    next.rooms[id].note = note.trim();
  } else {
    delete next.rooms[id].note;
  }
  return next;
}
