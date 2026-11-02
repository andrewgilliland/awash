import { describe, expect, it } from "vitest";
import { formatRoute, parseRoute } from "../src/router";

describe("reading a URL", () => {
  it("knows the World as it is, and the Plan", () => {
    expect(parseRoute("/world")).toEqual({ view: { kind: "world", planned: false }, selected: null });
    expect(parseRoute("/plan")).toEqual({ view: { kind: "world", planned: true }, selected: null });
  });

  it("knows a Region of either", () => {
    expect(parseRoute("/plan/undertow")).toEqual({ view: { kind: "world", planned: true, region: "undertow" }, selected: null });
    expect(parseRoute("/world/waking_coast")).toEqual({
      view: { kind: "world", planned: false, region: "waking_coast" },
      selected: null,
    });
  });

  it("knows a Room", () => {
    expect(parseRoute("/rooms/waking_coast_4")).toEqual({ view: { kind: "room", id: "waking_coast_4" }, selected: null });
  });

  it("knows the Room selected on the map", () => {
    expect(parseRoute("/plan", "?room=waking_coast_4")).toEqual({
      view: { kind: "world", planned: true },
      selected: "waking_coast_4",
    });
  });

  it("takes the World as where to start, and forgives a trailing slash", () => {
    expect(parseRoute("/")).toEqual({ view: { kind: "world", planned: false }, selected: null });
    expect(parseRoute("/plan/")).toEqual(parseRoute("/plan"));
    expect(parseRoute("/rooms/waking_coast_4/")).toEqual(parseRoute("/rooms/waking_coast_4"));
  });

  it("calls anything else unknown", () => {
    expect(parseRoute("/false")).toEqual({ unknown: "/false" });
    expect(parseRoute("/rooms")).toEqual({ unknown: "/rooms" });
    expect(parseRoute("/world/a/b")).toEqual({ unknown: "/world/a/b" });
  });
});

describe("writing a URL", () => {
  it("writes every view as the address that reads back to it", () => {
    const routes = [
      { view: { kind: "world" as const, planned: false }, selected: null },
      { view: { kind: "world" as const, planned: true }, selected: "waking_coast_4" },
      { view: { kind: "world" as const, planned: true, region: "undertow" }, selected: null },
      { view: { kind: "world" as const, planned: false, region: "waking_coast" }, selected: "waking_coast_1" },
      { view: { kind: "room" as const, id: "waking_coast_8" }, selected: null },
    ];
    for (const route of routes) {
      const url = new URL(formatRoute(route), "http://localhost");
      expect(parseRoute(url.pathname, url.search)).toEqual(route);
    }
    expect(formatRoute(routes[1])).toBe("/plan?room=waking_coast_4");
    expect(formatRoute(routes[4])).toBe("/rooms/waking_coast_8");
  });

  it("keeps an odd id whole", () => {
    const route = { view: { kind: "room" as const, id: "a room/with#marks" }, selected: null };
    const url = new URL(formatRoute(route), "http://localhost");
    expect(parseRoute(url.pathname, url.search)).toEqual(route);
  });
});
