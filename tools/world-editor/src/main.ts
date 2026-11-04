// The World editor's page: the World view (as it is, or as planned, where the Plan is edited), the
// Room view, saving the World's data, and the Check, which runs the game's tests. Where you are is
// the address (see router.ts), so Back, Forward, Refresh and links all work.

import "@fontsource/jetbrains-mono/400.css";
import "@fontsource/jetbrains-mono/700.css";
import { el, readRepo, versionOf, type View } from "./dom";
import { buildRoom, tileFolder } from "./build";
import { showRoom } from "./roomView";
import { formatRoute, parseRoute, type Route } from "./router";
import { showSidebar } from "./sidebar";
import { showTests, type CheckRun } from "./testsView";
import type { WorldData } from "./world";
import { serializeWorld } from "./worldFile";
import { showWorld, type Tool, type WorldEditor, type WorldViewHandle } from "./worldView";

const WORLD_PATH = "assets/world.json";
const PICTURES_KEY = "world-editor:pictures";

function readPictures(): boolean {
  try {
    return localStorage.getItem(PICTURES_KEY) === "true";
  } catch {
    return false;
  }
}

const stage = document.querySelector<HTMLElement>("#stage")!;
const side = document.querySelector<HTMLElement>("#side")!;
const sidebar = document.querySelector<HTMLElement>("#sidebar")!;
const actions = document.querySelector<HTMLElement>("#actions")!;
const status = document.querySelector<HTMLElement>("#status")!;

let world: WorldData;
// The version of world.json the edits stand on, so a save can tell if it changed on disk since.
let version = "";
let saved = "";
const undone: WorldData[] = [];
const redone: WorldData[] = [];
let view: View = { kind: "world", planned: false };
let selected: string | null = null;
// An address that leads nowhere, shown as such until you go somewhere else.
let unknown: string | null = null;
let tool: Tool = "select";
let region = "";
let drop = false;
// Built Rooms' tiles shown in their cells on the map: remembered in this browser, if it can.
let pictures = readPictures();
// Unsaved paint on the open Room.
let roomDirty = false;
// Whether the Check is running the game's tests, and what it found last.
let checking = false;
let lastRun: CheckRun | null = null;
// The World view on show, if it is, for the sidebar to light Rooms on.
let worldView: WorldViewHandle | null = null;

const dirty = () => serializeWorld(world) !== saved;

function say(message: string, tone: "" | "fail" | "pass" = "") {
  status.textContent = message;
  status.className = tone;
}

function edit(next: WorldData) {
  undone.push(world);
  redone.length = 0;
  world = next;
}

// The address for where you are.
function here(): string {
  return formatRoute({ view, selected: view.kind === "world" ? selected : null });
}

// Records a change that isn't a move, such as a Room selected on the map, without adding history.
function replaceAddress() {
  if (location.pathname + location.search !== here()) {
    history.replaceState(null, "", here());
  }
}

// Leaving a Room with unsaved paint asks first; true if it's fine to go.
function mayLeave(next: View | null): boolean {
  const staying = next?.kind === "room" && view.kind === "room" && next.id === view.id;
  if (view.kind !== "room" || !roomDirty || staying) {
    return true;
  }
  if (!confirm("Leave without saving the paint on this Room?")) {
    return false;
  }
  roomDirty = false;
  return true;
}

// Goes somewhere: a new history entry, so Back returns here. False if you chose to stay.
function go(next: View, select: string | null = null): boolean {
  if (!mayLeave(next)) {
    return false;
  }
  view = next;
  selected = select;
  unknown = null;
  if (location.pathname + location.search !== here()) {
    history.pushState(null, "", here());
  }
  render();
  return true;
}

function follow(route: Route) {
  if ("unknown" in route) {
    unknown = route.unknown;
  } else {
    unknown = null;
    view = route.view;
    selected = route.selected && world.rooms[route.selected] ? route.selected : null;
  }
  render();
}

addEventListener("popstate", () => {
  if (!mayLeave(null)) {
    // stay, and put the address back
    history.pushState(null, "", here());
    return;
  }
  follow(parseRoute(location.pathname, location.search));
});

