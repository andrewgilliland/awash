// The Codex's page: a list of one section's entries on the left, searched and filtered, and the
// chosen entry's page on the right. Where you are is the address, so Back, Forward and links work.

import "@fontsource/jetbrains-mono/400.css";
import "@fontsource/jetbrains-mono/700.css";
import type { Character, Codex, Enemy, Item, Region, Sprite } from "../server/codex";
import { byKind, formatRoute, frameCount, frameRect, parseRoute, shown, SECTIONS, type Filter, type Route, type Section } from "./select";

const SCALE = 4;
const THUMB = 24;
const TITLES: Record<Section, string> = { enemies: "Enemies", items: "Items", characters: "Characters", regions: "Regions" };

let codex: Codex;
let filter: Filter = "game";
let query = "";

const sidebar = document.querySelector("#sidebar") as HTMLElement;
const page = document.querySelector("#page") as HTMLElement;

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props: Record<string, unknown> = {},
  ...children: (Node | string | null)[]
): HTMLElementTagNameMap[K] {
  const node = Object.assign(document.createElement(tag), props);
  node.append(...children.filter((child): child is Node | string => child !== null));
  return node;
}

function art(path: string): string {
  return `/repo/${path}`;
}

const images = new Map<string, Promise<HTMLImageElement>>();
function image(path: string): Promise<HTMLImageElement> {
  let loading = images.get(path);
  if (!loading) {
    loading = new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = reject;
      img.src = art(path);
    });
    images.set(path, loading);
  }
  return loading;
}

// One frame of a sheet, drawn crisp at a scale, or fitted into a box when one is given.
function frame(sprite: Sprite, index: number, scale: number, box?: number): HTMLCanvasElement {
  const canvas = el("canvas", { className: "pixel" });
  image(sprite.sheet).then((img) => {
    const rect = frameRect(sprite, img.width, img.height, index);
    const fit = box ? Math.max(1, Math.floor(box / Math.max(rect.w, rect.h))) : scale;
    canvas.width = rect.w * fit;
    canvas.height = rect.h * fit;
    const context = canvas.getContext("2d") as CanvasRenderingContext2D;
    context.imageSmoothingEnabled = false;
    context.drawImage(img, rect.x, rect.y, rect.w, rect.h, 0, 0, canvas.width, canvas.height);
  });
  return canvas;
}

function icon(path: string, size: number): HTMLImageElement {
  return el("img", { className: "pixel", src: art(path), width: size, height: size, alt: "" });
}

// --- The list ------------------------------------------------------------------------------------

interface Listed {
  id: string;
  name: string;
  planned: boolean;
  // An item's type, which the Items list is split by.
  kind?: string;
  thumb: Node | null;
  badges: HTMLElement[];
}

function listed(section: Section): Listed[] {
  switch (section) {
    case "enemies":
      return codex.enemies.map((enemy) => ({
        id: enemy.id,
        name: enemy.name,
        planned: enemy.planned,
        thumb: enemy.sprite ? frame(enemy.sprite, 0, 1, THUMB) : null,
        badges: enemy.boss ? [badge("Boss", "boss")] : [],
      }));
    case "items":
      return codex.items.map((item) => ({
        id: item.id,
        name: item.name,
        planned: item.planned,
        kind: item.kind,
        thumb: item.icon ? icon(item.icon, 16) : null,
        badges: [],
      }));
    case "characters":
      return codex.characters.map((character) => ({
        id: character.id,
        name: character.name,
        planned: character.planned,
        thumb: character.sprite ? frame({ sheet: character.sprite }, 0, 1, THUMB) : null,
        badges: [],
      }));
    case "regions":
      return codex.regions.map((region) => ({
        id: region.id,
        name: region.name,
        planned: false,
        thumb: el("span", { className: "swatch", style: `background:${region.colour}` }),
        badges: [],
      }));
  }
}

