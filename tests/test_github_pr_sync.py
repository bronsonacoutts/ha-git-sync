#!/usr/bin/env python3
"""Tests for scripts/github_pr_sync.py."""

from __future__ import annotations

import argparse
import io
import json
import time
from unittest.mock import MagicMock, patch
from urllib import error as urllib_error

import pytest

import github_pr_sync as gps


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_http_response(body: str, status: int = 200) -> MagicMock:
    """Return a mock that behaves like urllib.response.addinfourl."""
    mock_resp = MagicMock()
    mock_resp.read.return_value = body.encode("utf-8")
    mock_resp.status = status
    mock_resp.__enter__ = lambda s: s
    mock_resp.__exit__ = MagicMock(return_value=False)
    return mock_resp


def _make_http_error(code: int, body: str = "") -> urllib_error.HTTPError:
    return urllib_error.HTTPError(
        url="https://api.github.com/test",
        code=code,
        msg="error",
        hdrs=None,  # type: ignore[arg-type]
        fp=io.BytesIO(body.encode("utf-8")),
    )


def _ns(**kwargs) -> argparse.Namespace:
    """Build an argparse.Namespace from keyword arguments."""
    return argparse.Namespace(**kwargs)


# ---------------------------------------------------------------------------
# api_request
# ---------------------------------------------------------------------------

class TestApiRequest:
    def test_success_returns_parsed_json(self):
        payload = {"number": 42, "url": "https://example.com"}
        mock_resp = _make_http_response(json.dumps(payload))
        with patch("github_pr_sync.request.urlopen", return_value=mock_resp):
            result = gps.api_request("GET", "/repos/owner/repo/pulls")
        assert result == payload

    def test_empty_body_returns_empty_dict(self):
        mock_resp = _make_http_response("  ")
        with patch("github_pr_sync.request.urlopen", return_value=mock_resp):
            result = gps.api_request("GET", "/repos/owner/repo/pulls")
        assert result == {}

    def test_http_error_raises_github_api_error(self):
        with patch(
            "github_pr_sync.request.urlopen",
            side_effect=_make_http_error(404, '{"message":"Not Found"}'),
        ):
            with pytest.raises(gps.GitHubApiError, match="HTTP 404"):
                gps.api_request("GET", "/repos/owner/repo/pulls/99")

    def test_url_error_raises_github_api_error(self):
        with patch(
            "github_pr_sync.request.urlopen",
            side_effect=urllib_error.URLError("connection refused"),
        ):
            with pytest.raises(gps.GitHubApiError, match="connection refused"):
                gps.api_request("GET", "/repos/owner/repo/pulls")

    def test_post_with_payload_sends_json_body(self):
        mock_resp = _make_http_response("{}")
        with patch("github_pr_sync.request.urlopen", return_value=mock_resp) as mock_open:
            gps.api_request("POST", "/repos/owner/repo/pulls", {"title": "t", "body": "b"})
        req = mock_open.call_args[0][0]
        assert req.data is not None
        assert req.get_header("Content-type") == "application/json"

    def test_authorization_header_set_when_token_present(self):
        payload = {}
        mock_resp = _make_http_response(json.dumps(payload))
        with patch("github_pr_sync.TOKEN", "mytoken"):
            with patch("github_pr_sync.request.urlopen", return_value=mock_resp) as mock_open:
                gps.api_request("GET", "/repos/owner/repo/pulls")
        req = mock_open.call_args[0][0]
        assert req.get_header("Authorization") == "Bearer mytoken"


# ---------------------------------------------------------------------------
# ensure_pr
# ---------------------------------------------------------------------------

PR_RESPONSE = {
    "number": 5,
    "html_url": "https://github.com/owner/repo/pull/5",
    "head": {"sha": "deadbeef"},
    "title": "Sync: ha → main",
    "body": "Auto-generated sync PR.",
}


class TestEnsurePr:
    def _args(self, **overrides):
        defaults = dict(
            repo="owner/repo",
            head="ha-sync",
            base="main",
            title="Sync: ha → main",
            body="Auto-generated sync PR.",
        )
        defaults.update(overrides)
        return _ns(**defaults)

    def test_creates_new_pr_when_none_exists(self, capsys):
        args = self._args()
        with patch("github_pr_sync.api_request") as mock_api:
            mock_api.side_effect = [[], PR_RESPONSE]
            rc = gps.ensure_pr(args)

        assert rc == 0
        out = json.loads(capsys.readouterr().out)
        assert out["number"] == 5
        assert out["created"] is True

        # Second call should be a POST
        _, post_call = mock_api.call_args_list
        assert post_call[0][0] == "POST"

    def test_returns_existing_pr_unchanged(self, capsys):
        args = self._args()
        existing = dict(PR_RESPONSE)  # title/body already match
        with patch("github_pr_sync.api_request") as mock_api:
            mock_api.side_effect = [[existing]]
            rc = gps.ensure_pr(args)

        assert rc == 0
        out = json.loads(capsys.readouterr().out)
        assert out["created"] is False
        # Only one API call: the GET
        assert mock_api.call_count == 1

    def test_updates_existing_pr_when_title_differs(self, capsys):
        args = self._args()
        stale = dict(PR_RESPONSE, title="Old title")
        updated = dict(PR_RESPONSE)
        with patch("github_pr_sync.api_request") as mock_api:
            mock_api.side_effect = [[stale], updated]
            rc = gps.ensure_pr(args)

        assert rc == 0
        _, patch_call = mock_api.call_args_list
        assert patch_call[0][0] == "PATCH"

    def test_propagates_api_error(self):
        args = self._args()
        with patch("github_pr_sync.api_request", side_effect=gps.GitHubApiError("boom")):
            with pytest.raises(gps.GitHubApiError, match="boom"):
                gps.ensure_pr(args)


