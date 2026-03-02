#!/usr/bin/env python3
"""Tests for scripts/migrate_automations.py."""

import textwrap
from pathlib import Path

import pytest
import yaml

import migrate_automations as ma


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def write_yaml(tmp_path: Path, rel_path: str, content: str) -> Path:
    target = tmp_path / rel_path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(textwrap.dedent(content), encoding="utf-8")
    return target


def read_yaml(path: Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# generate_id
# ---------------------------------------------------------------------------

class TestGenerateId:
    def test_deterministic_same_alias(self):
        """Same alias always produces the same id."""
        id1 = ma.generate_id("My Automation", set())
        id2 = ma.generate_id("My Automation", set())
        assert id1 == id2

    def test_different_aliases_different_ids(self):
        id1 = ma.generate_id("Automation A", set())
        id2 = ma.generate_id("Automation B", set())
        assert id1 != id2

    def test_result_is_13_digits(self):
        aid = ma.generate_id("Test", set())
        assert len(aid) == 13
        assert aid.isdigit()

    def test_collision_avoidance(self):
        """When first candidate is taken, a different id is returned."""
        taken = set()
        first = ma.generate_id("Same Alias", taken)
        taken.add(first)
        second = ma.generate_id("Same Alias", taken)
        assert first != second
        assert len(second) == 13

    def test_collision_second_result_is_deterministic(self):
        """The fallback id is also deterministic."""
        taken = {ma.generate_id("Same Alias", set())}
        id1 = ma.generate_id("Same Alias", set(taken))
        id2 = ma.generate_id("Same Alias", set(taken))
        assert id1 == id2


# ---------------------------------------------------------------------------
# migrate_file – automations with ids untouched
# ---------------------------------------------------------------------------

class TestMigrateFileIdempotent:
    def test_automation_with_id_unchanged(self, tmp_path):
        f = write_yaml(tmp_path, "automations.yaml", """\
            - id: 'existing_id_001'
              alias: '[Test] Already has id'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        added, dupes = ma.migrate_file(f, set())
        assert added == 0
        assert dupes == []
        data = read_yaml(f)
        assert data[0]["id"] == "existing_id_001"

    def test_no_backup_when_nothing_changed(self, tmp_path):
        f = write_yaml(tmp_path, "automations.yaml", """\
            - id: 'has_id'
              alias: '[Test] Fine'
              trigger: []
              action: []
              mode: single
        """)
        ma.migrate_file(f, set())
        assert not f.with_suffix(f.suffix + ".bak").exists()

    def test_second_run_produces_same_ids(self, tmp_path):
        """Running migrate_file twice gives the same id (idempotent)."""
        f = write_yaml(tmp_path, "automations.yaml", """\
            - alias: '[Test] No id'
              trigger: []
              action: []
              mode: single
        """)
        ma.migrate_file(f, set())
        first_id = read_yaml(f)[0]["id"]

        # Remove the backup so a second run doesn't get confused
        bak = f.with_suffix(f.suffix + ".bak")
        if bak.exists():
            bak.unlink()

        ma.migrate_file(f, set())
        second_id = read_yaml(f)[0]["id"]
        assert first_id == second_id


# ---------------------------------------------------------------------------
# migrate_file – missing id cases
# ---------------------------------------------------------------------------

class TestMigrateFileMissingId:
    def test_adds_id_to_automation_without_one(self, tmp_path):
        f = write_yaml(tmp_path, "automations.yaml", """\
            - alias: '[Test] No id'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        added, dupes = ma.migrate_file(f, set())
        assert added == 1
        assert dupes == []
        data = read_yaml(f)
        assert data[0]["id"]
        assert len(str(data[0]["id"])) == 13

    def test_backup_created_on_change(self, tmp_path):
        f = write_yaml(tmp_path, "automations.yaml", """\
            - alias: '[Test] No id'
              trigger: []
              action: []
              mode: single
        """)
        ma.migrate_file(f, set())
        assert f.with_suffix(f.suffix + ".bak").exists()

    def test_adds_ids_to_multiple_automations(self, tmp_path):
        f = write_yaml(tmp_path, "automations.yaml", """\
            - alias: '[Test] First'
              trigger: []
              action: []
              mode: single
            - alias: '[Test] Second'
              trigger: []
              action: []
              mode: single
        """)
        added, _ = ma.migrate_file(f, set())
        assert added == 2
        data = read_yaml(f)
        ids = [str(a["id"]) for a in data]
        assert len(set(ids)) == 2  # unique

    def test_mixed_file_only_fixes_missing(self, tmp_path):
        """Automations with ids keep their original id; only missing ones get new ones."""
        f = write_yaml(tmp_path, "automations.yaml", """\
            - id: 'keep_this_id'
              alias: '[Test] Has id'
              trigger: []
              action: []
              mode: single
            - alias: '[Test] No id'
              trigger: []
              action: []
              mode: single
        """)
        added, _ = ma.migrate_file(f, set())
        assert added == 1
        data = read_yaml(f)
        assert str(data[0]["id"]) == "keep_this_id"
        assert data[1]["id"]

    def test_generated_ids_unique_within_file(self, tmp_path):
        """All generated ids within a single file must be distinct."""
        entries = "\n".join(
            f"- alias: '[Test] Auto {i}'\n  trigger: []\n  action: []\n  mode: single"
            for i in range(20)
        )
        f = write_yaml(tmp_path, "automations.yaml", entries)
        ma.migrate_file(f, set())
        data = read_yaml(f)
        ids = [str(a["id"]) for a in data]
        assert len(ids) == len(set(ids))


# ---------------------------------------------------------------------------
# migrate_file – duplicate detection
# ---------------------------------------------------------------------------

class TestMigrateFileDuplicates:
    def test_duplicate_ids_reported(self, tmp_path):
        f = write_yaml(tmp_path, "automations.yaml", """\
            - id: 'dup_id'
              alias: '[Test] First'
              trigger: []
              action: []
              mode: single
            - id: 'dup_id'
              alias: '[Test] Second'
              trigger: []
              action: []
              mode: single
        """)
        _, dupes = ma.migrate_file(f, set())
        assert len(dupes) == 1
        assert dupes[0][0] == "dup_id"

    def test_duplicate_ids_not_auto_fixed(self, tmp_path):
        """Duplicate ids must be left for the user to resolve."""
        f = write_yaml(tmp_path, "automations.yaml", """\
            - id: 'dup'
              alias: '[Test] A'
              trigger: []
              action: []
              mode: single
            - id: 'dup'
              alias: '[Test] B'
              trigger: []
              action: []
              mode: single
        """)
        ma.migrate_file(f, set())
        data = read_yaml(f)
        # Both automations still have the duplicate id (not changed)
        assert all(str(a["id"]) == "dup" for a in data)


# ---------------------------------------------------------------------------
# target_files
# ---------------------------------------------------------------------------

class TestTargetFiles:
    def test_finds_automations_yaml(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", "")
        assert tmp_path / "automations.yaml" in ma.target_files(tmp_path)

    def test_finds_yaml_in_automations_dir(self, tmp_path):
        write_yaml(tmp_path, "automations/foo.yaml", "")
        names = {f.name for f in ma.target_files(tmp_path)}
        assert "foo.yaml" in names

    def test_returns_empty_when_no_files(self, tmp_path):
        assert ma.target_files(tmp_path) == []


# ---------------------------------------------------------------------------
# Cross-file collision avoidance
# ---------------------------------------------------------------------------

class TestCrossFileCollision:
    def test_same_alias_in_two_files_gets_different_ids(self, tmp_path):
        """Same alias in two different files must produce different ids."""
        f1 = write_yaml(tmp_path, "automations.yaml", """\
            - alias: '[Test] Same Alias'
              trigger: []
              action: []
              mode: single
        """)
        f2 = write_yaml(tmp_path, "automations/other.yaml", """\
            - alias: '[Test] Same Alias'
              trigger: []
              action: []
              mode: single
        """)
        shared_ids: set = set()
        ma.migrate_file(f1, shared_ids)
        ma.migrate_file(f2, shared_ids)
        id1 = read_yaml(f1)[0]["id"]
        id2 = read_yaml(f2)[0]["id"]
        assert id1 != id2, f"Both files received the same id: {id1}"

    def test_shared_set_prevents_collision_on_second_file(self, tmp_path):
        """shared_ids updated by first migrate_file call prevents id reuse."""
        f1 = write_yaml(tmp_path, "automations.yaml", """\
            - alias: '[Test] Unique'
              trigger: []
              action: []
              mode: single
        """)
        f2 = write_yaml(tmp_path, "automations/other.yaml", """\
            - alias: '[Test] Another'
              trigger: []
              action: []
              mode: single
        """)
        shared_ids: set = set()
        ma.migrate_file(f1, shared_ids)
        ma.migrate_file(f2, shared_ids)
        id1 = read_yaml(f1)[0]["id"]
        id2 = read_yaml(f2)[0]["id"]
        # Both ids must be in the shared set after both migrations
        assert id1 in shared_ids
        assert id2 in shared_ids
        assert id1 != id2


# ---------------------------------------------------------------------------
# Regression: existing repo files need no migration
# ---------------------------------------------------------------------------

class TestExistingRepoFiles:
    def test_meta_git_needs_no_migration(self):
        root = Path(__file__).parent.parent
        meta = root / "automations" / "meta_git.yaml"
        if not meta.exists():
            pytest.skip("automations/meta_git.yaml not present")
        added, dupes = ma.migrate_file(meta, set())
        # Restore original from backup if the script wrote one (it shouldn't)
        bak = meta.with_suffix(meta.suffix + ".bak")
        if bak.exists():
            meta.write_bytes(bak.read_bytes())
            bak.unlink()
        assert added == 0, f"meta_git.yaml had {added} automation(s) without id"
        assert dupes == [], f"meta_git.yaml has duplicate ids: {dupes}"
