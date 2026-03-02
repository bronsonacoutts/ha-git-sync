#!/usr/bin/env python3
"""Validate Home Assistant automation YAML files.

Checks performed on all automation YAML files found under the given root:
  1. Every automation must have an 'id' field.
  2. No two automations may share the same id (duplicate detection).
  3. Automation files must be stored in a HA UI-editable location:
        <root>/automations.yaml  OR  <root>/automations/*.yaml  OR  <root>/automations/*.yml

Usage:
  python3 scripts/validate_automations.py [directory]   # default: cwd
  python3 scripts/validate_automations.py /config

Exit codes:
  0  all checks passed
  1  one or more validation errors found
  2  dependency or usage error
"""

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required (pip install pyyaml).", file=sys.stderr)
    sys.exit(2)

# Directories / filenames that are considered UI-editable in a standard HA setup.
# automations.yaml at the config root, or any *.yaml under automations/.
_UI_EDITABLE_PARENT_NAMES = {"automations"}
_UI_EDITABLE_FILENAMES = {"automations.yaml"}


def is_ui_editable(file: Path, root: Path) -> bool:
    """Return True when *file* is in a HA UI-editable automation location."""
    try:
        rel = file.relative_to(root)
    except ValueError:
        return False
    parts = rel.parts
    if len(parts) == 1 and parts[0] in _UI_EDITABLE_FILENAMES:
        return True
    if len(parts) == 2 and parts[0] in _UI_EDITABLE_PARENT_NAMES:
        return True
    return False


def target_files(root: Path) -> list[Path]:
    """Return automation YAML files to validate (sorted, deterministic order)."""
    files: list[Path] = []
    top_level = root / "automations.yaml"
    if top_level.exists():
        files.append(top_level)
    automations_dir = root / "automations"
    if automations_dir.is_dir():
        files.extend(sorted(automations_dir.glob("*.yaml")))
        files.extend(sorted(automations_dir.glob("*.yml")))
    return files


def validate_files(files: list[Path], root: Path) -> tuple[list[str], int]:
    """Validate a list of YAML files.

    Returns ``(errors, total_automation_count)`` where *errors* is a list of
    error strings and *total_automation_count* is the number of automation
    entries found across all files (used for the success summary).
    """
    errors: list[str] = []
    seen_ids: dict[str, str] = {}  # id -> "file:index" for duplicate reporting
    total = 0

    for file in files:
        # Check UI-editable path
        if not is_ui_editable(file, root):
            errors.append(
                f"PATH ERROR: '{file.relative_to(root)}' is not a HA UI-editable "
                "automation location. Automations must be in 'automations.yaml' or "
                "the 'automations/' directory so they can be edited from the HA UI."
            )

        # Parse YAML (register !secret as a plain-string constructor so the
        # validator can parse files that reference HA secrets.yaml values).
        try:
            loader = yaml.SafeLoader
            loader.add_constructor(
                "!secret",
                lambda ldr, node: ldr.construct_scalar(node),
            )
            data = yaml.load(file.read_text(encoding="utf-8"), Loader=loader)
        except yaml.YAMLError as exc:
            errors.append(f"YAML ERROR: '{file}': {exc}")
            continue

        if data is None:
            continue  # empty file – not an error here
        if not isinstance(data, list):
            errors.append(
                f"FORMAT ERROR: '{file}' must contain a YAML list of automations, "
                f"got {type(data).__name__}."
            )
            continue

        for idx, item in enumerate(data):
            if not isinstance(item, dict):
                continue
            loc = f"{file.relative_to(root)}[{idx}]"
            automation_id = item.get("id")

            # Check 1: id must be present and non-empty
            if not automation_id:
                alias = item.get("alias", "<no alias>")
                errors.append(
                    f"MISSING ID: automation #{idx} (alias: '{alias}') in "
                    f"'{file.relative_to(root)}' has no 'id' field. "
                    "Every automation needs a stable, unique id so it remains "
                    "editable from the Home Assistant UI."
                )
                continue

            automation_id = str(automation_id)

            # Check 2: id must be unique
            if automation_id in seen_ids:
                errors.append(
                    f"DUPLICATE ID: id '{automation_id}' in '{loc}' is already "
                    f"used by '{seen_ids[automation_id]}'. "
                    "Each automation must have a unique id."
                )
            else:
                seen_ids[automation_id] = loc
            total += 1

    return errors, total


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
    if not root.is_dir():
        print(f"ERROR: '{root}' is not a directory.", file=sys.stderr)
        return 2

    files = target_files(root)
    if not files:
        print("No automation files found. Nothing to validate.")
        return 0

    errors, total = validate_files(files, root)

    if errors:
        print(f"Automation validation FAILED ({len(errors)} error(s) found):\n")
        for err in errors:
            print(f"  {err}")
        print(
            "\nFix the errors above, then rerun: "
            "python3 scripts/validate_automations.py"
        )
        return 1

    print(
        f"Automation validation passed: {total} automation(s) in "
        f"{len(files)} file(s) — all have unique ids and are in UI-editable locations."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
