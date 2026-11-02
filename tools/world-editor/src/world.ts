// The World's data as assets/world.json holds it, and its layout as the Map draws it: the same
// sizes, Exit gaps and Region names as scripts/ui/map_layout.gd.

export type Vec = [number, number];
export type Side = "north" | "east" | "south" | "west";

export interface Exit {
  screen: Vec;
  side: Side;
}

export interface RoomPlan {
  cell?: Vec;
  size?: Vec;
  region?: string;
  exits?: Exit[];
  markers?: Record<string, Vec>;
}

export interface RoomRecord extends RoomPlan {
  note?: string;
  scene?: string;
  cell: Vec;
  size: Vec;
  region: string;
  background?: string;
  plan?: RoomPlan;
}

export interface RegionRecord {
  note?: string;
  name: string;
  colour: string;
  // The ground a new Room's starter floor is painted with: a source and atlas tile in its terrain.
  floor?: [number, number, number];
  theme?: string;
  background?: string;
  backgrounds?: Record<string, string>;
}

export interface WorldData {
  regions: Record<string, RegionRecord>;
  rooms: Record<string, RoomRecord>;
}

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface LaidRoom {
  id: string;
  block: Rect;
  colour: string;
  // Built Rooms are filled; Planned Rooms are drawn in outline.
  built: boolean;
  walls: Rect[];
  lines: Rect[];
  markers: (Rect & { kind: string })[];
}

export interface WorldLayout {
  rooms: LaidRoom[];
  labels: { text: string; x: number; y: number }[];
  size: { w: number; h: number };
  // The screen of the World a point in the picture is on, and where screens sit in the picture.
  screenAt: (x: number, y: number) => Vec;
  blockAt: (cell: Vec, size: Vec) => Rect;
}

// One screen on the Map, keeping the screen's shape.
export const CELL = { w: 20, h: 18 };
export const SCREEN = { w: 160, h: 144 };
const EXIT_GAP = 6;
const MARKER = 5;
// Room around the picture, with space above for the Regions' names.
const MARGIN = { x: 4, y: 12 };
const LABEL_RISE = 3;
const STEP: Record<Side, Vec> = { north: [0, -1], east: [1, 0], south: [0, 1], west: [-1, 0] };

// A Room as the World's plan lays it out: what it is today, with any plan laid over it.
export function asPlanned(room: RoomRecord): Required<Pick<RoomRecord, "cell" | "size" | "region" | "exits" | "markers">> {
  return {
    cell: room.plan?.cell ?? room.cell,
    size: room.plan?.size ?? room.size,
    region: room.plan?.region ?? room.region,
    exits: room.plan?.exits ?? room.exits ?? [],
    markers: room.plan?.markers ?? room.markers ?? {},
  };
}