# ---------------------------------------------------------------------------
# wait_for_pr
# ---------------------------------------------------------------------------

class TestWaitForPr:
    def _args(self, **overrides):
        defaults = dict(repo="owner/repo", number=5, timeout=60, interval=1)
        defaults.update(overrides)
        return _ns(**defaults)

    def _pr_state(self, mergeable: bool | None, mergeable_state: str) -> dict:
        return {
            "mergeable": mergeable,
            "mergeable_state": mergeable_state,
            "head": {"sha": "abc123"},
            "html_url": "https://github.com/owner/repo/pull/5",
        }

    def test_returns_0_when_clean(self, capsys):
        pr = self._pr_state(True, "clean")
        with patch("github_pr_sync.api_request", return_value=pr):
            rc = gps.wait_for_pr(self._args())
        assert rc == 0
        out = json.loads(capsys.readouterr().out)
        assert out["mergeable"] is True
        assert out["mergeable_state"] == "clean"

    def test_returns_0_when_has_hooks(self, capsys):
        pr = self._pr_state(True, "has_hooks")
        with patch("github_pr_sync.api_request", return_value=pr):
            rc = gps.wait_for_pr(self._args())
        assert rc == 0

    def test_returns_1_when_dirty(self, capsys):
        pr = self._pr_state(False, "dirty")
        with patch("github_pr_sync.api_request", return_value=pr):
            rc = gps.wait_for_pr(self._args())
        assert rc == 1
        out = json.loads(capsys.readouterr().out)
        assert out["mergeable_state"] == "dirty"

    def test_returns_1_when_draft(self, capsys):
        pr = self._pr_state(False, "draft")
        with patch("github_pr_sync.api_request", return_value=pr):
            rc = gps.wait_for_pr(self._args())
        assert rc == 1

    def test_returns_1_when_unstable(self, capsys):
        pr = self._pr_state(False, "unstable")
        with patch("github_pr_sync.api_request", return_value=pr):
            rc = gps.wait_for_pr(self._args())
        assert rc == 1

    def test_polls_until_mergeable(self, capsys):
        """Returns 0 after transitioning from unknown → clean."""
        pending = self._pr_state(None, "unknown")
        ready = self._pr_state(True, "clean")
        with patch("github_pr_sync.api_request", side_effect=[pending, ready]):
            with patch("github_pr_sync.time.sleep"):
                rc = gps.wait_for_pr(self._args())
        assert rc == 0

    def test_timeout_raises_when_no_response_yet(self):
        """If deadline passes before first response is received, raise."""
        args = self._args(timeout=0, interval=0)
        with patch("github_pr_sync.api_request", side_effect=gps.GitHubApiError("network")):
            with patch("github_pr_sync.time.time", side_effect=[0, 1]):
                with pytest.raises(gps.GitHubApiError):
                    gps.wait_for_pr(args)

    def test_timeout_returns_last_state_when_never_mergeable(self, capsys):
        """If deadline passes while state is known-but-not-mergeable, return 1."""
        pr = self._pr_state(None, "blocked")
        t = [0, 0, 100]  # loop entry, sleep check, timeout-exceeded check

        with patch("github_pr_sync.api_request", return_value=pr):
            with patch("github_pr_sync.time.sleep"):
                with patch("github_pr_sync.time.time", side_effect=t):
                    rc = gps.wait_for_pr(args=self._args(timeout=10, interval=1))

        assert rc == 1
        out = json.loads(capsys.readouterr().out)
        assert out["mergeable_state"] == "blocked"


# ---------------------------------------------------------------------------
# merge_pr
# ---------------------------------------------------------------------------

MERGE_RESPONSE = {
    "merged": True,
    "sha": "cafecafe",
    "message": "Pull Request successfully merged",
}


class TestMergePr:
    def _args(self, **overrides):
        defaults = dict(
            repo="owner/repo",
            number=5,
            method="squash",
            title="chore: sync ha → main",
            message="",
        )
        defaults.update(overrides)
        return _ns(**defaults)

    def test_successful_merge_returns_0(self, capsys):
        with patch("github_pr_sync.api_request", return_value=MERGE_RESPONSE):
            rc = gps.merge_pr(self._args())
        assert rc == 0
        out = json.loads(capsys.readouterr().out)
        assert out["merged"] is True

    def test_not_merged_raises_github_api_error(self):
        not_merged = {"merged": False, "message": "Method Not Allowed"}
        with patch("github_pr_sync.api_request", return_value=not_merged):
            with pytest.raises(gps.GitHubApiError, match="not merged"):
                gps.merge_pr(self._args())

    def test_api_error_propagates(self):
        with patch("github_pr_sync.api_request", side_effect=gps.GitHubApiError("422 conflict")):
            with pytest.raises(gps.GitHubApiError, match="422 conflict"):
                gps.merge_pr(self._args())

    def test_uses_correct_merge_method(self):
        with patch("github_pr_sync.api_request", return_value=MERGE_RESPONSE) as mock_api:
            gps.merge_pr(self._args(method="rebase"))
        payload = mock_api.call_args[0][2]
        assert payload["merge_method"] == "rebase"
