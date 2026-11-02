// The World view: the World drawn as the Map draws it. As it is, it only shows; as planned, it
// edits the Plan: drag a Room to move it, drag out empty screens for a new Planned Room, click a
// Room's edge for an Exit, and set a Room's Region, note, size and marks beside it.

import { canvas, drawMarker, el, outline, rect, type Rect } from "./dom";
import { asPlanned, CELL, layoutWorld, type Side, type Vec, type WorldData } from "./world";
import { addPlannedRoom, moveRoom, removePlannedRoom, resizeRoom, setMarker, setNote, setRegion, toggleExit } from "./worldEdit";

const SCALE = 3;
// Empty screens round the planned World, to drag new Rooms out onto.
const PAD = 2;
const BACKDROP = "#0e0e16";
const CURRENT = "#52638c";
const WALL = "#94a5c6";
const PLANNED_WALL = "rgba(148, 165, 198, 0.55)";
const LINE = "rgba(148, 165, 198, 0.3)";
const GRID = "rgba(148, 165, 198, 0.07)";
const GHOST = "#ffff8b";
// How near a Room's edge, in Map pixels, a click toggles an Exit.
const EDGE_REACH = 5;

export type Tool = "select" | "room" | "exit";

export interface WorldEditor {
  world: WorldData;
  planned: boolean;
  selected: string | null;
  tool: Tool;
  region: string;
  drop: boolean;
  // Applies an edit, or says why it couldn't be made.
  apply(next: WorldData | null, refused: string, select?: string): void;
  select(id: string | null): void;
  set(changes: Partial<Pick<WorldEditor, "tool" | "region" | "drop">>): void;
  open(id: string): void;
}

const same = (a: Vec, b: Vec) => a[0] === b[0] && a[1] === b[1];

