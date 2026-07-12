# Linting and Formatting

Awash uses gdtoolkit for linting and formatting checks.

## Install

```bash
python3 -m pip install -r requirements-dev.txt
```

## Run

```bash
./scripts/quality/lint.sh
```

## Notes
- `gdlint` checks style and code quality rules.
- `gdformat --check` enforces formatting without editing files.