function badge(text: string, kind = ""): HTMLElement {
  return el("span", { className: `badge ${kind}` }, text);
}

function showSidebar(route: Route): void {
  const tabs = el(
    "nav",
    { className: "tabs" },
    ...SECTIONS.map((section) =>
      el("a", {
        className: "tab",
        href: formatRoute({ section, id: null }),
        ariaCurrent: section === route.section ? "page" : null,
        textContent: TITLES[section],
      }),
    ),
  );
  const search = el("input", { type: "search", placeholder: "Search", value: query, ariaLabel: "Search" });
  search.addEventListener("input", () => {
    query = search.value;
    showList(route, list);
  });
  const filters = el(
    "div",
    { className: "filter", role: "group", ariaLabel: "Show" },
    ...(
      [
        ["game", "In game"],
        ["planned", "Planned"],
        ["all", "All"],
      ] as [Filter, string][]
    ).map(([value, label]) => {
      const button = el("button", { type: "button", ariaPressed: String(filter === value), textContent: label });
      button.addEventListener("click", () => {
        filter = value;
        render();
      });
      return button;
    }),
  );
  const list = el("ul", { className: "list" });
  // Every Region is in the game, so there is nothing to filter.
  filters.hidden = route.section === "regions";
  sidebar.replaceChildren(el("h1", {}, "Awash Codex"), tabs, search, filters, list);
  showList(route, list);
}

function showList(route: Route, list: HTMLElement): void {
  const entries = shown(listed(route.section), route.section === "regions" ? "all" : filter, query);
  const row = (entry: Listed) =>
    el(
      "li",
      {},
      el(
        "a",
        {
          href: formatRoute({ section: route.section, id: entry.id }),
          ariaCurrent: entry.id === route.id ? "page" : null,
        },
        el("span", { className: "thumb" }, entry.thumb),
        el("span", { className: `name ${entry.planned ? "planned" : ""}` }, entry.name),
        ...entry.badges,
        entry.planned ? badge("Planned", "planned") : null,
      ),
    );
  if (route.section === "items") {
    // The items under a heading for each type, with how many it holds.
    list.replaceChildren(
      ...byKind(entries.map((entry) => ({ ...entry, kind: entry.kind ?? "" }))).flatMap((group) => [
        el("li", { className: "group" }, el("span", {}, group.title), el("span", { className: "count" }, String(group.entries.length))),
        ...group.entries.map(row),
      ]),
    );
  } else {
    list.replaceChildren(...entries.map(row));
  }
  if (entries.length === 0) {
    list.append(el("li", { className: "empty" }, "Nothing matches."));
  }
}

// --- An entry's page -----------------------------------------------------------------------------

function link(section: Section, id: string, text: string): HTMLAnchorElement {
  return el("a", { className: "link", href: formatRoute({ section, id }), textContent: text });
}

function nameOf(section: "enemies" | "items", id: string): string {
  const entries: { id: string; name: string }[] = section === "enemies" ? codex.enemies : codex.items;
  return entries.find((entry) => entry.id === id)?.name ?? id;
}

function percent(chance: number): string {
  return `${Math.round(chance * 1000) / 10}%`;
}

function facts(items: (Node | string)[], empty: string): HTMLElement {
  if (items.length === 0) {
    return el("p", { className: "empty" }, empty);
  }
  return el("ul", { className: "facts" }, ...items.map((item) => el("li", {}, item)));
}

function stats(rows: [string, string | Node][]): HTMLElement {
  return el("dl", { className: "stats" }, ...rows.flatMap(([term, value]) => [el("dt", {}, term), el("dd", {}, value)]));
}

function heading(name: string, badges: (HTMLElement | null)[], meta: string): HTMLElement[] {
  return [
    el("div", { className: "title" }, el("h2", {}, name), ...badges),
    meta ? el("p", { className: "meta" }, meta) : el("span"),
  ];
}

