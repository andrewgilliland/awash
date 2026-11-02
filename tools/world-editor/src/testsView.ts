// The tests view: every one of the game's tests from the last Check, failures first, with what the
// failing ones said, filtered to all, failing or passing. The tests are the one home of the World's
// rules, so this is where the editor shows what the rules make of the World.

import { el } from "./dom";

export interface CheckRun {
  passed: boolean;
  tests: { name: string; passed: boolean }[];
  errors: string[];
  at: Date;
}

export interface TestsState {
  run: CheckRun | null;
  checking: boolean;
  // Whether the World has edits not yet saved, which a Check can't see.
  unsaved: boolean;
  check: () => void;
}

type Filter = "all" | "failing" | "passing";
let filter: Filter = "all";

// A name and its value, joined by a dashed leader.
function info(name: string, value: string): HTMLElement[] {
  return [el("dt", {}, name), el("dd", {}, value)];
}

export function showTests(stage: HTMLElement, side: HTMLElement, state: TestsState) {
  const { run, checking } = state;
  const draw = () => {
    const shown = (run?.tests ?? []).filter(
      (test) => filter === "all" || (filter === "failing" ? !test.passed : test.passed),
    );
    const ordered = [...shown.filter((test) => !test.passed), ...shown.filter((test) => test.passed)];
    const failed = run ? run.tests.filter((test) => !test.passed).length : 0;
    const filters = (["all", "failing", "passing"] as Filter[]).map((kind) =>
      el(
        "button",
        { type: "button", ariaPressed: String(filter === kind), onclick: () => ((filter = kind), draw()) },
        kind === "all" ? "All" : kind === "failing" ? `Failing (${failed})` : `Passing (${(run?.tests.length ?? 0) - failed})`,
      ),
    );
    const summary = checking
      ? "Running the game's tests…"
      : !run
        ? "Not run yet"
        : run.passed
          ? `All ${run.tests.length} tests pass`
          : `${failed} of ${run.tests.length} tests fail`;
    stage.replaceChildren(
      el(
        "div",
        { className: "toolbar" },
        el("button", { type: "button", className: "primary", disabled: checking, onclick: state.check }, checking ? "Running…" : "Run the tests"),
        ...(run ? filters : []),
      ),
      el(
        "div",
        { className: "tests-box" },
        el("h2", {}, summary),
        ...(state.unsaved ? [el("p", { className: "muted" }, "The World has unsaved edits; the tests see only what's saved.")] : []),
        // Passing tests provoke errors on purpose too, so the run's errors are shown only when
        // something failed.
        ...(run && !run.passed && run.errors.length && filter !== "passing"
          ? [el("p", { className: "label" }, "What the run reported"), el("ul", { className: "results" }, ...run.errors.map((e) => el("li", { className: "fail" }, e)))]
          : []),
        ...(run
          ? [
              el("p", { className: "label" }, filter === "all" ? "Every test" : filter === "failing" ? "Failing" : "Passing"),
              el(
                "ul",
                { className: `results${checking ? " stale" : ""}` },
                ...ordered.map((test) => el("li", { className: test.passed ? "pass" : "fail" }, `${test.passed ? "✓" : "✗"} ${test.name}`)),
              ),
            ]
          : []),
      ),
    );
  };
  draw();
  side.replaceChildren(
    el("h2", {}, "Tests"),
    el("p", { className: "muted" }, "The game's own tests: the one home of the World's rules. Run them after saving."),
    ...(run
      ? [
          el(
            "dl",
            {},
            ...info("Passing", String(run.tests.filter((test) => test.passed).length)),
            ...info("Failing", String(run.tests.filter((test) => !test.passed).length)),
            ...info("Last run", run.at.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })),
          ),
        ]
      : []),
  );
}
