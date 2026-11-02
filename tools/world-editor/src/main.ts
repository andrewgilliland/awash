// The World editor's page: the World view (as it is, or as planned, where the Plan is edited), the
// read-only Room view, saving the World's data, and the Check, which runs the game's tests.

import "@fontsource/jetbrains-mono/400.css";
import "@fontsource/jetbrains-mono/700.css";
import { el, readRepo, versionOf, type View } from "./dom";
import { buildRoom } from "./build";
import { showRoom } from "./roomView";
import { showSidebar } from "./sidebar";
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
let tool: Tool = "select";
let region = "";
let drop = false;
// Built Rooms' tiles shown in their cells on the map: remembered in this browser, if it can.
let pictures = readPictures();
// Unsaved paint on the open Room.
let roomDirty = false;
// Whether the Check is running the game's tests.
let checking = false;
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

function drawSidebar() {
  showSidebar(sidebar, {
    world,
    view,
    checking,
    show: (next) => ((view = next), render()),
    check: () => void check(),
    hover: (id) => worldView?.highlight(id),
  });
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
  if (view.kind === "room") {
    worldView = null;
    void showRoom(
      world,
      view.id,
      stage,
      side,
      () => ((view = { kind: "world", planned: false }), render()),
      (unsaved) => (roomDirty = unsaved),
    ).catch((error: Error) => stage.replaceChildren(el("p", {}, error.message)));
    return;
  }
  const editor: WorldEditor = {
    world,
    planned: view.planned,
    selected,
    tool,
    region,
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
      say("");
      render();
    },
    select(id) {
      selected = id;
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
      view = { kind: "room", id };
      render();
    },
    build(id) {
      void build(id);
    },
  };
  // the World view keeps its own selection as you click, and hands it back here
  Object.defineProperty(editor, "selected", { get: () => selected, set: (id: string | null) => (selected = id) });
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
    const found = await fetch(`/repo/assets/regions/${region}/tiles/${sheet}.tres`, { method: "HEAD" });
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

// Runs the game's tests, the one home of the World's rules, and lists their results beside the view.
async function check() {
  checking = true;
  render();
  side.replaceChildren(
    el("h2", {}, "Check"),
    el("p", { className: "muted" }, dirty() ? "Running the game's tests on the saved World (save first to check your edits)…" : "Running the game's tests…"),
  );
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
      ...(result.errors.length
        ? [el("h2", {}, "What failed said"), el("ul", { className: "results" }, ...result.errors.map((e) => el("li", { className: "fail" }, e)))]
        : []),
    );
  } finally {
    checking = false;
    drawSidebar();
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
  render();
});
