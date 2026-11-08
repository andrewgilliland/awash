import { TRADER_SCENE } from "./people.ts";
import type { Room, World } from "./repo.ts";
import type { Character, Enemy, Item, MapRoom, Mark, Region } from "./types.ts";

// --- The World map -------------------------------------------------------------------------------

// Every Room in the World, built or planned, with where it sits and what it holds.
export function readMapRooms(
  world: World,
  rooms: Room[],
  allCaches: Region["caches"],
  items: Item[],
  characters: Character[],
  enemies: Enemy[],
): MapRoom[] {
  return Object.entries(world.rooms).map(([id, room]) => {
    const built = rooms.find((entry) => entry.id === id);
    const marks: Mark[] = [];
    for (const cache of allCaches.filter((entry) => entry.room === id)) {
      const name = items.find((item) => item.id === cache.kind)?.name ?? cache.kind;
      marks.push({ kind: "cache", id: cache.kind, label: `Cache ${cache.id}: ${name}` });
    }
    if (built?.markers.includes("rest")) {
      marks.push({ kind: "rest", id: "", label: "Rest point" });
    }
    if (built?.scene.nodes.some((node) => node.instance === TRADER_SCENE)) {
      marks.push({ kind: "shop", id: "", label: "Supply Shop" });
    }
    for (const character of characters.filter((entry) => entry.rooms.includes(id))) {
      marks.push({ kind: "character", id: character.id, label: character.name });
    }
    for (const enemy of enemies) {
      const here = enemy.rooms.find((entry) => entry.id === id);
      if (here) {
        const count = here.count > 1 ? ` ×${here.count}` : "";
        marks.push({ kind: enemy.boss ? "boss" : "enemy", id: enemy.id, label: `${enemy.name}${count}` });
      }
    }
    return {
      id,
      region: room.region,
      cell: room.cell,
      size: room.size,
      planned: !built,
      exits: room.exits ?? [],
      marks,
    };
  });
}
