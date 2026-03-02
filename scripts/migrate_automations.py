#!/usr/bin/env python3
"""Retrospective migration: add stable IDs to automations that have none.

Safe to run multiple times (idempotent): automations that already have an
id are never touched.

Usage:
  python3 scripts/migrate_automations.py [directory]   # default: cwd
  python3 scripts/migrate_automations.py /config

What it does:
  - Scans automations.yaml, automations/*.yaml, and automations/*.yml (same paths used by
    validate_automations.py).
  - For each automation without an id, generates a stable 13-digit id
    derived from the automation alias using SHA-256.  Running the script
    again on the same file produces the same ids (idempotent).
  - Creates a <filename>.bak backup before writing any changes.
  - Rewrites changed files in place (YAML re-serialised; comments are
    removed as a side-effect of PyYAML round-tripping).
  - Reports duplicate ids and exits with a non-zero code so they can be
    resolved before running validate_automations.py.

Exit codes:
  0  all changes applied (or nothing needed); no duplicates
  1  duplicate ids detected after migration (manual resolution required)
  2  dependency or usage error
"""

import hashlib
import shutil
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required (pip install pyyaml).", file=sys.stderr)
    sys.exit(2)


def generate_id(alias: str, used_ids: set) -> str:
    """Return a stable 13-digit automation id derived from *alias*.

    The id is deterministic: the same alias always produces the same
    first candidate.  If that candidate collides with an already-used id,
    a counter suffix is appended before re-hashing until a free slot is
    found.  The result is always exactly 13 decimal digits.
    """
    key = alias.strip()
    attempt = 0
    while True:
        source = key if attempt == 0 else f"{key}\x00{attempt}"
        digest = int(hashlib.sha256(source.encode()).hexdigest(), 16)
        candidate = str(digest % (10 ** 13)).zfill(13)
        if candidate not in used_ids:
            return candidate
        attempt += 1


def target_files(root: Path) -> list[Path]:
    """Return automation YAML files to migrate (sorted, deterministic order)."""
    files = []
    top_level = root / "automations.yaml"
    if top_level.exists():
        files.append(top_level)
    automations_dir = root / "automations"
    if automations_dir.is_dir():
        files.extend(sorted(automations_dir.glob("*.yaml")))
        files.extend(sorted(automations_dir.glob("*.yml")))
    return files


def migrate_file(file: Path, used_ids: set[str]) -> tuple[int, list[tuple[str, str]]]:
    """Add missing ids to automations in *file*.

    *used_ids* is a shared set of already-allocated ids (both pre-existing
    across all files and newly assigned ones from prior calls).  It is
    updated in place as new ids are generated, preventing cross-file id
    collisions.

    Returns ``(added, duplicates)`` where *added* is the number of ids
    inserted and *duplicates* is a list of ``(id, alias)`` pairs for ids
    that appear more than once within this file (not auto-fixed).
    """
    try:
        data = yaml.safe_load(file.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        print(f"Skipping {file}: YAML parse failed ({exc})", file=sys.stderr)
        return 0, []

    if not isinstance(data, list):
        return 0, []

    added = 0

    for idx, item in enumerate(data):
        if not isinstance(item, dict):
            continue
        if item.get("id"):
            continue  # already has an id — leave it alone

        # Use the explicit alias if present; otherwise fall back to a
        # deterministic synthetic alias based on file path and index.
        alias_str = str(item.get("alias") or "").strip()
        alias = alias_str or f"{file}:{idx}"
        new_id = generate_id(alias, used_ids)
        item["id"] = new_id
        used_ids.add(new_id)  # prevent subsequent calls from reusing this id
        added += 1

    # Within-file duplicate detection (covers pre-existing intra-file duplicates).
    seen: dict = {}
    duplicates = []
    for item in data:
        if not isinstance(item, dict) or not item.get("id"):
            continue
        aid = str(item["id"])
        alias = str(item.get("alias", "<no alias>"))
        if aid in seen:
            duplicates.append((aid, alias))
        else:
            seen[aid] = alias

    if added:
        # Back up before writing
        shutil.copy2(file, file.with_suffix(file.suffix + ".bak"))
        file.write_text(
            yaml.safe_dump(data, sort_keys=False, allow_unicode=True, width=1000),
            encoding="utf-8",
        )

    return added, duplicates


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
    if not root.is_dir():
        print(f"ERROR: '{root}' is not a directory.", file=sys.stderr)
        return 2

    files = target_files(root)
    if not files:
        print("No automation files found. Nothing to migrate.")
        return 0

    # First pass: collect ALL pre-existing ids across every file into a single
    # shared set, and detect any cross-file pre-existing duplicates.
    # used_ids is passed into migrate_file() so newly generated ids never
    # collide with existing ones or with ids assigned to other files.
    used_ids: set[str] = set()
    # all_duplicates collects (fpath, id, alias) tuples in two stages:
    #   1. Cross-file pre-existing duplicates found during this first pass.
    #   2. Intra-file pre-existing duplicates returned by migrate_file().
    all_duplicates: list[tuple] = []

    for file in files:
        try:
            data = yaml.safe_load(file.read_text(encoding="utf-8"))
        except yaml.YAMLError:
            continue
        if not isinstance(data, list):
            continue
        seen_in_pass: set[str] = set()  # tracks first occurrence within this pass
        for idx, item in enumerate(data):
            if not isinstance(item, dict) or not item.get("id"):
                continue
            aid = str(item["id"])
            alias = str(item.get("alias", "<no alias>"))
            if aid in used_ids and aid not in seen_in_pass:
                # id already seen in an earlier file — cross-file duplicate
                all_duplicates.append((file.relative_to(root), aid, alias))
            seen_in_pass.add(aid)
            used_ids.add(aid)

    # Second pass: migrate each file using the shared used_ids set so that
    # newly generated ids are guaranteed unique across all files.
    total_added = 0
    for file in files:
        added, file_dupes = migrate_file(file, used_ids)
        if added:
            print(f"  {file.relative_to(root)}: added {added} id(s)")
        all_duplicates.extend(
            (file.relative_to(root), aid, alias) for aid, alias in file_dupes
        )
        total_added += added

    if total_added:
        print(
            f"\nMigration complete: {total_added} id(s) added across {len(files)} file(s). "
            "Original files backed up as <filename>.bak.\n"
            "Run 'python3 scripts/validate_automations.py' to confirm all checks pass."
        )
    else:
        print("No missing ids found. Nothing to migrate.")

    if all_duplicates:
        print(
            f"\nWARNING: {len(all_duplicates)} duplicate id(s) detected "
            "(not auto-fixed — manual resolution required):"
        )
        for fpath, aid, alias in all_duplicates:
            print(f"  [{fpath}] id='{aid}'  alias='{alias}'")
        print(
            "\nTo fix: edit the listed automations and assign a unique id to each,\n"
            "then rerun 'python3 scripts/validate_automations.py'."
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
