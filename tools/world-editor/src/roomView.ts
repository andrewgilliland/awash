// A Room's tiles: its layers drawn from the real sheets in the order the game draws them, painted
// one layer at a time from that layer's own tile set, and saved back into the Room's scene.

import { parseRoomScene, setLayerCells, type Cell, type RoomScene, type TileLayer, type Vec } from "./godot";
import { el, canvas, image, outline, readRepo, rect } from "./dom";
import { blockStamp, eraseRect, fillRect, pickStamp, stampAt, type Area, type Stamp } from "./paint";
import { drawTiles, forgetBackdrop, forgetPicture, loadBackdrop, loadRoomArt } from "./roomPicture";
import { layerBounds, layerCell, layerOrigin, roomsSharing, screenOf, type BackgroundLayer } from "./background";
import { collisionOf, layerStack, peeled, type Collision } from "./layers";
import { SCREEN, type WorldData } from "./world";

const ROOM_SCALE = 2;
const PALETTE_SCALE = 2;
const EXIT_MARK = "#ffff8b";
const AIM = "#ff3df2";
const PICKED = "#ffff8b";
// How a tile collides, when Collisions is on: solid tiles filled, one-way tiles barred along the top.
const SOLID = "rgba(255, 70, 70, 0.45)";
const ONE_WAY = "rgba(255, 190, 40, 0.95)";
type Tool = "paint" | "fill" | "erase" | "pick";
const TOOLS: [Tool, string, string][] = [
  ["paint", "Paint", "Click or drag to paint the picked tiles"],
  ["fill", "Fill", "Drag out an area to fill with the picked tiles"],
  ["erase", "Erase", "Drag out an area to clear on this layer"],
  ["pick", "Eyedrop", "Drag over tiles on this layer to pick them up"],
];

