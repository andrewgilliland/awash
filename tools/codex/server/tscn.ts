import { isCall, readValueAt, type Value } from "./gdscript.ts";

// Reads a Godot scene's nodes and the files they name; everything else in it is left to Godot.

export interface SceneNode {
  name: string;
  type: string | null;
  // Godot's path from the root to the node's parent: "." for the root's children, "" for the root.
  parent: string;
  groups: string[];
  // The scene the node instances, as a res:// path.
  instance: string | null;
  properties: Record<string, Value>;
}

export interface Scene {
  // Each external resource's res:// path, by id.
  resources: Record<string, string>;
  nodes: SceneNode[];
}

const HEADER = /^\[(\w+)([^\n]*)\]$/gm;

export function readScene(text: string): Scene {
  const resources: Record<string, string> = {};
  const nodes: SceneNode[] = [];
  const headers = [...text.matchAll(HEADER)];
  headers.forEach((header, index) => {
    const attributes = header[2];
    if (header[1] === "ext_resource") {
      const id = attribute(attributes, "id");
      const path = attribute(attributes, "path");
      if (id && path) {
        resources[id] = path;
      }
      return;
    }
    if (header[1] !== "node") {
      return;
    }
    const bodyStart = header.index + header[0].length;
    const bodyEnd = index + 1 < headers.length ? headers[index + 1].index : text.length;
    const instance = /instance=ExtResource\("([^"]+)"\)/.exec(attributes);
    const groups = /groups=\[([^\]]*)\]/.exec(attributes);
    nodes.push({
      name: attribute(attributes, "name") ?? "",
      type: attribute(attributes, "type"),
      parent: attribute(attributes, "parent") ?? "",
      groups: groups ? [...groups[1].matchAll(/"([^"]*)"/g)].map((group) => group[1]) : [],
      instance: instance ? (resources[instance[1]] ?? null) : null,
      properties: readProperties(text.slice(bodyStart, bodyEnd), resources),
    });
  });
  return { resources, nodes };
}

function attribute(attributes: string, name: string): string | null {
  const match = new RegExp(`\\b${name}="([^"]*)"`).exec(attributes);
  return match ? match[1] : null;
}

function readProperties(body: string, resources: Record<string, string>): Record<string, Value> {
  const properties: Record<string, Value> = {};
  for (const match of body.matchAll(/^([\w/]+) = /gm)) {
    try {
      const [value] = readValueAt(body, match.index + match[0].length);
      properties[match[1]] = plain(value, resources);
    } catch {
      // A value this does not read is left out.
    }
  }
  return properties;
}

// An ExtResource as the file it names, and a PackedStringArray as its strings.
function plain(value: Value, resources: Record<string, string>): Value {
  if (isCall(value, "ExtResource") && typeof value.args[0] === "string") {
    return resources[value.args[0]] ?? null;
  }
  if (isCall(value, "PackedStringArray")) {
    return value.args;
  }
  return value;
}
