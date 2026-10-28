# Typechecking

Awash uses Godot's built-in GDScript static analysis and script compilation checks.

## Run
From the project root:

```bash
./scripts/quality/typecheck.sh
```

## Notes
- Every `.gd` file under `scripts/` and `tests/` is checked on its own with Godot's
  `--check-only`, which exits non-zero on parse, type and missing-dependency errors.
- The main scene is then booted once, and any `ERROR:` it prints fails the gate. A plain boot
  exits 0 even when a script fails to compile, so the exit code alone cannot be trusted.
- `./scripts/quality/typecheck_selftest.sh` proves the gate can fail: it builds a throwaway fixture
  project and expects a pass when clean and a failure for a parse error, a type error, a missing
  preload and a script error during boot. CI runs it before the typecheck itself.
- Set `GODOT_BIN` if your executable is not named `godot`.
