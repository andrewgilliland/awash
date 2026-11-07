import { basename } from "node:path";
import { isName, readConsts, readVars, type Value } from "./gdscript.ts";
import { readScene, type Scene, type SceneNode } from "./tscn.ts";
import { entries, field, local, preloadPath, readDocs, record, titled, vector, type Doc, type Files, type Room } from "./repo.ts";
import type { Enemy, Sprite } from "./types.ts";

const HITBOX = "res://scripts/combat/hitbox.gd";
// A hit a hitbox makes when nothing sets it otherwise, as scripts/combat/hitbox.gd has it.
const DEFAULT_DAMAGE = 10;

// --- Enemies -------------------------------------------------------------------------------------

export async function readEnemies(files: Files, rooms: Room[]): Promise<Enemy[]> {
  const docs = (await readDocs(files, "docs/enemies")).filter((doc) =>
    ["enemy", "boss"].includes(field(doc.data, "type")),
  );
  const enemies: Enemy[] = [];
  const documented = new Set<string>();
  for (const path of await files.list("scripts/enemies", ".gd")) {
    const script = await files.text(path);
    const consts = readConsts(script);
    if (!/^signal defeated/m.test(script) || typeof consts.MAX_HEALTH !== "number") {
      continue;
    }
    const id = basename(path, ".gd");
    const scenePath = `scenes/enemies/${id}.tscn`;
    const sceneText = await files.textOrNull(scenePath);
    const scene = sceneText ? readScene(sceneText) : { resources: {}, nodes: [] };
    const doc = docs.find((entry) => basename(entry.path, ".md") === id.replaceAll("_", "-"));
    if (doc) {
      documented.add(doc.path);
    }
    const root = scene.nodes.find((node) => node.parent === "");
    enemies.push({
      ...lore(id, doc),
      boss: (root?.groups.includes("boss") ?? false) || field(doc?.data ?? {}, "type") === "boss",
      planned: false,
      stats: {
        health: consts.MAX_HEALTH as number,
        experience: typeof consts.EXPERIENCE === "number" ? consts.EXPERIENCE : 0,
        gold: typeof consts.GOLD === "number" ? consts.GOLD : 0,
      },
      drops: drops(consts),
      hits: await hits(files, consts, scene),
      sprite: enemySprite(consts, scene),
      rooms: placements(rooms, `res://${scenePath}`),
    });
  }
  for (const doc of docs) {
    if (documented.has(doc.path)) {
      continue;
    }
    const id = basename(doc.path, ".md").replaceAll("-", "_");
    enemies.push({
      ...lore(id, doc),
      boss: field(doc.data, "type") === "boss",
      planned: true,
      stats: null,
      drops: [],
      hits: [],
      sprite: null,
      rooms: [],
    });
  }
  return enemies.sort((a, b) => a.name.localeCompare(b.name));
}

function lore(id: string, doc: Doc | undefined) {
  const data = doc?.data ?? {};
  const encounters = Array.isArray(data.encounters) ? (data.encounters as Record<string, unknown>[]) : [];
  return {
    id,
    name: field(data, "name") || titled(id),
    category: field(data, "category"),
    size: field(data, "size"),
    movement: field(data, "movement"),
    encounters: encounters.map((encounter) => ({
      region: field(encounter, "region"),
      description: field(encounter, "description"),
      visual: field(encounter, "visual"),
    })),
  };
}

// What a defeated enemy may leave: its Supply (a Brinecap if it names none) and its Weapon.
function drops(consts: Record<string, Value>): Enemy["drops"] {
  const found: Enemy["drops"] = [];
  const chance = consts.DROP_CHANCE;
  if (typeof chance === "number" && chance > 0) {
    const drop = consts.DROP;
    found.push({ item: drop !== undefined && isName(drop) ? drop.name : "brinecap", chance });
  }
  const weapon = consts.WEAPON_DROP;
  const weaponChance = consts.WEAPON_DROP_CHANCE;
  if (weapon !== undefined && isName(weapon) && typeof weaponChance === "number" && weaponChance > 0) {
    found.push({ item: weapon.name, chance: weaponChance });
  }
  return found;
}

