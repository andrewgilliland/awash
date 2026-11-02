// The sidebar: the editor's title, a summary of the World, and cards to move between the World as
// it is, the Plan, the Check and each built Room. The card for where you are is lit.

import { el, type View } from "./dom";
import type { WorldData } from "./world";

export interface Sidebar {
  world: WorldData;
  view: View;
  checking: boolean;
  show: (view: View) => void;
  check: () => void;
  // A Room card hovered or focused, to light that Room on the map; null when it's left.
  hover: (id: string | null) => void;
}

const ICONS: Record<string, string> = {
  region: "M3 18l5-9 4 6 3-4 6 7z",
  world: "M3 5h18v14H3z M3 12h18 M12 5v14",
  plan: "M4 4h7v7H4z M13 13h7v7h-7z M11 7.5h4.5V13",
  check: "M4 12l5 5L20 6",
  room: "M4 5h16v14H4z M4 15h16",
};

function icon(kind: string): SVGElement {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("aria-hidden", "true");
  const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
  path.setAttribute("d", ICONS[kind]);
  svg.append(path);
  return svg;
}

function card(kind: string, title: string, subtitle: string, lit: boolean, onclick: () => void, disabled = false): HTMLElement {
  return el(
    "button",
    { type: "button", className: `card${lit ? " lit" : ""}`, onclick, disabled, ariaCurrent: lit ? "page" : "false" },
    icon(kind),
    el(
      "span",
      { className: "card-text" },
      el("span", { className: "card-title" }, title),
      el("span", { className: "card-sub" }, subtitle),
    ),
  );
}

// A name and its value, joined by a dashed leader: //ROOMS ------ 9 BUILT
function info(name: string, value: string): HTMLElement {
  return el("div", { className: "info" }, el("span", { className: "label" }, name), el("span", { className: "leader" }), el("span", {}, value));
}

export function showSidebar(into: HTMLElement, sidebar: Sidebar) {
  const { world, view, show } = sidebar;
  const rooms = Object.entries(world.rooms);
  const built = rooms.filter(([, room]) => room.scene !== undefined);
  const planned = view.kind === "world" && view.planned;
  // The Region on show: the one picked, or the open Room's.
  const focus = view.kind === "world" ? view.region : world.rooms[view.id]?.region;
  into.replaceChildren(
    el("div", { className: "brand-box" }, el("span", {}, "Awash"), el("strong", {}, "World editor")),
    info("Rooms", `${built.length} built`),
    info("Planned", `${rooms.length - built.length} rooms`),
    info("Regions", String(Object.keys(world.regions).length)),
    el(
      "nav",
      { className: "cards", ariaLabel: "Views" },
      card("world", "The World", "As it is today", view.kind === "world" && !view.planned, () => show({ kind: "world", planned: false, region: focusOf(view) })),
      card("plan", "The Plan", "As planned, to edit", view.kind === "world" && view.planned, () => show({ kind: "world", planned: true, region: focusOf(view) })),
      card("check", "Check", sidebar.checking ? "Running the game's tests…" : "Run the game's tests", false, sidebar.check, sidebar.checking),
    ),
    el("p", { className: "label" }, "Regions"),
    el(
      "nav",
      { className: "cards", ariaLabel: "Regions" },
      ...Object.entries(world.regions).map(([id, region]) => {
        const inIt = rooms.filter(([, room]) => (room.plan?.region ?? room.region) === id);
        const builtHere = inIt.filter(([, room]) => room.scene !== undefined).length;
        const lit = view.kind === "world" && view.region === id;
        // a second click shows the whole World again
        return card("region", region.name, `${builtHere} built · ${inIt.length - builtHere} planned`, lit, () =>
          show({ kind: "world", planned, region: lit ? undefined : id }),
        );
      }),
    ),
    el("p", { className: "label" }, focus ? `Rooms in ${world.regions[focus]?.name ?? focus}` : "Rooms"),
    el(
      "nav",
      { className: "cards", ariaLabel: "Rooms" },
      ...built.filter(([, room]) => !focus || room.region === focus).map(([id, room]) => {
        const roomCard = card(
          "room",
          id.replace(/_/g, " "),
          `${room.size[0]}×${room.size[1]} · ${world.regions[room.region]?.name ?? room.region}`,
          view.kind === "room" && view.id === id,
          () => show({ kind: "room", id }),
        );
        roomCard.addEventListener("pointerenter", () => sidebar.hover(id));
        roomCard.addEventListener("pointerleave", () => sidebar.hover(null));
        roomCard.addEventListener("focus", () => sidebar.hover(id));
        roomCard.addEventListener("blur", () => sidebar.hover(null));
        return roomCard;
      }),
    ),
  );
}

// The Region a view shows, if one.
function focusOf(view: View): string | undefined {
  return view.kind === "world" ? view.region : undefined;
}