function drawSidebar() {
  showSidebar(sidebar, {
    world,
    view,
    checking,
    show: (next) => go(next),
    // to the tests, and runs them
    check: () => {
      if (go({ kind: "tests" })) {
        void check();
      }
    },
    hover: (id) => worldView?.highlight(id),
  });
}

// A page saying an address leads nowhere, with ways back.
function nowhere(title: string, why: string, ...ways: [string, View, string | null][]) {
  worldView = null;
  stage.replaceChildren(
    el("h2", {}, title),
    el("p", { className: "muted" }, why),
    el(
      "div",
      { className: "toolbar" },
      ...ways.map(([label, to, select]) => el("button", { type: "button", onclick: () => go(to, select) }, label)),
    ),
  );
  side.replaceChildren(el("h2", {}, "Nowhere"), el("p", { className: "muted" }, "Pick where to go in the sidebar."));
}

function render() {
  actions.replaceChildren(
    el("button", { type: "button", disabled: undone.length === 0, title: "Undo (⌘Z)", onclick: undo }, "Undo"),
    el("button", { type: "button", disabled: redone.length === 0, title: "Redo (⇧⌘Z)", onclick: redo }, "Redo"),
    el(
      "button",
      { type: "button", className: dirty() ? "primary" : "", disabled: !dirty(), title: "Save the World's data (⌘S)", onclick: save },
      dirty() ? "Save ●" : "Saved",
    ),
  );
  drawSidebar();
  const world_: View = { kind: "world", planned: false };
  const plan: View = { kind: "world", planned: true };
  if (unknown !== null) {
    nowhere("Nothing here", `There's nothing at ${unknown}.`, ["The World", world_, null], ["The Plan", plan, null]);
    return;
  }
  if (view.kind === "tests") {
    worldView = null;
    if (!lastRun && !checking) {
      // landed here with nothing to show: run them
      void check();
      return;
    }
    showTests(stage, side, { run: lastRun, checking, unsaved: dirty(), check: () => void check() });
    return;
  }
  if (view.kind === "room") {
    const id = view.id;
    const record = world.rooms[id];
    if (!record) {
      nowhere("No such Room", `The World has no Room called ${id}.`, ["The World", world_, null], ["The Plan", plan, null]);
      return;
    }
    if (record.scene === undefined) {
      nowhere("Not built yet", `${id} is a Planned Room: it has no scene to paint until it's built.`, ["See it in The Plan", plan, id]);
      return;
    }
    worldView = null;
    void showRoom(
      world,
      id,
      stage,
      side,
      () => go({ kind: "world", planned: false }, id),
      (unsaved) => (roomDirty = unsaved),
    ).catch((error: Error) => stage.replaceChildren(el("p", {}, error.message)));
    return;
  }
  if (view.region !== undefined && !world.regions[view.region]) {
    nowhere("No such Region", `The World has no Region called ${view.region}.`, ["The World", world_, null], ["The Plan", plan, null]);
    return;
  }
  const focus = view.region;
  const editor: WorldEditor = {
    world,
    planned: view.planned,
    focus,
    selected,
    tool,
    // a new Room is in the Region on show, if one is
    region: focus ?? region,
    drop,
    pictures,
    apply(next, refused, select) {
      if (!next) {
        say(refused, "fail");
        render();
        return;
      }
      edit(next);
      selected = select && next.rooms[select] ? select : null;
      replaceAddress();
      say("");
      render();
    },
    select(id) {
      selected = id;
      replaceAddress();
      render();
    },
    set(changes) {
      ({ tool = tool, region = region, drop = drop } = changes);
      if (changes.pictures !== undefined) {
        pictures = changes.pictures;
        try {
          localStorage.setItem(PICTURES_KEY, String(pictures));
        } catch {
          // a browser that keeps nothing just forgets the toggle
        }
      }
      render();
    },
    open(id) {
      go({ kind: "room", id });
    },
    build(id) {
      void build(id);
    },
  };
  // the World view keeps its own selection as you click, and hands it back here
  Object.defineProperty(editor, "selected", {
    get: () => selected,
    set: (id: string | null) => {
      selected = id;
      replaceAddress();
    },
  });
  worldView = showWorld(editor, stage, side);
}

function undo() {
  const last = undone.pop();
  if (last) {
    redone.push(world);
    world = last;
    render();
  }
}

