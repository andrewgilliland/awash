# Typechecking

Awash uses Godot's built-in GDScript static analysis and script compilation checks.

## Run
From the project root:

```bash
./scripts/quality/typecheck.sh
```

## Notes
- This runs a headless Godot compile pass.
- It catches parse and type-analysis errors early.
- Set `GODOT_BIN` if your executable is not named `godot`.