export function showWorld(editor: WorldEditor, stage: HTMLElement, side: HTMLElement) {
  const { world, planned } = editor;
  const editing = planned;
  const layout = layoutWorld(world, planned, editing ? PAD : 0);
  const [c, g] = canvas(layout.size.w, layout.size.h, SCALE);
  let ghost: Rect | null = null;

  const draw = () => {
    rect(g, { x: 0, y: 0, ...layout.size }, BACKDROP);
    if (editing) {
      for (let x = 4; x < layout.size.w; x += CELL.w) {
        rect(g, { x, y: 0, w: 1, h: layout.size.h }, GRID);
      }
      for (let y = 12; y < layout.size.h; y += CELL.h) {
        rect(g, { x: 0, y, w: layout.size.w, h: 1 }, GRID);
      }
    }
    for (const room of layout.rooms) {
      if (room.built) {
        rect(g, room.block, room.id === editor.selected ? CURRENT : room.colour);
      } else if (room.id === editor.selected) {
        rect(g, room.block, "rgba(82, 99, 140, 0.45)");
      }
      room.lines.forEach((line) => rect(g, line, LINE));
      room.walls.forEach((wall) => rect(g, wall, room.built ? WALL : PLANNED_WALL));
      room.markers.forEach((marker) => drawMarker(g, marker.kind, marker.x, marker.y));
    }
    g.fillStyle = "#c6d3e8";
    g.font = "6px monospace";
    layout.labels.forEach((label) => g.fillText(label.text.toUpperCase(), label.x, label.y));
    if (ghost) {
      outline(g, ghost, GHOST);
    }
  };

  const at = (event: PointerEvent | MouseEvent) => {
    const box = c.getBoundingClientRect();
    return { x: (event.clientX - box.left) / SCALE, y: (event.clientY - box.top) / SCALE };
  };
  const roomUnder = (x: number, y: number) =>
    layout.rooms.find((r) => x >= r.block.x && x < r.block.x + r.block.w && y >= r.block.y && y < r.block.y + r.block.h);

  // The Room edge nearest a point, if a click there means an Exit: its screen and side.
  const edgeAt = (x: number, y: number): { id: string; screen: Vec; side: Side } | null => {
    const room = roomUnder(x, y);
    if (!room) {
      return null;
    }
    const size = asPlanned(world.rooms[room.id]).size;
    const screen: Vec = [Math.floor((x - room.block.x) / CELL.w), Math.floor((y - room.block.y) / CELL.h)];
    const local = { x: x - room.block.x - screen[0] * CELL.w, y: y - room.block.y - screen[1] * CELL.h };
    const edges: [Side, number, boolean][] = [
      ["north", local.y, screen[1] === 0],
      ["south", CELL.h - local.y, screen[1] === size[1] - 1],
      ["west", local.x, screen[0] === 0],
      ["east", CELL.w - local.x, screen[0] === size[0] - 1],
    ];
    const near = edges.filter(([, distance, outer]) => outer && distance <= EDGE_REACH).sort((a, b) => a[1] - b[1]);
    return near.length ? { id: room.id, screen, side: near[0][0] } : null;
  };

  let drag: { kind: "move"; id: string; from: Vec } | { kind: "new"; from: Vec } | null = null;

  c.addEventListener("pointerdown", (event) => {
    const p = at(event);
    const screen = layout.screenAt(p.x, p.y);
    const room = roomUnder(p.x, p.y);
    if (!editing || editor.tool === "select") {
      editor.selected = room?.id ?? null;
      if (editing && room) {
        drag = { kind: "move", id: room.id, from: screen };
        c.setPointerCapture(event.pointerId);
      }
      draw();
      side.replaceChildren(...details(editor));
    } else if (editor.tool === "room" && !room) {
      drag = { kind: "new", from: screen };
      c.setPointerCapture(event.pointerId);
    } else if (editor.tool === "exit") {
      const edge = edgeAt(p.x, p.y);
      if (edge) {
        editor.apply(
          toggleExit(world, edge.id, edge.screen, edge.side, { drop: editor.drop && edge.side === "south" }),
          "",
          edge.id,
        );
      }
    }
  });

  c.addEventListener("pointermove", (event) => {
    if (!drag) {
      return;
    }
    const p = at(event);
    const screen = layout.screenAt(p.x, p.y);
    if (drag.kind === "move") {
      const room = asPlanned(world.rooms[drag.id]);
      const cell: Vec = [room.cell[0] + screen[0] - drag.from[0], room.cell[1] + screen[1] - drag.from[1]];
      ghost = layout.blockAt(cell, room.size);
    } else {
      const corner: Vec = [Math.min(drag.from[0], screen[0]), Math.min(drag.from[1], screen[1])];
      const size: Vec = [Math.abs(screen[0] - drag.from[0]) + 1, Math.abs(screen[1] - drag.from[1]) + 1];
      ghost = layout.blockAt(corner, size);
    }
    draw();
  });

  c.addEventListener("pointerup", (event) => {
    if (!drag) {
      return;
    }
    const p = at(event);
    const screen = layout.screenAt(p.x, p.y);
    const done = drag;
    drag = null;
    ghost = null;
    if (done.kind === "move") {
      if (same(screen, done.from)) {
        draw();
        return;
      }
      const room = asPlanned(world.rooms[done.id]);
      const cell: Vec = [room.cell[0] + screen[0] - done.from[0], room.cell[1] + screen[1] - done.from[1]];
      editor.apply(moveRoom(world, done.id, cell), "A Room can't move onto another Room.", done.id);
    } else {
      const corner: Vec = [Math.min(done.from[0], screen[0]), Math.min(done.from[1], screen[1])];
      const size: Vec = [Math.abs(screen[0] - done.from[0]) + 1, Math.abs(screen[1] - done.from[1]) + 1];
      const added = addPlannedRoom(world, editor.region, corner, size);
      editor.apply(added?.world ?? null, "A new Room can't cover another Room.", added?.id);
    }
  });

  c.addEventListener("dblclick", (event) => {
    const p = at(event);
    const room = roomUnder(p.x, p.y);
    if (room && world.rooms[room.id].scene) {
      editor.open(room.id);
    }
  });

  draw();
  const tools = editing ? toolbar(editor) : [];
  stage.replaceChildren(...tools, c);
  side.replaceChildren(...details(editor));
}

function toolbar(editor: WorldEditor): Node[] {
  const tool = (kind: Tool, label: string, hint: string) =>
    el("button", { type: "button", title: hint, ariaPressed: String(editor.tool === kind), onclick: () => editor.set({ tool: kind }) }, label);
  const regions = el(
    "select",
    { title: "The Region a new Room is in", onchange: (e: Event) => editor.set({ region: (e.target as HTMLSelectElement).value }) },
    ...Object.entries(editor.world.regions).map(([id, region]) => el("option", { value: id, selected: id === editor.region }, region.name)),
  );
  const drop = el("input", { type: "checkbox", checked: editor.drop, onchange: (e: Event) => editor.set({ drop: (e.target as HTMLInputElement).checked }) });
  const bits: Node[] = [
    tool("select", "Move", "Click a Room to see it; drag it to move it (a built Room moves only in the Plan)"),
    tool("room", "New Room", "Drag out empty screens for a new Planned Room"),
    tool("exit", "Exits", "Click a Room's edge to add or take away an Exit"),
  ];
  if (editor.tool === "room") {
    bits.push(el("label", {}, "in ", regions));
  }
  if (editor.tool === "exit") {
    bits.push(el("label", { title: "A south Exit falls into the Room below, with no way back up" }, drop, " South Exits are Drops"));
  }
  return [el("div", { className: "toolbar" }, ...bits)];
}

