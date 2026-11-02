// The World editor's page: the World view (as it is, or as planned), a read-only Room view, and the
// Check, which runs the game's tests.

import { parseRoomScene, parseTileSet, type RoomScene, type TileSet } from "./godot";
import { asPlanned, layoutWorld, SCREEN, type LaidRoom, type WorldData } from "./world";

const SCALE = 3;
const ROOM_SCALE = 2;
const BACKDROP = "#0e0e16";
const CURRENT = "#52638c";
const WALL = "#94a5c6";
const PLANNED_WALL = "rgba(148, 165, 198, 0.55)";
const LINE = "rgba(148, 165, 198, 0.3)";
const SKY = "#0cf1ff";
const EXIT_MARK = "#ffff8b";
const MARKERS: Record<string, { colour: string; rows: string[] }> = {
  rest: { colour: "#f2f2f2", rows: ["..#..", ".###.", ".###.", "#####", "..#.."] },
  boss: { colour: "#e8584c", rows: [".....", "#.#.#", "#####", "#####", "....."] },
};
// Godot's flips on an alternative tile.
const FLIP_H = 4096;
const FLIP_V = 8192;

type View = { kind: "world"; planned: boolean } | { kind: "room"; id: string };

const stage = document.querySelector<HTMLElement>("#stage")!;
const side = document.querySelector<HTMLElement>("#side")!;
const views = document.querySelector<HTMLElement>("#views")!;
const checkButton = document.querySelector<HTMLButtonElement>("#check")!;

let world: WorldData;
let view: View = { kind: "world", planned: false };
let selected: string | null = null;
const images = new Map<string, Promise<HTMLImageElement>>();
const tileSets = new Map<string, Promise<TileSet>>();

const repoUrl = (path: string) => `/repo/${path.replace(/^res:\/\//, "")}`;

async function text(path: string): Promise<string> {
  const response = await fetch(repoUrl(path));
  if (!response.ok) {
    throw new Error(`Could not read ${path}`);
  }
  return response.text();
}

function image(path: string): Promise<HTMLImageElement> {
  if (!images.has(path)) {
    images.set(
      path,
      new Promise((done, fail) => {
        const img = new Image();
        img.onload = () => done(img);
        img.onerror = () => fail(new Error(`Could not load ${path}`));
        img.src = repoUrl(path);
      }),
    );
  }
  return images.get(path)!;
}

function tileSet(path: string): Promise<TileSet> {
  if (!tileSets.has(path)) {
    tileSets.set(path, text(path).then(parseTileSet));
  }
  return tileSets.get(path)!;
}

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props: Record<string, unknown> = {},
  ...children: (Node | string)[]
): HTMLElementTagNameMap[K] {
  const node = Object.assign(document.createElement(tag), props);
  node.append(...children);
  return node;
}

function canvas(w: number, h: number, scale: number): [HTMLCanvasElement, CanvasRenderingContext2D] {
  const c = el("canvas", { width: w * scale, height: h * scale });
  const g = c.getContext("2d")!;
  g.imageSmoothingEnabled = false;
  g.scale(scale, scale);
  return [c, g];
}

function rect(g: CanvasRenderingContext2D, r: { x: number; y: number; w: number; h: number }, colour: string) {
  g.fillStyle = colour;
  g.fillRect(r.x, r.y, r.w, r.h);
}

function drawMarker(g: CanvasRenderingContext2D, kind: string, x: number, y: number) {
  const marker = MARKERS[kind];
  marker?.rows.forEach((row, dy) =>
    [...row].forEach((pixel, dx) => pixel === "#" && rect(g, { x: x + dx, y: y + dy, w: 1, h: 1 }, marker.colour)),
  );
}