function roomLine(room: { id: string; region?: string; count?: number }): string {
  const count = room.count && room.count > 1 ? ` (${room.count})` : "";
  return `${room.id}${room.region ? ` — ${room.region}` : ""}${count}`;
}

function showEnemy(enemy: Enemy): Node[] {
  const meta = [enemy.category, enemy.size, enemy.movement].filter(Boolean).join(" · ");
  const parts: Node[] = heading(enemy.name, [enemy.boss ? badge("Boss", "boss") : null, enemy.planned ? badge("Planned", "planned") : null], meta);
  if (enemy.sprite) {
    parts.push(spriteBlock(enemy.sprite));
  }
  if (enemy.stats) {
    parts.push(
      el("h3", {}, "Stats"),
      stats([
        ["Health", String(enemy.stats.health)],
        ["Experience", String(enemy.stats.experience)],
        ["Gold", String(enemy.stats.gold)],
      ]),
      el("h3", {}, "Hits for"),
      facts(enemy.hits.map((hit) => `${hit.name} — ${hit.damage}`), "Nothing."),
      el("h3", {}, "Drops"),
      facts(
        enemy.drops.map((drop) => el("span", {}, link("items", drop.item, nameOf("items", drop.item)), ` — ${percent(drop.chance)}`)),
        "Nothing.",
      ),
      el("h3", {}, "Found in"),
      facts(enemy.rooms.map(roomLine), "No Room yet."),
    );
  }
  for (const encounter of enemy.encounters) {
    parts.push(
      el("h3", {}, encounter.region || "Encounter"),
      el("p", {}, encounter.description),
      encounter.visual ? el("p", { className: "meta" }, encounter.visual) : el("span"),
    );
  }
  return parts;
}

// Every frame of the sheet, each animation's named, and the first animation playing.
function spriteBlock(sprite: Sprite): HTMLElement {
  const block = el("div", { className: "sprite" });
  image(sprite.sheet).then((img) => {
    const animations = Object.entries(sprite.animations ?? {});
    const groups: [string, number[]][] =
      animations.length > 0 ? animations : [["frames", [...Array(frameCount(sprite, img.width, img.height)).keys()]]];
    const [first] = groups;
    const playing = el("canvas", { className: "pixel" });
    let step = 0;
    const draw = () => {
      const rect = frameRect(sprite, img.width, img.height, first[1][step % first[1].length]);
      playing.width = rect.w * SCALE * 2;
      playing.height = rect.h * SCALE * 2;
      const context = playing.getContext("2d") as CanvasRenderingContext2D;
      context.imageSmoothingEnabled = false;
      context.drawImage(img, rect.x, rect.y, rect.w, rect.h, 0, 0, playing.width, playing.height);
      step += 1;
    };
    draw();
    const timer = window.setInterval(() => (playing.isConnected ? draw() : window.clearInterval(timer)), 250);
    block.append(el("figure", {}, playing, el("figcaption", {}, first[0])));
    for (const [name, frames] of groups) {
      block.append(
        el("figure", {}, el("div", { className: "frames" }, ...frames.map((index) => frame(sprite, index, SCALE))), el("figcaption", {}, name)),
      );
    }
  });
  return block;
}

function showItem(item: Item): Node[] {
  const parts: Node[] = heading(item.name, [badge(item.kind), item.planned ? badge("Planned", "planned") : null], item.effect);
  if (item.icon) {
    parts.push(el("div", { className: "sprite" }, el("div", { className: "frames" }, icon(item.icon, 64))));
  }
  if (item.description) {
    parts.push(el("p", { className: "quote" }, `“${item.description}”`));
  }
  if (!item.planned) {
    const where: (Node | string)[] = [];
    if (item.price !== null) {
      where.push(`Tidefen's Supply Shop — ${item.price} Gold`);
    }
    for (const cache of item.caches) {
      where.push(`Cache ${cache.id} in ${cache.room} — ${cache.count}`);
    }
    for (const drop of item.droppedBy) {
      where.push(el("span", {}, link("enemies", drop.enemy, nameOf("enemies", drop.enemy)), ` drops it — ${percent(drop.chance)}`));
    }
    parts.push(el("h3", {}, "Where to get it"), facts(where, "Nowhere yet."));
  }
  if (item.lore) {
    parts.push(el("h3", {}, "From the docs"), el("p", {}, item.lore));
  }
  return parts;
}

