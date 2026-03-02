#!/usr/bin/env python3
"""Tests for scripts/validate_automations.py."""

import sys
import textwrap
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
import validate_automations as va  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def write_yaml(tmp_path: Path, rel_path: str, content: str) -> Path:
    """Write *content* to *tmp_path / rel_path* and return the full path."""
    target = tmp_path / rel_path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(textwrap.dedent(content), encoding="utf-8")
    return target


# ---------------------------------------------------------------------------
# is_ui_editable
# ---------------------------------------------------------------------------

class TestIsUiEditable:
    def test_automations_yaml_at_root(self, tmp_path):
        f = write_yaml(tmp_path, "automations.yaml", "")
        assert va.is_ui_editable(f, tmp_path)

    def test_file_in_automations_dir(self, tmp_path):
        f = write_yaml(tmp_path, "automations/git_sync.yaml", "")
        assert va.is_ui_editable(f, tmp_path)

    def test_nested_under_automations_dir(self, tmp_path):
        # sub-subdirectory is NOT considered UI-editable
        f = write_yaml(tmp_path, "automations/subdir/git_sync.yaml", "")
        assert not va.is_ui_editable(f, tmp_path)

    def test_examples_dir_not_ui_editable(self, tmp_path):
        f = write_yaml(tmp_path, "examples/automations/git_sync.yaml", "")
        assert not va.is_ui_editable(f, tmp_path)

    def test_random_yaml_not_ui_editable(self, tmp_path):
        f = write_yaml(tmp_path, "some_other.yaml", "")
        assert not va.is_ui_editable(f, tmp_path)


# ---------------------------------------------------------------------------
# validate_files – passing cases
# ---------------------------------------------------------------------------

class TestValidateFilesPass:
    def test_valid_single_automation(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", """\
            - id: 'abc123'
              alias: '[Test] My automation'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert errors == []

    def test_valid_multiple_automations(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", """\
            - id: 'id_001'
              alias: '[Test] First'
              trigger: []
              condition: []
              action: []
              mode: single
            - id: 'id_002'
              alias: '[Test] Second'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert errors == []

    def test_valid_automation_in_automations_dir(self, tmp_path):
        write_yaml(tmp_path, "automations/git_sync.yaml", """\
            - id: 'git_sync_001'
              alias: '[Git] Sync'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert errors == []

    def test_empty_file_passes(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", "")
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert errors == []


# ---------------------------------------------------------------------------
# validate_files – failure cases
# ---------------------------------------------------------------------------

class TestValidateFilesFail:
    def test_missing_id_produces_error(self, tmp_path):
        """Regression: automation without id must fail validation."""
        write_yaml(tmp_path, "automations.yaml", """\
            - alias: '[Test] No id here'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert len(errors) == 1
        assert "MISSING ID" in errors[0]
        assert "No id here" in errors[0]

    def test_empty_id_produces_error(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", """\
            - id: ''
              alias: '[Test] Empty id'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert len(errors) == 1
        assert "MISSING ID" in errors[0]

    def test_duplicate_id_produces_error(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", """\
            - id: 'dup_id'
              alias: '[Test] First'
              trigger: []
              condition: []
              action: []
              mode: single
            - id: 'dup_id'
              alias: '[Test] Second'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert len(errors) == 1
        assert "DUPLICATE ID" in errors[0]
        assert "dup_id" in errors[0]

    def test_duplicate_id_across_files(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", """\
            - id: 'shared_id'
              alias: '[Test] In root file'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        write_yaml(tmp_path, "automations/other.yaml", """\
            - id: 'shared_id'
              alias: '[Test] In subdir file'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert len(errors) == 1
        assert "DUPLICATE ID" in errors[0]

    def test_multiple_missing_ids_reported(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", """\
            - alias: '[Test] No id first'
              trigger: []
              condition: []
              action: []
              mode: single
            - alias: '[Test] No id second'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        files = va.target_files(tmp_path)
        errors = va.validate_files(files, tmp_path)
        assert len(errors) == 2
        assert all("MISSING ID" in e for e in errors)

    def test_non_ui_editable_path_produces_error(self, tmp_path):
        """File outside automations.yaml / automations/ should flag a PATH ERROR."""
        bad = write_yaml(tmp_path, "examples/automations/git_sync.yaml", """\
            - id: 'example_001'
              alias: '[Test] Example'
              trigger: []
              condition: []
              action: []
              mode: single
        """)
        errors = va.validate_files([bad], tmp_path)
        assert len(errors) == 1
        assert "PATH ERROR" in errors[0]


# ---------------------------------------------------------------------------
# target_files
# ---------------------------------------------------------------------------

class TestTargetFiles:
    def test_finds_automations_yaml(self, tmp_path):
        write_yaml(tmp_path, "automations.yaml", "")
        assert tmp_path / "automations.yaml" in va.target_files(tmp_path)

    def test_finds_yaml_in_automations_dir(self, tmp_path):
        write_yaml(tmp_path, "automations/foo.yaml", "")
        write_yaml(tmp_path, "automations/bar.yaml", "")
        files = va.target_files(tmp_path)
        names = {f.name for f in files}
        assert {"foo.yaml", "bar.yaml"} == names

    def test_returns_empty_when_no_files(self, tmp_path):
        assert va.target_files(tmp_path) == []


# ---------------------------------------------------------------------------
# Regression: existing repo automation files are valid
# ---------------------------------------------------------------------------

class TestExistingRepoFiles:
    def test_automations_meta_git_valid(self):
        """automations/meta_git.yaml must have unique, non-empty ids."""
        root = Path(__file__).parent.parent
        meta = root / "automations" / "meta_git.yaml"
        if not meta.exists():
            pytest.skip("automations/meta_git.yaml not present")
        errors = va.validate_files([meta], root)
        # meta_git.yaml is outside the standard HA UI-editable paths by design;
        # we only care about id uniqueness and presence here.
        id_errors = [e for e in errors if "MISSING ID" in e or "DUPLICATE ID" in e]
        assert id_errors == [], id_errors

    def test_automations_yaml_example_valid(self):
        """automations.yaml.example must have unique, non-empty ids."""
        root = Path(__file__).parent.parent
        example = root / "automations.yaml.example"
        if not example.exists():
            pytest.skip("automations.yaml.example not present")
        data = yaml.safe_load(example.read_text(encoding="utf-8"))
        assert isinstance(data, list), "automations.yaml.example must be a YAML list"
        ids = [str(a.get("id", "")) for a in data if isinstance(a, dict)]
        missing = [i for i, a in enumerate(data) if not a.get("id")]
        assert missing == [], f"automations without id at indices: {missing}"
        assert len(ids) == len(set(ids)), "duplicate ids found in automations.yaml.example"
