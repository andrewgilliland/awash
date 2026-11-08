import { isName, isRef, readConsts, type Value } from "./gdscript.ts";
import { entries, field, keyName, local, preloadPath, readDocs, record, singular, titled, type Files, type Room } from "./repo.ts";
import type { Enemy, Item, Region } from "./types.ts";

const CACHE_SCENE = "res://scenes/world/cache.tscn";

// --- Items ---------------------------------------------------------------------------------------

export async function readItems(files: Files, allCaches: Region["caches"], enemies: Enemy[]): Promise<Item[]> {
  const items: Item[] = [];
  const supplies = readConsts(await files.text("scripts/items/supplies.gd"));
  const subWeapons = readConsts(await files.text("scripts/items/sub_weapons.gd"));
  const equipment = readConsts(await files.text("scripts/items/equipment.gd"));
  const add = (
    kind: string,
    consts: Record<string, Value>,
    table: Value | undefined,
    effect: (fields: Record<string, Value>) => string,
  ) => {
    for (const entry of entries(table)) {
      const id = keyName(entry.key, consts);
      if (!id) {
        continue;
      }
      const fields = record(entry.value);
      const icon = typeof fields.icon === "string" ? local(fields.icon) : `assets/items/${id}.png`;
      items.push({
        id,
        name: typeof fields.name === "string" ? fields.name : titled(id),
        kind,
        planned: false,
        description: typeof fields.description === "string" ? fields.description : "",
        effect: effect(fields),
        trait: "",
        traitBuilt: false,
        icon,
        price: null,
        caches: [],
        droppedBy: [],
        lore: "",
      });
    }
  };
  add("Supply", supplies, supplies.KINDS, (fields) => {
    if (typeof fields.restores === "number") {
      return `Restores ${fields.restores} Health`;
    }
    const share = fields.restores_share;
    if (typeof share === "number") {
      return share === 0.5 ? "Restores half your Health" : `Restores ${Math.round(share * 100)}% of your Health`;
    }
    return "";
  });
  const carried = subWeapons.CARRY_LIMIT;
  add("Sub Weapon", subWeapons, subWeapons.KINDS, () =>
    typeof carried === "number" ? `Up to ${carried} carried` : "",
  );
  add("Weapon", equipment, equipment.WEAPONS, (fields) =>
    typeof fields.attack === "number" ? `Attack +${fields.attack}` : "",
  );
  add("Armor", equipment, equipment.ARMOR, (fields) =>
    typeof fields.defense === "number" ? `Defense +${fields.defense}` : "",
  );
  await priceFromShop(files, items);
  for (const cache of allCaches) {
    items.find((item) => item.id === cache.kind)?.caches.push({ id: cache.id, room: cache.room, count: cache.count });
  }
  for (const enemy of [...enemies].sort((a, b) => a.id.localeCompare(b.id))) {
    for (const drop of enemy.drops) {
      items.find((item) => item.id === drop.item)?.droppedBy.push({ enemy: enemy.id, chance: drop.chance });
    }
  }
  await loreFromDocs(files, items);
  return items;
}

async function priceFromShop(files: Files, items: Item[]): Promise<void> {
  const shop = readConsts(await files.text("scripts/items/shop.gd"));
  const stock = Array.isArray(shop.STOCK) ? shop.STOCK : [];
  for (const line of stock) {
    if (!Array.isArray(line) || typeof line[1] !== "number") {
      continue;
    }
    const id = await resolveName(files, line[0] as Value, shop);
    const item = items.find((entry) => entry.id === id);
    if (item) {
      item.price = line[1];
    }
  }
}

// A StringName, or a const naming one here or in a script preloaded as Alias.NAME.
async function resolveName(files: Files, value: Value, consts: Record<string, Value>): Promise<string | null> {
  if (isName(value)) {
    return value.name;
  }
  if (!isRef(value)) {
    return null;
  }
  const [alias, name] = value.ref.includes(".") ? value.ref.split(".") : [null, value.ref];
  let table = consts;
  if (alias) {
    const path = preloadPath(consts[alias]);
    if (!path) {
      return null;
    }
    table = readConsts(await files.text(path));
  }
  const named = table[name];
  return named !== undefined && isName(named) ? named.name : null;
}