// Lays out the whole World: as it is, every built Room where it sits; or as planned, every Room,
// built and planned, where the World's plan puts it. Pad leaves that many empty screens round it.
// Given a Region, only the Rooms in it, as it is or as planned.
export function layoutWorld(world: WorldData, planned: boolean, pad = 0, region?: string): WorldLayout {
  const shown = Object.entries(world.rooms)
    .filter(([, room]) => planned || room.scene !== undefined)
    .map(([id, room]) => {
      const laid = planned
        ? asPlanned(room)
        : { cell: room.cell, size: room.size, region: room.region, exits: room.exits ?? [], markers: room.markers ?? {} };
      return { id, built: room.scene !== undefined, ...laid };
    })
    .filter((room) => region === undefined || room.region === region);
  const cells = shown.length ? shown : [{ cell: [0, 0] as Vec, size: [1, 1] as Vec }];
  const corner = [Math.min(...cells.map((r) => r.cell[0])) - pad, Math.min(...cells.map((r) => r.cell[1])) - pad];
  const far = [
    Math.max(...cells.map((r) => r.cell[0] + r.size[0])) + pad,
    Math.max(...cells.map((r) => r.cell[1] + r.size[1])) + pad,
  ];
  const offset = { x: MARGIN.x - corner[0] * CELL.w, y: MARGIN.y - corner[1] * CELL.h };
  const nameAt = new Map<string, { x: number; y: number }>();
  const rooms = shown.map((room) => {
    const block = {
      x: offset.x + room.cell[0] * CELL.w,
      y: offset.y + room.cell[1] * CELL.h,
      w: room.size[0] * CELL.w,
      h: room.size[1] * CELL.h,
    };
    const name = world.regions[room.region]?.name ?? room.region;
    const held = nameAt.get(name);
    if (!held || block.y < held.y || (block.y === held.y && block.x < held.x)) {
      nameAt.set(name, { x: block.x, y: block.y });
    }
    return {
      id: room.id,
      block,
      colour: world.regions[room.region]?.colour ?? "#000000",
      built: room.built,
      walls: walls(room.size, room.exits, block),
      lines: lines(room.size, block),
      markers: Object.entries(room.markers).map(([kind, at]) => {
        const screen = screenRect(block, at);
        return {
          kind,
          x: Math.floor(screen.x + screen.w / 2 - MARKER / 2),
          y: Math.floor(screen.y + screen.h / 2 - MARKER / 2),
          w: MARKER,
          h: MARKER,
        };
      }),
    };
  });
  const labels = [...nameAt].map(([text, at]) => ({ text, x: at.x, y: at.y - LABEL_RISE }));
  const size = { w: (far[0] - corner[0]) * CELL.w + MARGIN.x * 2, h: (far[1] - corner[1]) * CELL.h + MARGIN.y * 2 };
  const screenAt = (x: number, y: number): Vec => [
    corner[0] + Math.floor((x - MARGIN.x) / CELL.w),
    corner[1] + Math.floor((y - MARGIN.y) / CELL.h),
  ];
  const blockAt = (cell: Vec, size: Vec): Rect => ({
    x: offset.x + cell[0] * CELL.w,
    y: offset.y + cell[1] * CELL.h,
    w: size[0] * CELL.w,
    h: size[1] * CELL.h,
  });
  return { rooms, labels, size, screenAt, blockAt };
}

function screenRect(block: Rect, screen: Vec): Rect {
  return { x: block.x + screen[0] * CELL.w, y: block.y + screen[1] * CELL.h, w: CELL.w, h: CELL.h };
}

// One pixel round the Room's edge, screen by screen, open in the middle where an Exit leaves.
function walls(size: Vec, exits: Exit[], block: Rect): Rect[] {
  const open = new Set(exits.map((exit) => `${exit.screen[0]},${exit.screen[1]},${exit.side}`));
  const found: Rect[] = [];
  for (let y = 0; y < size[1]; y++) {
    for (let x = 0; x < size[0]; x++) {
      for (const side of Object.keys(STEP) as Side[]) {
        const [bx, by] = [x + STEP[side][0], y + STEP[side][1]];
        if (bx >= 0 && by >= 0 && bx < size[0] && by < size[1]) {
          continue;
        }
        const edge = edgeOf(screenRect(block, [x, y]), side);
        found.push(...(open.has(`${x},${y},${side}`) ? opened(edge, side) : [edge]));
      }
    }
  }
  return found;
}

function edgeOf(screen: Rect, side: Side): Rect {
  switch (side) {
    case "north":
      return { x: screen.x, y: screen.y, w: screen.w, h: 1 };
    case "south":
      return { x: screen.x, y: screen.y + screen.h - 1, w: screen.w, h: 1 };
    case "west":
      return { x: screen.x, y: screen.y, w: 1, h: screen.h };
    case "east":
      return { x: screen.x + screen.w - 1, y: screen.y, w: 1, h: screen.h };
  }
}

// The edge in two, with the Exit's gap in its middle.
function opened(edge: Rect, side: Side): Rect[] {
  if (side === "north" || side === "south") {
    const start = Math.floor((edge.w - EXIT_GAP) / 2);
    return [
      { ...edge, w: start },
      { ...edge, x: edge.x + start + EXIT_GAP, w: edge.w - start - EXIT_GAP },
    ];
  }
  const start = Math.floor((edge.h - EXIT_GAP) / 2);
  return [
    { ...edge, h: start },
    { ...edge, y: edge.y + start + EXIT_GAP, h: edge.h - start - EXIT_GAP },
  ];
}

// Where one of the Room's screens meets the next, inside its walls.
function lines(size: Vec, block: Rect): Rect[] {
  const found: Rect[] = [];
  for (let x = 1; x < size[0]; x++) {
    found.push({ x: block.x + x * CELL.w, y: block.y + 1, w: 1, h: block.h - 2 });
  }
  for (let y = 1; y < size[1]; y++) {
    found.push({ x: block.x + 1, y: block.y + y * CELL.h, w: block.w - 2, h: 1 });
  }
  return found;
}
