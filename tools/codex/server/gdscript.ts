// Reads the literal values Godot's files hold: a GDScript's consts and plain vars, and a scene's
// properties. Only literals are read; an expression such as `20.0 / 0.15` is left out.

export type Value =
  | number
  | string
  | boolean
  | null
  | { name: string } // a StringName, &"name"
  | { ref: string } // a name defined elsewhere, such as MEAT_PIE or Supplies.MEAT_PIE
  | { call: string; args: Value[] } // preload(...), Vector2i(...)
  | Value[]
  | DictEntry[] // a dictionary keyed by values: { MEAT_PIE: {...} }
  | { [key: string]: Value }; // a dictionary keyed by names: { name = "...", ... }

export interface DictEntry {
  key: Value;
  value: Value;
}

class Unreadable extends Error {}

// A call such as preload("...") or Vector2i(16, 16), by the name called, or any call with none.
export function isCall(value: Value | undefined, call?: string): value is { call: string; args: Value[] } {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const called = (value as { call?: unknown }).call;
  return typeof called === "string" && Array.isArray((value as { args?: unknown }).args) && (call === undefined || called === call);
}

// A StringName, &"name".
export function isName(value: Value | undefined): value is { name: string } {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  return typeof (value as { name?: unknown }).name === "string" && Object.keys(value).length === 1;
}

// A name defined elsewhere, such as MEAT_PIE or Supplies.MEAT_PIE.
export function isRef(value: Value | undefined): value is { ref: string } {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  return typeof (value as { ref?: unknown }).ref === "string" && Object.keys(value).length === 1;
}

// Every top-level const set to a literal, by name.
export function readConsts(script: string): Record<string, Value> {
  return readDeclarations(script, /^const (\w+)\s*(?::\s*[\w.[\]]+\s*)?:?=\s*/gm);
}

// Every top-level var set to a number, string or bool, by name.
export function readVars(script: string): Record<string, Value> {
  const vars = readDeclarations(script, /^var (\w+)\s*(?::\s*[\w.[\]]+\s*)?:?=\s*/gm);
  return Object.fromEntries(
    Object.entries(vars).filter(([, value]) => ["number", "string", "boolean"].includes(typeof value)),
  );
}

function readDeclarations(script: string, declaration: RegExp): Record<string, Value> {
  const found: Record<string, Value> = {};
  for (const match of script.matchAll(declaration)) {
    try {
      const [value, end] = readValueAt(script, match.index + match[0].length);
      if (restOfLineIsBlank(script, end)) {
        found[match[1]] = value;
      }
    } catch (error) {
      if (!(error instanceof Unreadable)) {
        throw error;
      }
    }
  }
  return found;
}

// The value starting at an index, and the index just past it.
export function readValueAt(text: string, start: number): [Value, number] {
  const reader = new Reader(text, start);
  const value = reader.value();
  return [value, reader.at];
}

function restOfLineIsBlank(text: string, at: number): boolean {
  const end = text.indexOf("\n", at);
  const rest = text.slice(at, end === -1 ? undefined : end).trim();
  return rest === "" || rest.startsWith("#");
}

class Reader {
  constructor(
    private readonly text: string,
    public at: number,
  ) {}

  value(): Value {
    this.skip();
    const char = this.text[this.at];
    if (char === '"') {
      return this.string();
    }
    if (char === "&" && this.text[this.at + 1] === '"') {
      this.at += 1;
      return { name: this.string() };
    }
    if (char === "[") {
      return this.array();
    }
    if (char === "{") {
      return this.dictionary();
    }
    const number = /^-?\d+(?:\.\d+)?(?:e-?\d+)?/.exec(this.text.slice(this.at));
    if (number) {
      this.at += number[0].length;
      this.noOperator();
      return Number(number[0]);
    }
    const name = /^[A-Za-z_][\w.]*/.exec(this.text.slice(this.at));
    if (!name) {
      throw new Unreadable();
    }
    this.at += name[0].length;
    if (name[0] === "true" || name[0] === "false") {
      return name[0] === "true";
    }
    if (name[0] === "null") {
      return null;
    }
    this.skip();
    if (this.text[this.at] === "(") {
      this.at += 1;
      return { call: name[0], args: this.list(")") };
    }
    this.noOperator();
    return { ref: name[0] };
  }

  private string(): string {
    let out = "";
    this.at += 1;
    while (this.at < this.text.length && this.text[this.at] !== '"') {
      if (this.text[this.at] === "\\") {
        const next = this.text[this.at + 1];
        out += next === "n" ? "\n" : next === "t" ? "\t" : next;
        this.at += 2;
      } else {
        out += this.text[this.at];
        this.at += 1;
      }
    }
    this.at += 1;
    return out;
  }

  private array(): Value[] {
    this.at += 1;
    return this.list("]");
  }

  private list(close: string): Value[] {
    const items: Value[] = [];
    for (;;) {
      this.skip();
      if (this.text[this.at] === close) {
        this.at += 1;
        return items;
      }
      items.push(this.value());
      this.skip();
      if (this.text[this.at] === ",") {
        this.at += 1;
      } else if (this.text[this.at] !== close) {
        throw new Unreadable();
      }
    }
  }

  // Keyed by names, `{ name = "x" }`, it reads as an object; keyed by values, `{ KEY: x }`, as
  // its entries in order.
  private dictionary(): Value {
    this.at += 1;
    this.skip();
    const named = /^[A-Za-z_]\w*\s*=(?!=)/.test(this.text.slice(this.at));
    const object: Record<string, Value> = {};
    const entries: DictEntry[] = [];
    for (;;) {
      this.skip();
      if (this.text[this.at] === "}") {
        this.at += 1;
        return named ? object : entries;
      }
      if (named) {
        const key = /^([A-Za-z_]\w*)\s*=/.exec(this.text.slice(this.at));
        if (!key) {
          throw new Unreadable();
        }
        this.at += key[0].length;
        object[key[1]] = this.value();
      } else {
        const key = this.value();
        this.skip();
        if (this.text[this.at] !== ":") {
          throw new Unreadable();
        }
        this.at += 1;
        entries.push({ key, value: this.value() });
      }
      this.skip();
      if (this.text[this.at] === ",") {
        this.at += 1;
      } else if (this.text[this.at] !== "}") {
        throw new Unreadable();
      }
    }
  }

  // A literal followed by arithmetic is an expression, which this does not read.
  private noOperator(): void {
    const rest = /^[ \t]*([-+*/%])/.exec(this.text.slice(this.at));
    if (rest) {
      throw new Unreadable();
    }
  }

  // Past whitespace and comments.
  private skip(): void {
    for (;;) {
      const space = /^\s+/.exec(this.text.slice(this.at));
      if (space) {
        this.at += space[0].length;
        continue;
      }
      if (this.text[this.at] === "#") {
        const end = this.text.indexOf("\n", this.at);
        this.at = end === -1 ? this.text.length : end;
        continue;
      }
      return;
    }
  }
}
