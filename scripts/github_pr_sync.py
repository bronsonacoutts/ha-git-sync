#!/usr/bin/env python3
"""Minimal GitHub pull-request helper for HA-hosted sync jobs."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from typing import Any
from urllib import error, parse, request


API_URL = os.environ.get("GITHUB_API_URL", "https://api.github.com").rstrip("/")
TOKEN = (
    os.environ.get("GITHUB_API_TOKEN")
    or os.environ.get("GH_TOKEN")
    or os.environ.get("GITHUB_TOKEN")
)


class GitHubApiError(RuntimeError):
    """Raised when a GitHub API request fails."""


def api_request(method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    body = None
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = request.Request(f"{API_URL}{path}", data=body, headers=headers, method=method)
    try:
        with request.urlopen(req) as response:
            raw = response.read().decode("utf-8")
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise GitHubApiError(f"{method} {path} failed with HTTP {exc.code}: {detail}") from exc
    except error.URLError as exc:
        raise GitHubApiError(f"{method} {path} failed: {exc.reason}") from exc

    if not raw.strip():
        return {}
    return json.loads(raw)


def ensure_pr(args: argparse.Namespace) -> int:
    owner, _repo = args.repo.split("/", 1)
    query = parse.urlencode(
        {
            "state": "open",
            "head": f"{owner}:{args.head}",
            "base": args.base,
        }
    )
    pulls = api_request("GET", f"/repos/{args.repo}/pulls?{query}")
    created = False

    if pulls:
        pr = pulls[0]
        if pr.get("title") != args.title or pr.get("body") != args.body:
            pr = api_request(
                "PATCH",
                f"/repos/{args.repo}/pulls/{pr['number']}",
                {"title": args.title, "body": args.body},
            )
    else:
        pr = api_request(
            "POST",
            f"/repos/{args.repo}/pulls",
            {
                "title": args.title,
                "head": args.head,
                "base": args.base,
                "body": args.body,
                "maintainer_can_modify": True,
            },
        )
        created = True

    print(
        json.dumps(
            {
                "number": pr["number"],
                "created": created,
                "url": pr["html_url"],
                "head_sha": pr["head"]["sha"],
            }
        )
    )
    return 0


def wait_for_pr(args: argparse.Namespace) -> int:
    deadline = time.time() + args.timeout
    last_state = None

    while time.time() <= deadline:
        pr = api_request("GET", f"/repos/{args.repo}/pulls/{args.number}")
        mergeable = pr.get("mergeable")
        mergeable_state = pr.get("mergeable_state")
        last_state = {
            "mergeable": mergeable,
            "mergeable_state": mergeable_state,
            "head_sha": pr["head"]["sha"],
            "url": pr["html_url"],
        }

        if mergeable is True and mergeable_state in {"clean", "has_hooks"}:
            print(json.dumps(last_state))
            return 0

        if mergeable_state in {"dirty", "draft", "unstable"}:
            print(json.dumps(last_state))
            return 1

        time.sleep(args.interval)

    if last_state is None:
        raise GitHubApiError("Timed out before GitHub returned pull-request metadata.")

    print(json.dumps(last_state))
    return 1


def merge_pr(args: argparse.Namespace) -> int:
    result = api_request(
        "PUT",
        f"/repos/{args.repo}/pulls/{args.number}/merge",
        {
            "merge_method": args.method,
            "commit_title": args.title,
            "commit_message": args.message,
        },
    )

    if not result.get("merged"):
        raise GitHubApiError(
            f"Pull request #{args.number} was not merged: {result.get('message', 'unknown error')}"
        )

    print(json.dumps(result))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    ensure = subparsers.add_parser("ensure-pr", help="Create or update the sync PR.")
    ensure.add_argument("--repo", required=True)
    ensure.add_argument("--head", required=True)
    ensure.add_argument("--base", required=True)
    ensure.add_argument("--title", required=True)
    ensure.add_argument("--body", required=True)
    ensure.set_defaults(func=ensure_pr)

    wait = subparsers.add_parser("wait-for-pr", help="Wait until the PR is mergeable.")
    wait.add_argument("--repo", required=True)
    wait.add_argument("--number", required=True, type=int)
    wait.add_argument("--timeout", required=True, type=int)
    wait.add_argument("--interval", required=True, type=int)
    wait.set_defaults(func=wait_for_pr)

    merge = subparsers.add_parser("merge-pr", help="Merge the sync PR.")
    merge.add_argument("--repo", required=True)
    merge.add_argument("--number", required=True, type=int)
    merge.add_argument("--method", required=True, choices=("merge", "squash", "rebase"))
    merge.add_argument("--title", required=True)
    merge.add_argument("--message", required=True)
    merge.set_defaults(func=merge_pr)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        return args.func(args)
    except GitHubApiError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
