import { basename } from "node:path";
import { readConsts } from "./gdscript.ts";
import { readScene } from "./tscn.ts";
import { field, local, preloadPath, readDocs, titled, type Files, type Room, type World } from "./repo.ts";
import type { Character, Region } from "./types.ts";

const TRADER_SCENE = "res://scenes/npcs/trader.tscn";

// --- Characters ----------------------------------------------------------------------------------

export async function readCharacters(files: Files, rooms: Room[]): Promise<Character[]> {
  const people = await peopleInRooms(files, rooms);
  const characters: Character[] = [];
  const player = readConsts(await files.text("scripts/player/player_rig.gd"));
  for (const doc of await readDocs(files, "docs/characters")) {
    if (field(doc.data, "type") !== "character") {
      continue;
    }
    const name = field(doc.data, "name");
    const first = name.split(" ")[0].toLowerCase();
    const person = people.find((entry) => [name.toLowerCase(), first].includes(entry.name.toLowerCase()));
    const details: Record<string, string> = {};
    for (const key of Object.keys(doc.data)) {
      const value = field(doc.data, key);
      // Links to other docs are left out.
      if (!["name", "type", "working_name"].includes(key) && value && !value.endsWith(".md")) {
        details[key] = field(doc.data, key);
      }
    }
    const protagonist = field(doc.data, "role") === "protagonist";
    if (person) {
      people.splice(people.indexOf(person), 1);
    }
    characters.push({
      id: basename(doc.path, ".md").replaceAll("-", "_"),
      name,
      planned: !person && !protagonist,
      sprite: person?.sprite ?? (protagonist ? preloadPath(player.BODY_SHEET) : null),
      rooms: person?.rooms ?? [],
      lines: person?.lines ?? [],
      details,
    });
  }
  for (const person of people) {
    characters.push({ ...person, planned: false, details: {} });
  }
  return characters.sort((a, b) => a.name.localeCompare(b.name));
}

interface Person {
  id: string;
  name: string;
  sprite: string | null;
  rooms: string[];
  lines: string[];
}

// Everyone standing in the Rooms: each instance of a scene under scenes/npcs, by the name they
// speak as, with their sheet and lines, from the Room or from their own scene and script.
async function peopleInRooms(files: Files, rooms: Room[]): Promise<Person[]> {
  const people: Person[] = [];
  for (const room of rooms) {
    for (const node of room.scene.nodes) {
      if (!node.instance?.startsWith("res://scenes/npcs/")) {
        continue;
      }
      const own = readScene(await files.text(node.instance)).nodes.find((entry) => entry.parent === "");
      const props = { ...(own?.properties ?? {}), ...node.properties };
      const script = typeof props.script === "string" ? readConsts(await files.text(props.script)) : {};
      const speaker = typeof props.speaker === "string" && props.speaker ? props.speaker : node.name;
      const name = titled(speaker);
      const sheet = typeof props.sheet === "string" ? local(props.sheet) : preloadPath(script.SHEET);
      const lines = Array.isArray(props.lines) ? props.lines.filter((line): line is string => typeof line === "string") : [];
      const known = people.find((person) => person.name === name);
      if (known) {
        known.rooms.push(room.id);
        continue;
      }
      people.push({ id: name.toLowerCase().replace(/[^a-z0-9]+/g, "_"), name, sprite: sheet, rooms: [room.id], lines });
    }
  }
  return people;
}

// --- Regions -------------------------------------------------------------------------------------

export function readRegions(world: World, rooms: Room[], allCaches: Region["caches"]): Region[] {
  return Object.entries(world.regions).map(([id, region]) => {
    const own = rooms.filter((room) => room.regionId === id);
    const enemies = new Set<string>();
    const bosses = new Set<string>();
    const cachesHere = allCaches.filter((cache) => own.some((room) => room.id === cache.room));
    for (const room of own) {
      for (const node of room.scene.nodes) {
        const enemy = /^res:\/\/scenes\/enemies\/(\w+)\.tscn$/.exec(node.instance ?? "");
        if (enemy && enemy[1] !== "shockwave") {
          enemies.add(enemy[1]);
          if (room.markers.includes("boss")) {
            bosses.add(enemy[1]);
          }
        }
      }
    }
    return {
      id,
      name: region.name,
      colour: region.colour.toLowerCase(),
      rooms: own.map((room) => ({ id: room.id, size: room.size })),
      enemies: [...enemies].sort(),
      caches: cachesHere,
      restPoints: own.filter((room) => room.markers.includes("rest")).map((room) => room.id),
      shops: own
        .filter((room) => room.scene.nodes.some((node) => node.instance === TRADER_SCENE))
        .map((room) => room.id),
      bosses: [...bosses].sort(),
    };
  });
}
