# Review

How to review a pull request in Awash, for people and agents alike. Read `GLOSSARY.md` for the
domain words and `docs/specs/` for the rules the game must keep.

## What counts as a finding

A finding is a behaviour that is wrong now or will break, backed by evidence: a `file:line` in this
PR, plus the spec rule, test or call path it breaks. The strongest evidence is a test in `tests/`
that fails against the PR. Read the code a name points to before claiming what it does.

Look hardest for these, the ways Awash has broken before:

- **Spec drift**: the Player controller, Player rig or Run state no longer matches its spec or
  `GLOSSARY.md`, or the spec and the code now disagree.
- **Broken wiring**: a renamed or moved node, a changed `NodePath`, an `@onready` path, or a
  `%UniqueName` that a script or test still uses the old way.
- **Incomplete tables**: a Player state without a rig row, a sword animation whose offsets and
  frames differ in count, a menu button without its Panel.
- **Tests that pass by accident**: a test that never sees the code it names fail. Watch the
  headless runner: nodes are outside the tree during `_init`, autoloads are absent, and assets
  load only after the `.godot` import.
- **Gate weakening**: a change to `.github/`, `.githooks/` or `scripts/quality/` that lets a red
  check pass.

## Severity

- **Important**: wrong behaviour, a broken gate, or a test that cannot fail. Blocks merge.
- **Nit**: a real but minor improvement. At most three per review.
- **Pre-existing**: a bug the PR did not introduce. Report it, and leave it for its own PR.

Formatting, naming taste and cleanup belong to `gdlint`, `gdformat` and the author; leave them out.

## Skip

`assets/`, `docs/story/`, `docs/characters/`, `docs/enemies/`, `docs/items/`, `docs/setting/`,
`*.aseprite`, `*.uid`, `*.import`.

## The summary

Start with the count of Important findings. When there are none, say so in one line.
Every finding is answered before merge: fixed, or its thread resolved with a reason.