// Each Cache in the World and what it holds, as the Cache's own defaults fill in what a Room leaves.
export async function caches(files: Files, rooms: Room[]): Promise<Region["caches"]> {
  const defaults = readExports(await files.text("scripts/world/cache.gd"));
  const found: Region["caches"] = [];
  for (const room of rooms) {
    for (const node of room.scene.nodes) {
      if (node.instance !== CACHE_SCENE) {
        continue;
      }
      const kind = node.properties.kind ?? defaults.kind;
      const count = node.properties.count ?? defaults.count;
      const id = node.properties.cache_id;
      found.push({
        id: id !== undefined && isName(id) ? id.name : node.name,
        room: room.id,
        kind: kind !== undefined && isName(kind) ? kind.name : "",
        count: typeof count === "number" ? count : 0,
      });
    }
  }
  return found;
}

// A script's exported vars and their defaults.
function readExports(script: string): Record<string, Value> {
  return readConsts(script.replace(/^@export var /gm, "const "));
}

// The docs' word on each item: a doc of its own, by its name or one of its forms', or a line in
// a list of its kind; any the game does not hold yet join as planned.
async function loreFromDocs(files: Files, items: Item[]): Promise<void> {
  const byName = (name: string) => items.find((item) => item.name.toLowerCase() === name.toLowerCase());
  for (const doc of await readDocs(files, "docs/items")) {
    const type = field(doc.data, "type");
    if (type === "item_type") {
      for (const line of doc.body.matchAll(/^- \*\*([^*]+)\*\*:\s*(.+)$/gm)) {
        const item = byName(line[1]);
        const words = withoutFiles(line[2]);
        if (item) {
          item.lore ||= words;
        } else {
          items.push(plannedItem(line[1], field(doc.data, "name"), words));
        }
      }
      continue;
    }
    if (!type) {
      continue;
    }
    const forms = Array.isArray(doc.data.forms) ? (doc.data.forms as Record<string, unknown>[]) : [];
    const names = [field(doc.data, "name"), ...forms.map((form) => field(form, "name"))];
    const item = names.map(byName).find((entry) => entry !== undefined);
    const words = withoutFiles(
      [field(doc.data, "description"), field(doc.data, "acquisition")].filter(Boolean).join(" "),
    );
    const trait = field(doc.data, "trait") || field(doc.data, "legendary_trait");
    if (item) {
      item.lore ||= words;
      if (!item.trait && trait) {
        item.trait = trait;
        item.traitBuilt = doc.data.trait_built === true;
      }
    } else {
      const planned = plannedItem(field(doc.data, "name"), field(doc.data, "item_type") || titled(type), words);
      planned.id = field(doc.data, "id") || planned.id;
      const icon = forms.map((form) => field(form, "icon")).find(Boolean);
      planned.icon = icon ? local(icon) : null;
      planned.effect = docEffect(doc.data, forms);
      planned.trait = trait;
      items.push(planned);
    }
  }
}

// What a planned item does, by its doc: its Attack or Defense, or the effect it states.
function docEffect(data: Record<string, unknown>, forms: Record<string, unknown>[]): string {
  for (const [stat, label] of [
    ["attack", "Attack"],
    ["defense", "Defense"],
  ]) {
    const value = forms.map((form) => form[stat]).find((entry) => typeof entry === "number");
    if (typeof value === "number") {
      return `${label} +${value}`;
    }
  }
  return field(data, "effect");
}

// The docs' words without the files they point at, such as (`assets/items/brinecap.aseprite`).
function withoutFiles(words: string): string {
  return words.replace(/\s*\([^()]*`[^`]*\.[a-z]+`[^()]*\)/g, "").trim();
}

function plannedItem(name: string, kind: string, lore: string): Item {
  return {
    id: name.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, ""),
    name,
    kind: singular(kind),
    planned: true,
    description: "",
    effect: "",
    trait: "",
    traitBuilt: false,
    icon: null,
    price: null,
    caches: [],
    droppedBy: [],
    lore,
  };
}
