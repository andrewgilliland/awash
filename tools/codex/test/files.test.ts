import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { repoPath } from "../server/files";

const REPO = resolve(__dirname, "../../..");

describe("the art the page may load", () => {
  it("finds a file under assets, from the repo's root or as a res:// path", () => {
    expect(repoPath(REPO, "assets/items/bomb.png")).toBe(resolve(REPO, "assets/items/bomb.png"));
    expect(repoPath(REPO, "res://assets/items/bomb.png")).toBe(resolve(REPO, "assets/items/bomb.png"));
  });

  it("loads nothing outside it", () => {
    expect(repoPath(REPO, "scripts/core/world.gd")).toBeNull();
    expect(repoPath(REPO, "assets/../../outside")).toBeNull();
    expect(repoPath(REPO, "/etc/passwd")).toBeNull();
    expect(repoPath(REPO, ".git/config")).toBeNull();
  });
});
