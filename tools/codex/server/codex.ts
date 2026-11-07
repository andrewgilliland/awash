import { readEnemies } from "./enemies.ts";
import { caches, readItems } from "./items.ts";
import { readCharacters, readRegions } from "./people.ts";
import { Files, readRooms, type World } from "./repo.ts";
import type { Codex } from "./types.ts";

// The Codex: the game's enemies, items, characters and Regions, read afresh from its own files
// every time: the GDScripts' consts, the scenes, the World's data and the docs' frontmatter. It
// holds no numbers of its own, so it never drifts from the game.

export type * from "./types.ts";

export async function buildCodex(repo: string): Promise<Codex> {
  const files = new Files(repo);
  const world = JSON.parse(await files.text("assets/world.json")) as World;
  const rooms = await readRooms(files, world);
  const allCaches = await caches(files, rooms);
  const enemies = await readEnemies(files, rooms);
  const items = await readItems(files, allCaches, enemies);
  const characters = await readCharacters(files, rooms);
  const regions = readRegions(world, rooms, allCaches);
  return { enemies, items, characters, regions };
}
