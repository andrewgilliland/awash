import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { saveFile, versionOf } from "../server/save";

function repoWithWorld(text: string): string {
  const repo = mkdtempSync(join(tmpdir(), "world-editor-"));
  mkdirSync(join(repo, "assets"));
  writeFileSync(join(repo, "assets/world.json"), text);
  return repo;
}

describe("saving", () => {
  it("writes the World's data over the version it was loaded from", async () => {
    const repo = repoWithWorld("old\n");
    const result = await saveFile(repo, "assets/world.json", versionOf("old\n"), "new\n");
    expect(result).toEqual({ saved: true, version: versionOf("new\n") });
    expect(readFileSync(join(repo, "assets/world.json"), "utf8")).toBe("new\n");
  });

  it("refuses when the file changed on disk since it was loaded", async () => {
    const repo = repoWithWorld("changed by someone else\n");
    const result = await saveFile(repo, "assets/world.json", versionOf("old\n"), "new\n");
    expect(result).toEqual({ saved: false, reason: "changed" });
    expect(readFileSync(join(repo, "assets/world.json"), "utf8")).toBe("changed by someone else\n");
  });

  it("writes a Room's scene over the version it was loaded from", async () => {
    const repo = repoWithWorld("old\n");
    mkdirSync(join(repo, "scenes/rooms"), { recursive: true });
    writeFileSync(join(repo, "scenes/rooms/waking_coast_1.tscn"), "scene\n");
    const path = "scenes/rooms/waking_coast_1.tscn";
    expect((await saveFile(repo, path, versionOf("scene\n"), "painted\n")).saved).toBe(true);
    expect(readFileSync(join(repo, path), "utf8")).toBe("painted\n");
    expect(await saveFile(repo, path, versionOf("scene\n"), "again\n")).toEqual({ saved: false, reason: "changed" });
  });

  it("writes nothing but the files it owns", async () => {
    const repo = repoWithWorld("old\n");
    for (const path of ["scenes/ui/pause_menu.tscn", "scenes/rooms/../ui/pause_menu.tscn", "scenes/rooms/x.tres", "scripts/core/world.gd", "../escape.json", "assets/other.json"]) {
      expect(await saveFile(repo, path, versionOf(""), "x")).toEqual({ saved: false, reason: "not writable" });
    }
  });
});