// The World as the Map draws it: built Rooms filled with their Region's colour, Planned Rooms in
// outline, walls with a gap at each Exit, and each Region's name.
function showWorld(planned: boolean) {
  const layout = layoutWorld(world, planned);
  const [c, g] = canvas(layout.size.w, layout.size.h, SCALE);
  rect(g, { x: 0, y: 0, ...layout.size }, BACKDROP);
  for (const room of layout.rooms) {
    if (room.built) {
      rect(g, room.block, room.id === selected ? CURRENT : room.colour);
    }
    room.lines.forEach((line) => rect(g, line, LINE));
    room.walls.forEach((wall) => rect(g, wall, room.built ? WALL : PLANNED_WALL));
    room.markers.forEach((marker) => drawMarker(g, marker.kind, marker.x, marker.y));
  }
  g.fillStyle = "#c6d3e8";
  g.font = "6px monospace";
  layout.labels.forEach((label) => g.fillText(label.text.toUpperCase(), label.x, label.y));
  c.addEventListener("click", (event) => {
    const box = c.getBoundingClientRect();
    const x = (event.clientX - box.left) / SCALE;
    const y = (event.clientY - box.top) / SCALE;
    const hit = layout.rooms.find((r) => x >= r.block.x && x < r.block.x + r.block.w && y >= r.block.y && y < r.block.y + r.block.h);
    selected = hit?.id ?? null;
    render();
  });
  c.addEventListener("dblclick", () => {
    if (selected && world.rooms[selected]?.scene) {
      view = { kind: "room", id: selected };
      render();
    }
  });
  stage.replaceChildren(c);
  side.replaceChildren(...roomDetails(selected, layout.rooms, planned));
}

function roomDetails(id: string | null, laid: LaidRoom[], planned: boolean): Node[] {
  if (!id || !laid.some((room) => room.id === id)) {
    return [
      el("h2", {}, planned ? "The World as planned" : "The World as it is"),
      el("p", { className: "muted" }, "Click a Room to see it; double-click a built Room to open it."),
    ];
  }
  const record = world.rooms[id];
  const room = planned ? asPlanned(record) : { ...record, exits: record.exits ?? [], markers: record.markers ?? {} };
  const region = world.regions[room.region]?.name ?? room.region;
  const nodes: Node[] = [
    el("h2", {}, id),
    el("p", { className: "muted" }, record.scene ? (record.plan ? "Built; the Plan moves it." : "Built.") : "Planned: not built yet."),
  ];
  if (record.note) {
    nodes.push(el("p", {}, record.note));
  }
  const exits = room.exits.map((exit) => `${exit.side} of screen ${exit.screen.join(",")}`).join("; ") || "none";
  nodes.push(
    el(
      "dl",
      {},
      el("dt", {}, "Region"),
      el("dd", {}, region),
      el("dt", {}, "Screen"),
      el("dd", {}, room.cell.join(", ")),
      el("dt", {}, "Size"),
      el("dd", {}, `${room.size[0]} × ${room.size[1]} screens`),
      el("dt", {}, "Exits"),
      el("dd", {}, exits),
      el("dt", {}, "Marks"),
      el("dd", {}, Object.keys(room.markers).join(", ") || "none"),
    ),
  );
  if (record.scene) {
    nodes.push(el("button", { type: "button", onclick: () => ((view = { kind: "room", id }), render()) }, "Open Room"));
  }
  return nodes;
}