// What each of its hits costs the Player: the damage its scripts set (its own consts and its
// brain's vars), or else its hitboxes' own; then the hits of the scenes it sends out.
async function hits(
  files: Files,
  consts: Record<string, Value>,
  scene: Scene,
): Promise<Enemy["hits"]> {
  const found: Enemy["hits"] = [];
  const named = (name: string, value: Value) => {
    if (typeof value === "number" && value > 0) {
      found.push({ name: titled(name.replace(/_damage$/i, "")), damage: value });
    }
  };
  for (const [name, value] of Object.entries(consts)) {
    if (/^[A-Z_]+_DAMAGE$/.test(name)) {
      named(name, value);
    }
  }
  for (const value of Object.values(consts)) {
    const path = preloadPath(value);
    if (path?.endsWith("_brain.gd")) {
      for (const [name, damage] of Object.entries(readVars(await files.text(path)))) {
        if (/_damage$/.test(name)) {
          named(name, damage);
        }
      }
    }
  }
  const scriptSets = found.length > 0;
  for (const node of scene.nodes) {
    if (!(await isHitbox(files, node))) {
      continue;
    }
    const damage = node.properties.damage;
    if (typeof damage === "number") {
      found.push({ name: node.name.replace(/Hitbox$/, ""), damage });
    } else if (!scriptSets) {
      found.push({ name: node.name.replace(/Hitbox$/, ""), damage: DEFAULT_DAMAGE });
    }
  }
  for (const value of Object.values(consts)) {
    const path = preloadPath(value);
    if (!path?.endsWith(".tscn")) {
      continue;
    }
    const sent = readScene(await files.text(path));
    for (const node of sent.nodes) {
      if (await isHitbox(files, node)) {
        const damage = node.properties.damage;
        found.push({ name: titled(basename(path, ".tscn")), damage: typeof damage === "number" ? damage : DEFAULT_DAMAGE });
      }
    }
  }
  return found;
}

async function isHitbox(files: Files, node: SceneNode): Promise<boolean> {
  const script = node.properties.script;
  if (typeof script !== "string") {
    return false;
  }
  if (script === HITBOX) {
    return true;
  }
  const text = await files.textOrNull(script);
  return text !== null && text.startsWith(`extends "${HITBOX}"`);
}

function enemySprite(consts: Record<string, Value>, scene: Scene): Sprite | null {
  const sheet = preloadPath(consts.SHEET);
  if (sheet) {
    const animations: Record<string, number[]> = {};
    for (const entry of entries(consts.ANIMATIONS)) {
      const frames = record(entry.value).frames;
      if (isName(entry.key) && Array.isArray(frames)) {
        animations[entry.key.name] = frames.filter((frame): frame is number => typeof frame === "number");
      }
    }
    return { sheet, frame: vector(consts.FRAME_SIZE) ?? undefined, animations };
  }
  for (const node of scene.nodes) {
    const texture = node.properties.texture;
    if (typeof texture === "string" && (node.type === "Sprite2D" || node.type === "AnimatedSprite2D")) {
      const across = node.properties.hframes;
      const down = node.properties.vframes;
      return {
        sheet: local(texture),
        grid: [typeof across === "number" ? across : 1, typeof down === "number" ? down : 1],
      };
    }
  }
  return null;
}

// Each Room a scene is placed in, with how many.
function placements(rooms: Room[], scenePath: string): Enemy["rooms"] {
  const found: Enemy["rooms"] = [];
  for (const room of rooms) {
    const count = room.scene.nodes.filter((node) => node.instance === scenePath).length;
    if (count > 0) {
      found.push({ id: room.id, region: room.region, count });
    }
  }
  return found;
}
