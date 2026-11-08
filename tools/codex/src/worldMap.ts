// The World map: every Room in its Region's colour, drawn live from the World's data, with a
// legend of what the Rooms hold. Drag to pan; the wheel, a pinch or the buttons zoom.

import type { Codex, MapRoom, Mark, MarkKind } from "../server/codex";
import { bounds, exitLine, fit, labelsShown, MARK_ORDER, pan, roomBox, symbols, zoomAt, type Box, type View } from "./mapView";
import { formatRoute } from "./select";

const SVG = "http://www.w3.org/2000/svg";
const GLYPH = 12;
const ZOOM_STEP = 1.5;
// How wide one character of a Room's id is drawn, in pixels.
const LABEL_CHAR = 6.2;

const KINDS: Record<MarkKind, { label: string; colour: string }> = {
  cache: { label: "Caches", colour: "#f8e18e" },
  rest: { label: "Rest points", colour: "#7cd4c8" },
  shop: { label: "Shops", colour: "#f0a050" },
  character: { label: "Characters", colour: "#a8c8ff" },
  boss: { label: "Bosses", colour: "#ff7a6b" },
  enemy: { label: "Enemies", colour: "#c8c8c8" },
};

// Which kinds the legend shows, kept from page to page. Enemies start hidden: nearly every Room
// has some.
const shown = new Set<MarkKind>(MARK_ORDER.filter((kind) => kind !== "enemy"));

function svg<K extends keyof SVGElementTagNameMap>(
  tag: K,
  attributes: Record<string, string | number> = {},
  ...children: (Node | null)[]
): SVGElementTagNameMap[K] {
  const node = document.createElementNS(SVG, tag);
  for (const [name, value] of Object.entries(attributes)) {
    node.setAttribute(name, String(value));
  }
  node.append(...children.filter((child): child is Node => child !== null));
  return node;
}

function title(text: string): SVGTitleElement {
  const node = svg("title");
  node.textContent = text;
  return node;
}

// A kind's symbol, centred on a point.
function glyph(kind: MarkKind, cx: number, cy: number, size = GLYPH): SVGElement {
  const r = size / 2;
  const fill = KINDS[kind].colour;
  const edge = { stroke: "#0b1622", "stroke-width": 1.5 };
  const points = (list: [number, number][]) => list.map(([x, y]) => `${cx + x * r},${cy + y * r}`).join(" ");
  switch (kind) {
    case "cache":
      return svg("rect", { x: cx - r, y: cy - r * 0.75, width: size, height: r * 1.5, rx: 1.5, fill, ...edge });
    case "rest":
      return svg("circle", { cx, cy, r: r * 0.85, fill, ...edge });
    case "shop":
      return svg("polygon", { points: points([[0, -1], [1, 0], [0, 1], [-1, 0]]), fill, ...edge });
    case "character":
      return svg("polygon", { points: points([[0, -1], [1, 0.85], [-1, 0.85]]), fill, ...edge });
    case "boss": {
      const star: [number, number][] = [];
      for (let i = 0; i < 10; i++) {
        const angle = -Math.PI / 2 + (i * Math.PI) / 5;
        const reach = i % 2 === 0 ? 1 : 0.45;
        star.push([Math.cos(angle) * reach, Math.sin(angle) * reach]);
      }
      return svg("polygon", { points: points(star), fill, ...edge });
    }
    case "enemy":
      return svg(
        "g",
        { stroke: fill, "stroke-width": 2.5, "stroke-linecap": "round" },
        svg("line", { x1: cx - r * 0.7, y1: cy - r * 0.7, x2: cx + r * 0.7, y2: cy + r * 0.7 }),
        svg("line", { x1: cx + r * 0.7, y1: cy - r * 0.7, x2: cx - r * 0.7, y2: cy + r * 0.7 }),
      );
  }
}

// The page a mark links to: an item, a Character or an enemy, or its Room's Region.
function markLink(mark: Mark, room: MapRoom): string {
  switch (mark.kind) {
    case "cache":
      return formatRoute({ section: "items", id: mark.id });
    case "character":
      return formatRoute({ section: "characters", id: mark.id });
    case "boss":
    case "enemy":
      return formatRoute({ section: "enemies", id: mark.id });
    default:
      return formatRoute({ section: "regions", id: room.region });
  }
}

