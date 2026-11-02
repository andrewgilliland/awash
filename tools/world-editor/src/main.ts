// The World editor's page: the World view (as it is, or as planned, where the Plan is edited), the
// read-only Room view, saving the World's data, and the Check, which runs the game's tests.

import { el, readRepo } from "./dom";
import { showRoom } from "./roomView";
import type { WorldData } from "./world";
import { serializeWorld } from "./worldFile";
import { showWorld, type Tool, type WorldEditor } from "./worldView";

const WORLD_PATH = "assets/world.json";

type View = { kind: "world"; planned: boolean } | { kind: "room"; id: string };

const stage = document.querySelector<HTMLElement>("#stage")!;
const side = document.querySelector<HTMLElement>("#side")!;
const views = document.querySelector<HTMLElement>("#views")!;
const actions = document.querySelector<HTMLElement>("#actions")!;
const status = document.querySelector<HTMLElement>("#status")!;
const checkButton = document.querySelector<HTMLButtonElement>("#check")!;

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
  actions.replaceChildren(
    el("button", { type: "button", disabled: undone.length === 0, title: "Undo (⌘Z)", onclick: undo }, "Undo"),
    el("button", { type: "button", disabled: redone.length === 0, title: "Redo (⇧⌘Z)", onclick: redo }, "Redo"),
    el("button", { type: "button", disabled: !dirty(), title: "Save the World's data (⌘S)", onclick: save }, dirty() ? "Save ●" : "Saved"),
  );
  if (view.kind === "room") {
    void showRoom(world, view.id, stage, side, () => ((view = { kind: "world", planned: false }), render())).catch(
      (error: Error) => stage.replaceChildren(el("p", {}, error.message)),
    );
    return;
  }
  const editor: WorldEditor = {
    world,
    planned: view.planned,
    selected,
    tool,
    region,
    drop,
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
      render();
    },
    open(id) {
      view = { kind: "room", id };
      render();
    },
  };
  // the World view keeps its own selection as you click, and hands it back here
  Object.defineProperty(editor, "selected", { get: () => selected, set: (id: string | null) => (selected = id) });
  showWorld(editor, stage, side);
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
  if (world && dirty()) {
    event.preventDefault();
  }
});

checkButton.addEventListener("click", async () => {
  checkButton.disabled = true;
  checkButton.textContent = "Checking…";
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
    checkButton.disabled = false;
    checkButton.textContent = "Check";
  }
});

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