// Shows a Room for painting. It says whether it has unsaved paint through dirty, and only leaves
// for the World through back once you have saved or chosen to drop the paint.
export async function showRoom(
  world: WorldData,
  id: string,
  stage: HTMLElement,
  side: HTMLElement,
  back: () => void,
  dirty: (unsaved: boolean) => void,
) {
  const record = world.rooms[id];
  const path = record.scene!;
  stage.replaceChildren(el("p", { className: "muted" }, `Loading ${id}…`));
  const file = await readRepo(path);
  let text = file.text;
  let version = file.version;
  const scene: RoomScene = parseRoomScene(text);
  const bounds = {
    w: (record.size[0] * SCREEN.w) / 16,
    h: (record.size[1] * SCREEN.h) / 16,
  };
  const size = { w: record.size[0] * SCREEN.w, h: record.size[1] * SCREEN.h };
  const hidden = new Set<string>();
  const art = await loadRoomArt(scene);
  const { sets, sheets } = art;
  // The Region's Background, behind the Room as the camera frames each of its screens: a copy to
  // paint, so paint not saved never reaches other Rooms' pictures. Its tile sets and sheets join
  // the Room's.
  const loaded = await loadBackdrop(world, id);
  const backdrop = loaded && { ...loaded, background: structuredClone(loaded.background), art: { sets, sheets } };
  for (const [path, set] of loaded?.art.sets ?? []) {
    sets.set(path, set);
  }
  for (const [texture, sheet] of loaded?.art.sheets ?? []) {
    sheets.set(texture, sheet);
  }
  let backdropText = backdrop?.text ?? "";
  let backdropVersion = backdrop?.version ?? "";
  const isBackground = (key: string) => key.startsWith("Background/");
  // A Background tile layer by its key: the layer it is in, and its tiles.
  const backgroundTiles = (key: string): { layer: BackgroundLayer; tiles: TileLayer } => {
    for (const layer of backdrop?.background.layers ?? []) {
      for (const tiles of layer.tiles) {
        if (`Background/${tiles.name}` === key) {
          return { layer, tiles };
        }
      }
    }
    throw new Error(`No Background layer ${key}`);
  };
  // Every layer, front to back; picking one peels away those in front, shown faintly. Peel and
  // Restore step deeper and back one layer at a time.
  const stack = layerStack(scene, backdrop?.background ?? null, sets);
  let peelTo = "";
  let collisions = false;
  // The palette loads more of a layer's sheets as you pick them.
  const loadSheet = async (texture: string) => {
    if (!sheets.has(texture)) {
      sheets.set(texture, await image(texture));
    }
    return sheets.get(texture)!;
  };

  // What painting changes: each layer's cells, the layers changed since the last save, and undo.
  let active = scene.layers.find((layer) => layer.name === "Terrain")?.name ?? scene.layers[0]?.name ?? "";
  const changed = new Set<string>();
  const undone: { layer: string; cells: Cell[] }[] = [];
  const redone: { layer: string; cells: Cell[] }[] = [];
  let tool: Tool = "paint";
  let stamp: Stamp | null = null;
  let source = -1;
  let status = "";

  const layerOf = (name: string) =>
    isBackground(name) ? backgroundTiles(name).tiles : scene.layers.find((layer) => layer.name === name)!;
  // The cells the picked layer may hold: the Room's, or a Background layer's own.
  const boundsOf = (name: string) => (isBackground(name) ? layerBounds(backgroundTiles(name).layer) : bounds);
  const setOf = (name: string) => sets.get(layerOf(name).tileSet)!;
  // The tiles a layer may be painted with: on Terrain only those that collide or are one-way.
  const paintable = (name: string, src: number) => {
    const tiles = setOf(name).sources.get(src)?.tiles ?? new Map();
    const terrain = name === "Terrain";
    return new Set([...tiles].filter(([, tile]) => !terrain || tile.collides || tile.oneWay).map(([coords]) => coords));
  };
  const sourcesOf = (name: string) =>
    [...setOf(name).sources].filter(([src]) => paintable(name, src).size > 0).map(([src, s]) => ({ src, texture: s.texture }));

  // A paint stroke is one change to undo, however many cells it crosses.
  let stroke: Cell[] | null = null;
  const change = (cells: Cell[]) => {
    const layer = layerOf(active);
    if (JSON.stringify(cells) === JSON.stringify(layer.cells)) {
      return;
    }
    if (!stroke) {
      undone.push({ layer: active, cells: layer.cells });
      redone.length = 0;
    }
    layer.cells = cells;
    changed.add(active);
    dirty(true);
  };

  const [roomCanvas, g] = canvas(size.w, size.h, ROOM_SCALE);
  let aim: Area | null = null;

  const draw = () => {
    drawTiles(g, scene, art, size, { hidden, faded: peeled(stack, peelTo || active) }, backdrop);
    if (collisions) {
      for (const layer of scene.layers) {
        if (!hidden.has(layer.name)) {
          for (const cell of layer.cells) {
            markCollision(g, collisionOf(sets.get(layer.tileSet)!, cell), cell.x * 16 + layer.position[0], cell.y * 16 + layer.position[1]);
          }
        }
      }
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
    if (aim) {
      // On a Background layer, the aim is in the layer's cells: drawn where they land on the screen
      // the pointer is on, as the copy of its repeat nearest the pointer.
      let at: Vec = [0, 0];
      if (isBackground(active) && backdrop) {
        const { layer, tiles } = backgroundTiles(active);
        const origin = layerOrigin(layer, backdrop.roomOrigin, screenOf(lastPoint));
        at = [origin[0] + tiles.position[0], origin[1] + tiles.position[1]];
        const repeat = layer.repeat[0];
        if (repeat > 0) {
          at[0] += Math.floor((lastPoint[0] - at[0]) / repeat) * repeat;
        }
      }
      outline(g, { x: at[0] + aim.x * 16, y: at[1] + aim.y * 16, w: aim.w * 16, h: aim.h * 16 }, AIM);
    }
  };

  // The point in the Room under the pointer, and the screen it was last on, for the aim.
  let lastPoint: Vec = [0, 0];
  const cellAt = (event: PointerEvent): Vec => {
    const box = roomCanvas.getBoundingClientRect();
    lastPoint = [(event.clientX - box.left) / ROOM_SCALE, (event.clientY - box.top) / ROOM_SCALE];
    if (isBackground(active) && backdrop) {
      const { layer, tiles } = backgroundTiles(active);
      return layerCell(layer, tiles, backdrop.roomOrigin, lastPoint);
    }
    return [Math.floor(lastPoint[0] / 16), Math.floor(lastPoint[1] / 16)];
  };
  const areaBetween = (a: Vec, b: Vec): Area => ({
    x: Math.min(a[0], b[0]),
    y: Math.min(a[1], b[1]),
    w: Math.abs(a[0] - b[0]) + 1,
    h: Math.abs(a[1] - b[1]) + 1,
  });
  const stampArea = (at: Vec): Area => ({ x: at[0], y: at[1], w: stamp?.tiles[0].length ?? 1, h: stamp?.tiles.length ?? 1 });

  let from: Vec | null = null;
  roomCanvas.addEventListener("pointerdown", (event) => {
    const at = cellAt(event);
    from = at;
    roomCanvas.setPointerCapture(event.pointerId);
    if (tool === "paint") {
      if (!stamp) {
        say("Pick tiles in the palette first.");
        from = null;
        return;
      }
      stroke = layerOf(active).cells;
      undone.push({ layer: active, cells: stroke });
      redone.length = 0;
      change(stampAt(layerOf(active).cells, at, stamp, boundsOf(active)));
    }
    aim = tool === "paint" ? stampArea(at) : areaBetween(at, at);
    draw();
  });
  roomCanvas.addEventListener("pointermove", (event) => {
    const at = cellAt(event);
    if (from && tool === "paint" && stamp) {
      change(stampAt(layerOf(active).cells, at, stamp, boundsOf(active)));
    }
    aim = from && tool !== "paint" ? areaBetween(from, at) : stampArea(at);
    draw();
  });
  roomCanvas.addEventListener("pointerup", (event) => {
    if (!from) {
      return;
    }
    const area = areaBetween(from, cellAt(event));
    from = null;
    if (stroke && stroke === layerOf(active).cells) {
      undone.pop();
    }
    stroke = null;
    if (tool === "fill") {
      if (stamp) {
        change(fillRect(layerOf(active).cells, area, stamp, boundsOf(active)));
      } else {
        say("Pick tiles in the palette first.");
      }
    } else if (tool === "erase") {
      change(eraseRect(layerOf(active).cells, area));
    } else if (tool === "pick") {
      const picked = pickStamp(layerOf(active).cells, area);
      if (picked) {
        stamp = picked;
        source = picked.source;
        tool = "paint";
      } else {
        say(`Nothing to pick there on ${active}, or tiles from more than one sheet.`);
      }
    }
    render();
  });
  roomCanvas.addEventListener("pointerleave", () => {
    if (!from) {
      aim = null;
      draw();
    }
  });

  const stackIndex = (key: string) => stack.findIndex((entry) => entry.key === key);
  // How deep the peel goes: the layer it stops at, at least the one being painted.
  const depth = () => Math.max(stackIndex(peelTo || active), stackIndex(active));
  const step = (by: number) => {
    const to = Math.min(Math.max(depth() + by, stackIndex(active)), stack.length - 1);
    peelTo = to === stackIndex(active) ? "" : stack[to].key;
    render();
  };

  function say(message: string) {
    status = message;
    render();
  }

  const undo = () => {
    const last = undone.pop();
    if (last) {
      redone.push({ layer: last.layer, cells: layerOf(last.layer).cells });
      layerOf(last.layer).cells = last.cells;
      changed.add(last.layer);
      render();
    }
  };
  const redo = () => {
    const next = redone.pop();
    if (next) {
      undone.push({ layer: next.layer, cells: layerOf(next.layer).cells });
      layerOf(next.layer).cells = next.cells;
      changed.add(next.layer);
      render();
    }
  };

  // What the Room's scene and the Background's would be with the paint written in.
  const written = () => {
    let room = text;
    let back = backdropText;
    for (const name of changed) {
      if (isBackground(name)) {
        back = setLayerCells(back, backgroundTiles(name).tiles.name, layerOf(name).cells);
      } else {
        room = setLayerCells(room, name, layerOf(name).cells);
      }
    }
    return { room, back };
  };

  const write = async (file: string, base: string, contents: string) => {
    const response = await fetch("/api/save", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: file.replace(/^res:\/\//, ""), base, text: contents }),
    });
    return (await response.json()) as { saved: boolean; version?: string; reason?: string };
  };

  const save = async () => {
    const { room, back } = written();
    const saved: string[] = [];
    if (room !== text) {
      const result = await write(path, version, room);
      if (!result.saved) {
        return say(refusal(result.reason, "Room's scene"));
      }
      text = room;
      version = result.version!;
      forgetPicture(id);
      saved.push(path.replace(/^res:\/\//, ""));
    }
    if (backdrop && back !== backdropText) {
      const result = await write(backdrop.path, backdropVersion, back);
      if (!result.saved) {
        return say(refusal(result.reason, "Background's scene"));
      }
      backdropText = back;
      backdropVersion = result.version!;
      forgetBackdrop(backdrop.path);
      const shared = roomsSharing(world, backdrop.path).length;
      saved.push(`the Background, shared by ${shared} Room${shared === 1 ? "" : "s"}`);
    }
    changed.clear();
    dirty(false);
    say(`Saved ${saved.join(" and ")}.`);
  };

  const unsaved = () => {
    const { room, back } = written();
    return room !== text || back !== backdropText;
  };

  const palette = async (): Promise<Node[]> => {
    const sources = sourcesOf(active);
    if (!sources.some((s) => s.src === source)) {
      source = sources[0]?.src ?? -1;
    }
    const chooser = el(
      "select",
      {
        onchange: (e: Event) => {
          source = Number((e.target as HTMLSelectElement).value);
          stamp = null;
          render();
        },
      },
      ...sources.map((s) => el("option", { value: String(s.src), selected: s.src === source }, s.texture.split("/").slice(-2).join("/"))),
    );
    if (source < 0) {
      return [el("p", { className: "muted" }, `${active} has nothing to paint with.`)];
    }
    const texture = setOf(active).sources.get(source)!.texture;
    const sheet = await loadSheet(texture);
    const has = paintable(active, source);
    const [pc, pg] = canvas(sheet.width, sheet.height, PALETTE_SCALE);
    pc.className = "palette";
    const drawPalette = (dragged?: Area) => {
      rect(pg, { x: 0, y: 0, w: sheet.width, h: sheet.height }, "#2a2d40");
      pg.drawImage(sheet, 0, 0);
      for (let y = 0; y < sheet.height / 16; y++) {
        for (let x = 0; x < sheet.width / 16; x++) {
          if (!has.has(`${x},${y}`)) {
            rect(pg, { x: x * 16, y: y * 16, w: 16, h: 16 }, "rgba(14, 14, 22, 0.75)");
          }
        }
      }
      if (collisions) {
        for (const coords of has) {
          const [x, y] = coords.split(",").map(Number);
          markCollision(pg, collisionOf(setOf(active), { x, y, source, atlas: [x, y], alternative: 0 }), x * 16, y * 16);
        }
      }
      const shown = dragged ?? (stamp && stamp.source === source ? pickedArea(stamp) : null);
      if (shown) {
        outline(pg, { x: shown.x * 16, y: shown.y * 16, w: shown.w * 16, h: shown.h * 16 }, PICKED);
      }
    };
    let start: Vec | null = null;
    const tileAt = (event: PointerEvent): Vec => {
      const box = pc.getBoundingClientRect();
      return [Math.floor((event.clientX - box.left) / PALETTE_SCALE / 16), Math.floor((event.clientY - box.top) / PALETTE_SCALE / 16)];
    };
    pc.addEventListener("pointerdown", (event) => {
      start = tileAt(event);
      pc.setPointerCapture(event.pointerId);
      drawPalette(areaBetween(start, start));
    });
    pc.addEventListener("pointermove", (event) => start && drawPalette(areaBetween(start, tileAt(event))));
    pc.addEventListener("pointerup", (event) => {
      if (!start) {
        return;
      }
      const picked = blockStamp(source, start, tileAt(event), has);
      start = null;
      if (picked.tiles.flat().some((tile) => tile)) {
        stamp = picked;
        if (tool === "erase" || tool === "pick") {
          tool = "paint";
        }
        status = "";
      }
      render();
    });
    drawPalette();
    return [el("label", { className: "field" }, "Sheet", chooser), el("div", { className: "palette-box" }, pc)];
  };

  async function render() {
    const tools = el(
      "div",
      { className: "toolbar" },
      ...TOOLS.map(([kind, label, hint]) =>
        el("button", { type: "button", title: hint, ariaPressed: String(tool === kind), onclick: () => ((tool = kind), render()) }, label),
      ),
      el("button", { type: "button", disabled: undone.length === 0, title: "Undo paint", onclick: undo }, "Undo"),
      el("button", { type: "button", disabled: redone.length === 0, title: "Redo paint", onclick: redo }, "Redo"),
      el("button", { type: "button", disabled: !unsaved(), title: "Save the Room's scene, and its Background's if painted", onclick: save }, unsaved() ? "Save Room ●" : "Room saved"),
      el("button", { type: "button", disabled: depth() >= stack.length - 1, title: "Peel away one more layer, from the front", onclick: () => step(1) }, "Peel"),
      el("button", { type: "button", disabled: depth() <= stackIndex(active), title: "Put the last layer peeled back", onclick: () => step(-1) }, "Restore"),
      el(
        "button",
        { type: "button", ariaPressed: String(collisions), title: "Show which tiles are solid (filled) and one-way (barred)", onclick: () => ((collisions = !collisions), render()) },
        "Collisions",
      ),
      el("span", { className: "muted" }, status),
    );
    draw();
    stage.replaceChildren(tools, el("div", { className: "room-box" }, roomCanvas));
    const shared = backdrop ? roomsSharing(world, backdrop.path).length : 0;
    let headed = false;
    const layers = stack.flatMap((entry) => {
      const shown = el("input", { type: "checkbox", checked: !hidden.has(entry.key), title: "Show this layer" });
      shown.addEventListener("change", () => {
        if (shown.checked) {
          hidden.delete(entry.key);
        } else {
          hidden.add(entry.key);
        }
        draw();
      });
      const pick = el("input", {
        type: "radio",
        name: "layer",
        checked: entry.key === active,
        disabled: !entry.paintable,
        title: entry.paintable ? "Paint this layer, peeling away those in front" : "A plain colour: not painted with tiles",
      });
      pick.addEventListener("change", () => {
        active = entry.key;
        peelTo = "";
        stamp = null;
        render();
      });
      const cells = entry.paintable ? ` (${layerOf(entry.key).cells.length})` : "";
      const row = el(
        "div",
        { className: `layer${peeled(stack, peelTo || active).has(entry.key) ? " peeled" : ""}` },
        pick,
        shown,
        ` ${entry.key.replace(/^Background\//, "")}${entry.paintable ? cells : " fill"}${changed.has(entry.key) ? " ●" : ""}`,
        ...(entry.collides ? [el("span", { className: "badge", title: "Its tiles collide: solid or one-way" }, "collides")] : []),
      );
      if (entry.background && !headed) {
        headed = true;
        return [
          el("p", { className: "label" }, `Background · shared by the ${shared} Room${shared === 1 ? "" : "s"} that show it`),
          row,
        ];
      }
      return [row];
    });
    side.replaceChildren(
      el("h2", {}, id),
      el("p", { className: "muted" }, `${record.size[0]} × ${record.size[1]} screens · ${path}`),
      el("p", {}, "Layers front to back. Paint the one picked: those in front of it are peeled away, shown faintly. Tick to show."),
      ...layers,
      ...(await palette()),
      el(
        "button",
        {
          type: "button",
          onclick: () => {
            if (!unsaved() || confirm("Leave without saving the paint on this Room?")) {
              dirty(false);
              back();
            }
          },
        },
        "Back to the World",
      ),
    );
  }

  await render();
}

function pickedArea(stamp: Stamp): Area | null {
  for (let y = 0; y < stamp.tiles.length; y++) {
    for (let x = 0; x < stamp.tiles[y].length; x++) {
      const tile = stamp.tiles[y][x];
      if (tile) {
        return { x: tile[0] - x, y: tile[1] - y, w: stamp.tiles[0].length, h: stamp.tiles.length };
      }
    }
  }
  return null;
}

function markCollision(g: CanvasRenderingContext2D, collision: Collision, x: number, y: number) {
  if (collision === "solid") {
    rect(g, { x, y, w: 16, h: 16 }, SOLID);
  } else if (collision === "one-way") {
    rect(g, { x, y, w: 16, h: 3 }, ONE_WAY);
  }
}

function refusal(reason: string | undefined, what: string): string {
  return reason === "changed"
    ? `The ${what} changed on disk since it was opened (was it saved in Godot?), so nothing more was saved. Reopen the Room to get it.`
    : `The ${what} can't be written.`;
}