// The World map, fitted to one Region's Rooms when it is given one, or else to the whole World.
export function worldMap(codex: Codex, focus: string | null = null): HTMLElement {
  const regions = new Map(codex.regions.map((region) => [region.id, region]));
  const rooms = codex.rooms;
  const focused = focus ? rooms.filter((room) => room.region === focus) : rooms;
  const target: Box = bounds((focused.length > 0 ? focused : rooms).map(roomBox));
  let view: View = { scale: 1, x: 0, y: 0 };
  let size = { w: 0, h: 0 };

  const picture = svg("svg", { class: "map-picture", role: "img", "aria-label": "World map" });
  const frame = document.createElement("div");
  frame.className = "map-frame";
  const legend = document.createElement("div");
  legend.className = "legend";
  legend.setAttribute("role", "group");
  legend.setAttribute("aria-label", "Show on the map");

  const draw = () => {
    const parts: SVGElement[] = [];
    const named = labelsShown(view.scale);
    for (const room of rooms) {
      const box = roomBox(room);
      const x = box.x * view.scale + view.x;
      const y = box.y * view.scale + view.y;
      const w = box.w * view.scale;
      const h = box.h * view.scale;
      const region = regions.get(room.region);
      const block = svg(
        "a",
        { href: formatRoute({ section: "regions", id: room.region }), class: "map-room", opacity: focus && room.region !== focus ? 0.45 : 1 },
        title(`${room.id} — ${region?.name ?? room.region}${room.planned ? " (planned)" : ""}`),
        svg("rect", {
          x,
          y,
          width: w,
          height: h,
          fill: room.planned ? "none" : (region?.colour ?? "#333"),
          stroke: room.planned ? "#a3a3a3" : "#ffffff66",
          "stroke-width": 1,
          "stroke-dasharray": room.planned ? "4 3" : "none",
        }),
      );
      for (const exit of room.exits) {
        const line = exitLine(room, exit);
        block.append(
          svg("line", {
            x1: line.x1 * view.scale + view.x,
            y1: line.y1 * view.scale + view.y,
            x2: line.x2 * view.scale + view.x,
            y2: line.y2 * view.scale + view.y,
            stroke: "#f8e18e",
            "stroke-width": 2,
          }),
        );
      }
      // A Room's id, when the Room is wide enough to hold it at this zoom.
      if (named && w >= room.id.length * LABEL_CHAR + 8) {
        const label = svg("text", { x: x + 4, y: y + 12, class: "map-label" });
        label.textContent = room.id;
        block.append(label);
      }
      parts.push(block);
      const marks = symbols(room.marks, shown);
      const across = marks.length * (GLYPH + 3) - 3;
      marks.forEach((symbol, index) => {
        const cx = x + w / 2 - across / 2 + GLYPH / 2 + index * (GLYPH + 3);
        const cy = y + h / 2 + (named ? 4 : 0);
        parts.push(
          svg(
            "a",
            { href: markLink(symbol.marks[0], room), class: "map-mark" },
            title(symbol.marks.map((mark) => mark.label).join("\n")),
            glyph(symbol.kind, cx, cy),
          ),
        );
      });
    }
    picture.replaceChildren(...parts);
  };

  const showLegend = () => {
    legend.replaceChildren(
      ...MARK_ORDER.map((kind) => {
        const count = rooms.filter((room) => room.marks.some((mark) => mark.kind === kind)).length;
        const button = document.createElement("button");
        button.type = "button";
        button.ariaPressed = String(shown.has(kind));
        button.append(
          svg("svg", { width: GLYPH + 4, height: GLYPH + 4, "aria-hidden": "true" }, glyph(kind, (GLYPH + 4) / 2, (GLYPH + 4) / 2)),
          ` ${KINDS[kind].label} `,
          Object.assign(document.createElement("span"), { className: "count", textContent: String(count) }),
        );
        button.addEventListener("click", () => {
          if (shown.has(kind)) {
            shown.delete(kind);
          } else {
            shown.add(kind);
          }
          showLegend();
          draw();
        });
        return button;
      }),
    );
  };

  const fitView = () => {
    view = fit(target, size.w, size.h);
    draw();
  };
  const zoomBy = (factor: number, px = size.w / 2, py = size.h / 2) => {
    view = zoomAt(view, factor, px, py);
    draw();
  };

  // Dragging pans; a drag that moved is not a click on what it started over.
  let dragging: { x: number; y: number; moved: boolean } | null = null;
  picture.addEventListener("pointerdown", (event) => {
    dragging = { x: event.clientX, y: event.clientY, moved: false };
  });
  picture.addEventListener("pointermove", (event) => {
    if (!dragging || event.buttons === 0) {
      return;
    }
    const dx = event.clientX - dragging.x;
    const dy = event.clientY - dragging.y;
    if (!dragging.moved && Math.hypot(dx, dy) < 3) {
      return;
    }
    if (!dragging.moved) {
      dragging.moved = true;
      picture.setPointerCapture(event.pointerId);
      frame.classList.add("dragging");
    }
    view = pan(view, dx, dy);
    dragging.x = event.clientX;
    dragging.y = event.clientY;
    draw();
  });
  const release = () => {
    frame.classList.remove("dragging");
    setTimeout(() => (dragging = null));
  };
  picture.addEventListener("pointerup", release);
  picture.addEventListener("pointercancel", release);
  picture.addEventListener(
    "click",
    (event) => {
      if (dragging?.moved) {
        event.preventDefault();
        event.stopPropagation();
      }
    },
    true,
  );
  // The wheel zooms toward the pointer; a trackpad pinch arrives as a wheel with Control held.
  picture.addEventListener(
    "wheel",
    (event) => {
      event.preventDefault();
      const rect = picture.getBoundingClientRect();
      const factor = Math.exp(-event.deltaY * (event.ctrlKey ? 0.01 : 0.0015));
      zoomBy(factor, event.clientX - rect.left, event.clientY - rect.top);
    },
    { passive: false },
  );

  const button = (text: string, label: string, act: () => void) => {
    const node = Object.assign(document.createElement("button"), { type: "button", textContent: text, title: label });
    node.setAttribute("aria-label", label);
    node.addEventListener("click", act);
    return node;
  };
  const controls = document.createElement("div");
  controls.className = "map-controls";
  controls.append(
    button("+", "Zoom in", () => zoomBy(ZOOM_STEP)),
    button("−", "Zoom out", () => zoomBy(1 / ZOOM_STEP)),
    button("Fit", "Fit the map", fitView),
  );
  frame.append(picture, controls);

  // Fits once the frame has a size, and keeps the view as it is when the frame resizes.
  new ResizeObserver(([entry]) => {
    const first = size.w === 0;
    size = { w: entry.contentRect.width, h: entry.contentRect.height };
    if (first && size.w > 0) {
      fitView();
    } else {
      draw();
    }
  }).observe(frame);

  showLegend();
  const wrapper = document.createElement("div");
  wrapper.className = "world-map";
  wrapper.append(frame, legend);
  return wrapper;
}