function details(editor: WorldEditor): Node[] {
  const { world, planned, selected: id } = editor;
  if (!id || !world.rooms[id]) {
    return [
      el("h2", {}, planned ? "The World as planned" : "The World as it is"),
      el(
        "p",
        { className: "muted" },
        planned
          ? "Drag a Room to move it, drag out empty screens with New Room, or click a Room's edge with Exits. Double-click a built Room to open it."
          : "Click a Room to see it; double-click a built Room to open it. Edit the Plan in As planned.",
      ),
    ];
  }
  const record = world.rooms[id];
  const room = planned ? asPlanned(record) : { ...record, exits: record.exits ?? [], markers: record.markers ?? {} };
  const built = record.scene !== undefined;
  const nodes: Node[] = [
    el("h2", {}, id),
    el("p", { className: "muted" }, built ? (record.plan ? "Built; the Plan moves it." : "Built.") : "Planned: not built yet."),
  ];
  const screens: Vec[] = [];
  for (let y = 0; y < room.size[1]; y++) {
    for (let x = 0; x < room.size[0]; x++) {
      screens.push([x, y]);
    }
  }
  const exits = room.exits.map((exit) => `${exit.side} of screen ${exit.screen.join(",")}`).join("; ") || "none";
  if (!planned) {
    if (record.note) {
      nodes.push(el("p", {}, record.note));
    }
    nodes.push(
      el(
        "dl",
        {},
        el("dt", {}, "Region"),
        el("dd", {}, world.regions[room.region]?.name ?? room.region),
        el("dt", {}, "Screen"),
        el("dd", {}, room.cell.join(", ")),
        el("dt", {}, "Size"),
        el("dd", {}, `${room.size[0]} × ${room.size[1]} screens`),
        el("dt", {}, "Exits"),
        el("dd", {}, exits),
      ),
    );
  } else {
    const note = el("textarea", { rows: 3, value: record.note ?? "", placeholder: "What this Room is for" });
    note.addEventListener("change", () => editor.apply(setNote(world, id, note.value), "", id));
    const region = el(
      "select",
      { onchange: (e: Event) => editor.apply(setRegion(world, id, (e.target as HTMLSelectElement).value), "", id) },
      ...Object.entries(world.regions).map(([key, r]) => el("option", { value: key, selected: key === room.region }, r.name)),
    );
    const sizeInput = (axis: 0 | 1) => {
      const input = el("input", { type: "number", min: 1, max: 12, value: String(room.size[axis]), disabled: built });
      input.addEventListener("change", () => {
        const size: Vec = [...room.size];
        size[axis] = Math.max(1, Number(input.value));
        editor.apply(resizeRoom(world, id, size), "A Room can't grow over another Room.", id);
      });
      return input;
    };
    const mark = (kind: string, label: string) => {
      const select = el(
        "select",
        {
          onchange: (e: Event) => {
            const value = (e.target as HTMLSelectElement).value;
            const screen = value ? (value.split(",").map(Number) as Vec) : null;
            editor.apply(setMarker(world, id, kind, screen), "", id);
          },
        },
        el("option", { value: "" }, "none"),
        ...screens.map((s) => el("option", { value: s.join(","), selected: room.markers[kind] && same(room.markers[kind], s) }, `screen ${s.join(",")}`)),
      );
      return [el("dt", {}, label), el("dd", {}, select)];
    };
    nodes.push(
      el("label", { className: "field" }, "Note", note),
      el(
        "dl",
        {},
        el("dt", {}, "Region"),
        el("dd", {}, region),
        el("dt", {}, "Screen"),
        el("dd", {}, room.cell.join(", ")),
        el("dt", {}, "Size"),
        el("dd", { className: "size" }, sizeInput(0), " × ", sizeInput(1)),
        ...mark("rest", "Rest point"),
        ...mark("boss", "Boss"),
        el("dt", {}, "Exits"),
        el("dd", {}, exits),
      ),
    );
    if (!built) {
      nodes.push(
        el("button", { type: "button", onclick: () => editor.apply(removePlannedRoom(world, id), "", undefined) }, "Remove this Planned Room"),
      );
    }
  }
  if (built) {
    nodes.push(el("button", { type: "button", onclick: () => editor.open(id) }, "Open Room"));
  }
  return nodes;
}
