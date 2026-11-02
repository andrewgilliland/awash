// The World editor's addresses: where you are as a URL, and back again.
//
//   /world, /world/<region>     the World as it is, all of it or one Region
//   /plan, /plan/<region>       the Plan, likewise
//   /rooms/<room>               a Room, to paint
//   ?room=<room>                the Room selected on the map
//
// "/" is the World as it is. Anything else is unknown. Whether a Room or Region by that name exists
// is for the page to say; these only read and write addresses.

import type { View } from "./dom";

export type Route = { view: View; selected: string | null } | { unknown: string };

export function parseRoute(pathname: string, search = ""): Route {
  const parts = pathname.split("/").filter(Boolean).map(decodeURIComponent);
  const selected = new URLSearchParams(search).get("room");
  const [top, name, ...rest] = parts;
  if (rest.length > 0) {
    return { unknown: pathname };
  }
  if (parts.length === 0) {
    return { view: { kind: "world", planned: false }, selected };
  }
  if (top === "world" || top === "plan") {
    const view: View = name === undefined ? { kind: "world", planned: top === "plan" } : { kind: "world", planned: top === "plan", region: name };
    return { view, selected };
  }
  if (top === "rooms" && name !== undefined) {
    return { view: { kind: "room", id: name }, selected: null };
  }
  return { unknown: pathname };
}

export function formatRoute(route: { view: View; selected: string | null }): string {
  const { view, selected } = route;
  if (view.kind === "room") {
    return `/rooms/${encodeURIComponent(view.id)}`;
  }
  const path = `/${view.planned ? "plan" : "world"}${view.region ? `/${encodeURIComponent(view.region)}` : ""}`;
  return selected ? `${path}?room=${encodeURIComponent(selected)}` : path;
}
