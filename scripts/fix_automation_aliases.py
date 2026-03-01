#!/usr/bin/env python3
import re
import sys
from pathlib import Path

try:
    import yaml
except Exception:
    print("PyYAML is required (pip install pyyaml).")
    sys.exit(2)


ALIAS_PATTERN = re.compile(r"^\[[^\]]+\]\s+.+")


def to_title(text: str) -> str:
    tokens = re.split(r"(\s+)", text.strip())
    normalized = []
    for token in tokens:
        if token.isspace() or token == "":
            normalized.append(token)
            continue
        if token.isupper() and len(token) <= 4:
            normalized.append(token)
        else:
            normalized.append(token.capitalize())
    return "".join(normalized).strip()


def normalize_alias(alias: str | None, item: dict, area: str) -> str:
    base = (alias or "").strip()
    if not base:
        base = str(item.get("id", "Automation")).strip() or "Automation"
    base = re.sub(r"^\[[^\]]+\]\s*", "", base).strip()
    base = re.sub(r"\s+", " ", base)
    base = to_title(base)
    if not base:
        base = "Automation"
    return f"[{area}] {base}"


def target_files(root: Path) -> list[Path]:
    files: list[Path] = []
    top_level = root / "automations.yaml"
    if top_level.exists():
        files.append(top_level)

    automations_dir = root / "automations"
    if automations_dir.is_dir():
        files.extend(sorted(automations_dir.glob("*.yaml")))
        files.extend(sorted(automations_dir.glob("*.yml")))

    return files


def correct_file(file: Path) -> bool:
    try:
        data = yaml.safe_load(file.read_text(encoding="utf-8"))
    except Exception as ex:
        print(f"Skipping {file}: parse failed ({ex})")
        return False

    if not isinstance(data, list):
        return False

    if file.name == "automations.yaml":
        area = "Automation"
    else:
        area = re.sub(r"[_-]+", " ", file.stem).strip().title() or "Automation"

    changed = False
    for item in data:
        if not isinstance(item, dict):
            continue
        alias = item.get("alias")
        if isinstance(alias, str) and ALIAS_PATTERN.match(alias.strip()):
            continue
        item["alias"] = normalize_alias(alias if isinstance(alias, str) else None, item, area)
        changed = True

    if changed:
        file.write_text(
            yaml.safe_dump(data, sort_keys=False, allow_unicode=True, width=1000),
            encoding="utf-8",
        )

    return changed


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
    files = target_files(root)
    if not files:
        print("No automation files found.")
        return 0

    changed_files = []
    for file in files:
        if correct_file(file):
            changed_files.append(file)

    if changed_files:
        print("Updated alias names in:")
        for file in changed_files:
            print(f" - {file}")
    else:
        print("No alias corrections required.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
