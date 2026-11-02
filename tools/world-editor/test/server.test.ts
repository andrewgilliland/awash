import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { repoPath } from "../server/files";
import { parseTestOutput } from "../server/check";

const REPO = resolve(__dirname, "../../..");

describe("reading the repo's files", () => {
  it("finds a res:// path, or one from the repo's root, under the folders it may read", () => {
    expect(repoPath(REPO, "res://assets/world.json")).toBe(resolve(REPO, "assets/world.json"));
    expect(repoPath(REPO, "scenes/rooms/waking_coast_1.tscn")).toBe(
      resolve(REPO, "scenes/rooms/waking_coast_1.tscn"),
    );
  });

  it("reads nothing outside them", () => {
    expect(repoPath(REPO, "res://../secret.txt")).toBeNull();
    expect(repoPath(REPO, "/etc/passwd")).toBeNull();
    expect(repoPath(REPO, "assets/../../outside")).toBeNull();
    expect(repoPath(REPO, ".git/config")).toBeNull();
    expect(repoPath(REPO, "scripts/core/world.gd")).toBeNull();
  });
});

describe("the Check", () => {
  it("reads each test's result from the test run", () => {
    const output = [
      "PASS: Every Room in the World has a scene",
      "\u001b[1;31mERROR:\u001b[0;91m FAIL: The plan lays out every Room, built and planned, none overlapping",
      "\u001b[1;31mERROR:\u001b[0;91m waking_coast_9 and undertow_2 both plan (12, 2)",
      "\u001b[1;31mERROR:\u001b[0;91m 1 test(s) failed",
    ].join("\n");
    const check = parseTestOutput(output, 1);
    expect(check.passed).toBe(false);
    expect(check.tests).toEqual([
      { name: "Every Room in the World has a scene", passed: true },
      { name: "The plan lays out every Room, built and planned, none overlapping", passed: false },
    ]);
    expect(check.errors).toContain("waking_coast_9 and undertow_2 both plan (12, 2)");
  });

  it("passes when every test does", () => {
    const check = parseTestOutput("PASS: A\nPASS: B\nAll tests passed\n", 0);
    expect(check.passed).toBe(true);
    expect(check.tests.every((test) => test.passed)).toBe(true);
  });
});