function showCharacter(character: Character): Node[] {
  const parts: Node[] = heading(character.name, [character.planned ? badge("Planned", "planned") : null], character.details.role ?? "");
  if (character.sprite) {
    parts.push(spriteBlock({ sheet: character.sprite }));
  }
  if (character.lines.length > 0) {
    parts.push(el("h3", {}, "Says"), ...character.lines.map((line) => el("p", { className: "quote" }, `“${line}”`)));
  }
  if (!character.planned) {
    parts.push(el("h3", {}, "Found in"), facts(character.rooms, "Not in a Room."));
  }
  const details = Object.entries(character.details).filter(([key]) => key !== "role");
  if (details.length > 0) {
    parts.push(el("h3", {}, "From the docs"), stats(details.map(([key, value]) => [key.replaceAll("_", " "), value])));
  }
  return parts;
}

function showRegion(region: Region): Node[] {
  return [
    el("div", { className: "title" }, el("span", { className: "swatch", style: `background:${region.colour}` }), el("h2", {}, region.name)),
    el("h3", {}, "Rooms"),
    facts(region.rooms.map((room) => `${room.id} — ${room.size[0]}×${room.size[1]} screens`), "None built."),
    el("h3", {}, "Enemies"),
    facts(region.enemies.map((id) => link("enemies", id, nameOf("enemies", id))), "None."),
    el("h3", {}, "Bosses"),
    facts(region.bosses.map((id) => link("enemies", id, nameOf("enemies", id))), "None."),
    el("h3", {}, "Caches"),
    facts(
      region.caches.map((cache) => el("span", {}, `${cache.id} in ${cache.room}: ${cache.count} `, link("items", cache.kind, nameOf("items", cache.kind)))),
      "None.",
    ),
    el("h3", {}, "Rest points"),
    facts(region.restPoints, "None."),
    el("h3", {}, "Shops"),
    facts(region.shops, "None."),
  ];
}

function showPage(route: Route): void {
  const entry = route.id ? findEntry(route) : null;
  if (!entry) {
    page.replaceChildren(el("h2", {}, TITLES[route.section]), el("p", { className: "meta" }, "Choose one from the list."));
    return;
  }
  page.replaceChildren(...entry);
  page.scrollTop = 0;
}

function findEntry(route: Route): Node[] | null {
  switch (route.section) {
    case "enemies": {
      const enemy = codex.enemies.find((entry) => entry.id === route.id);
      return enemy ? showEnemy(enemy) : null;
    }
    case "items": {
      const item = codex.items.find((entry) => entry.id === route.id);
      return item ? showItem(item) : null;
    }
    case "characters": {
      const character = codex.characters.find((entry) => entry.id === route.id);
      return character ? showCharacter(character) : null;
    }
    case "regions": {
      const region = codex.regions.find((entry) => entry.id === route.id);
      return region ? showRegion(region) : null;
    }
  }
}

function render(): void {
  const route = parseRoute(location.hash);
  showSidebar(route);
  showPage(route);
}

async function start(): Promise<void> {
  page.replaceChildren(el("p", { className: "meta" }, "Reading the game's files…"));
  const response = await fetch("/api/codex");
  codex = (await response.json()) as Codex;
  window.addEventListener("hashchange", render);
  render();
}

start().catch((error: unknown) => {
  page.replaceChildren(el("h2", {}, "The Codex could not be read"), el("p", { className: "meta" }, String(error)));
});