function redo() {
  const next = redone.pop();
  if (next) {
    undone.push(world);
    world = next;
    render();
  }
}

// Writes a file the editor owns over the version it stands on; null if it was written.
async function write(path: string, base: string, text: string): Promise<{ version?: string; reason?: string }> {
  const response = await fetch("/api/save", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path, base, text }),
  });
  return response.json();
}

// Builds a Planned Room: its scene first, written only where no file is yet, then the World with the
// Room given that scene, along with any edits not yet saved.
async function build(id: string) {
  const result = buildRoom(world, id);
  if ("error" in result) {
    say(result.error, "fail");
    return;
  }
  const region = world.rooms[id].region;
  for (const sheet of ["terrain", "scenery"]) {
    const found = await fetch(`/repo/assets/regions/${tileFolder(world, region)}/tiles/${sheet}.tres`, { method: "HEAD" });
    if (!found.ok) {
      say(`${world.regions[region]?.name ?? region} has no tile sheets yet, so its Rooms can't be built.`, "fail");
      return;
    }
  }
  const edits = dirty() ? " It also saves your other edits to the World." : "";
  if (!confirm(`Build ${id}? This writes ${result.path} and puts the Room in the game.${edits}`)) {
    return;
  }
  const scene = await write(result.path, await versionOf(""), result.scene);
  if (!scene.version) {
    say(scene.reason === "changed" ? `There's a file at ${result.path} already, so nothing was built.` : `${result.path} can't be written.`, "fail");
    return;
  }
  const text = serializeWorld(result.world);
  const saved_ = await write(WORLD_PATH, version, text);
  if (!saved_.version) {
    say(`Wrote ${result.path}, but ${WORLD_PATH} changed on disk since it was loaded, so the World doesn't name it yet. Reload, then give ${id} its scene.`, "fail");
    return;
  }
  edit(result.world);
  version = saved_.version;
  saved = text;
  selected = id;
  replaceAddress();
  say(`Built ${id} at ${result.path}. Open it to paint; the Check shows what its neighbours still need.`, "pass");
  render();
}

async function save() {
  const text = serializeWorld(world);
  const response = await fetch("/api/save", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path: WORLD_PATH, base: version, text }),
  });
  const result: { saved: boolean; version?: string; reason?: string } = await response.json();
  if (result.saved) {
    version = result.version!;
    saved = text;
    say(`Saved ${WORLD_PATH}.`, "pass");
  } else if (result.reason === "changed") {
    say(`${WORLD_PATH} changed on disk since it was loaded, so nothing was saved. Reload to get it (your edits here would be lost).`, "fail");
  } else {
    say(`${WORLD_PATH} can't be written.`, "fail");
  }
  render();
}

addEventListener("keydown", (event) => {
  if (!(event.metaKey || event.ctrlKey) || (event.target as Element).closest("input, textarea, select")) {
    return;
  }
  if (event.key === "z") {
    event.preventDefault();
    if (event.shiftKey) {
      redo();
    } else {
      undo();
    }
  } else if (event.key === "s") {
    event.preventDefault();
    if (dirty()) {
      void save();
    }
  }
});

addEventListener("beforeunload", (event) => {
  if ((world && dirty()) || roomDirty) {
    event.preventDefault();
  }
});

// Runs the game's tests, the one home of the World's rules; the tests view shows what they found.
async function check() {
  if (checking) {
    return;
  }
  checking = true;
  render();
  try {
    const response = await fetch("/api/check", { method: "POST" });
    const result: Omit<CheckRun, "at"> = await response.json();
    lastRun = { ...result, at: new Date() };
  } catch {
    say("The tests couldn't be run.", "fail");
  } finally {
    checking = false;
    render();
  }
}

void readRepo(WORLD_PATH).then((file) => {
  world = JSON.parse(file.text);
  version = file.version;
  saved = file.text;
  region = Object.keys(world.regions)[0] ?? "";
  if (serializeWorld(world) !== file.text) {
    say(`${WORLD_PATH} isn't laid out as the editor writes it; saving will lay it out again.`);
  }
  const route = parseRoute(location.pathname, location.search);
  follow(route);
  if (!("unknown" in route)) {
    // "/" and other spellings settle on the address for where they lead
    replaceAddress();
  }
});