// A Room's tile layers drawn from the real sheets in the order the game draws them, on a flat sky,
// with its screens' edges and its Exits marked.
async function showRoom(id: string) {
  const record = world.rooms[id];
  stage.replaceChildren(el("p", { className: "muted" }, `Loading ${id}…`));
  const scene: RoomScene = parseRoomScene(await text(record.scene!));
  const size = { w: record.size[0] * SCREEN.w, h: record.size[1] * SCREEN.h };
  const hidden = new Set<string>();
  // Every tile set and sheet the Room draws from, loaded before the first draw.
  const sets = new Map<string, TileSet>();
  const sheets = new Map<string, HTMLImageElement>();
  for (const layer of scene.layers) {
    sets.set(layer.tileSet, await tileSet(layer.tileSet));
  }
  const textures = new Set(
    scene.layers.flatMap((layer) =>
      layer.cells.map((cell) => sets.get(layer.tileSet)!.sources.get(cell.source)?.texture ?? ""),
    ),
  );
  textures.delete("");
  await Promise.all([...textures].map(async (texture) => sheets.set(texture, await image(texture))));

  const draw = () => {
    const [c, g] = canvas(size.w, size.h, ROOM_SCALE);
    rect(g, { x: 0, y: 0, ...size }, SKY);
    for (const layer of scene.layers) {
      if (hidden.has(layer.name)) {
        continue;
      }
      const set = sets.get(layer.tileSet)!;
      const [tw, th] = set.tileSize;
      g.globalAlpha = layer.opacity;
      for (const cell of layer.cells) {
        const sheet = sheets.get(set.sources.get(cell.source)?.texture ?? "");
        if (!sheet) {
          continue;
        }
        const x = cell.x * tw + layer.position[0];
        const y = cell.y * th + layer.position[1];
        g.save();
        g.translate(x + tw / 2, y + th / 2);
        g.scale(cell.alternative & FLIP_H ? -1 : 1, cell.alternative & FLIP_V ? -1 : 1);
        g.drawImage(sheet, cell.atlas[0] * tw, cell.atlas[1] * th, tw, th, -tw / 2, -th / 2, tw, th);
        g.restore();
      }
      g.globalAlpha = 1;
    }
    for (let x = 1; x < record.size[0]; x++) {
      rect(g, { x: x * SCREEN.w, y: 0, w: 1, h: size.h }, "rgba(0, 0, 0, 0.35)");
    }
    for (let y = 1; y < record.size[1]; y++) {
      rect(g, { x: 0, y: y * SCREEN.h, w: size.w, h: 1 }, "rgba(0, 0, 0, 0.35)");
    }
    for (const exit of record.exits ?? []) {
      const sx = exit.screen[0] * SCREEN.w;
      const sy = exit.screen[1] * SCREEN.h;
      const mark = {
        north: { x: sx + SCREEN.w / 2 - 12, y: 0, w: 24, h: 3 },
        south: { x: sx + SCREEN.w / 2 - 12, y: size.h - 3, w: 24, h: 3 },
        west: { x: 0, y: sy + SCREEN.h / 2 - 12, w: 3, h: 24 },
        east: { x: size.w - 3, y: sy + SCREEN.h / 2 - 12, w: 3, h: 24 },
      }[exit.side];
      rect(g, mark, EXIT_MARK);
    }
    stage.replaceChildren(c);
  };

  side.replaceChildren(
    el("h2", {}, id),
    el("p", { className: "muted" }, `${record.size[0]} × ${record.size[1]} screens · ${record.scene}`),
    el("p", {}, "Layers, in the order the game draws them:"),
    ...scene.layers.map((layer) => {
      const box = el("input", { type: "checkbox", checked: true });
      box.addEventListener("change", () => {
        if (box.checked) {
          hidden.delete(layer.name);
        } else {
          hidden.add(layer.name);
        }
        draw();
      });
      return el("label", { className: "layer" }, box, ` ${layer.name} (${layer.cells.length} tiles)`);
    }),
    el("p", { className: "muted" }, "Yellow marks are Exits; dark lines are screen edges."),
    el("button", { type: "button", onclick: () => ((view = { kind: "world", planned: false }), render()) }, "Back to the World"),
  );
  draw();
}

function render() {
  views.replaceChildren(
    ...[false, true].map((planned) =>
      el(
        "button",
        {
          type: "button",
          ariaPressed: String(view.kind === "world" && view.planned === planned),
          onclick: () => ((view = { kind: "world", planned }), render()),
        },
        planned ? "As planned" : "As it is",
      ),
    ),
  );
  if (view.kind === "world") {
    showWorld(view.planned);
  } else {
    void showRoom(view.id).catch((error: Error) => stage.replaceChildren(el("p", {}, error.message)));
  }
}

checkButton.addEventListener("click", async () => {
  checkButton.disabled = true;
  checkButton.textContent = "Checking…";
  side.replaceChildren(el("h2", {}, "Check"), el("p", { className: "muted" }, "Running the game's tests…"));
  try {
    const response = await fetch("/api/check", { method: "POST" });
    const result: { passed: boolean; tests: { name: string; passed: boolean }[]; errors: string[] } = await response.json();
    const failed = result.tests.filter((test) => !test.passed);
    side.replaceChildren(
      el("h2", {}, result.passed ? `All ${result.tests.length} tests pass` : `${failed.length} of ${result.tests.length} tests fail`),
      el(
        "ul",
        { className: "results" },
        ...[...failed, ...result.tests.filter((test) => test.passed)].map((test) =>
          el("li", { className: test.passed ? "pass" : "fail" }, `${test.passed ? "✓" : "✗"} ${test.name}`),
        ),
      ),
      ...(result.errors.length ? [el("h2", {}, "What failed said"), el("ul", { className: "results" }, ...result.errors.map((e) => el("li", { className: "fail" }, e)))] : []),
    );
  } finally {
    checkButton.disabled = false;
    checkButton.textContent = "Check";
  }
});

void text("assets/world.json").then((body) => {
  world = JSON.parse(body);
  render();
});

