// What the Codex holds: the game's enemies, items, characters and Regions.

export interface Codex {
  enemies: Enemy[];
  items: Item[];
  characters: Character[];
  regions: Region[];
}

export interface Encounter {
  region: string;
  description: string;
  visual: string;
}

export interface Sprite {
  sheet: string;
  // One frame's size, or how many frames across and down the sheet is cut into.
  frame?: [number, number];
  grid?: [number, number];
  // Each animation's frames, by index along the sheet.
  animations?: Record<string, number[]>;
}

export interface Enemy {
  id: string;
  name: string;
  boss: boolean;
  planned: boolean;
  category: string;
  size: string;
  movement: string;
  encounters: Encounter[];
  stats: { health: number; experience: number; gold: number } | null;
  drops: { item: string; chance: number }[];
  hits: { name: string; damage: number }[];
  sprite: Sprite | null;
  rooms: { id: string; region: string; count: number }[];
}

export interface Item {
  id: string;
  name: string;
  kind: string;
  planned: boolean;
  description: string;
  effect: string;
  icon: string | null;
  price: number | null;
  caches: { id: string; room: string; count: number }[];
  droppedBy: { enemy: string; chance: number }[];
  lore: string;
}

export interface Character {
  id: string;
  name: string;
  planned: boolean;
  sprite: string | null;
  rooms: string[];
  lines: string[];
  // What its doc says of it, by field.
  details: Record<string, string>;
}

export interface Region {
  id: string;
  name: string;
  colour: string;
  rooms: { id: string; size: [number, number] }[];
  enemies: string[];
  caches: { id: string; room: string; kind: string; count: number }[];
  restPoints: string[];
  shops: string[];
  bosses: string[];
}
