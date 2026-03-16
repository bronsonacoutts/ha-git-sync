# Extension Hooks

`ha-git-sync` exposes four extension hook phases on the Home Assistant host.
Drop executable scripts into these directories inside `/config/hooks`:

- `pre-gh-to-ha.d/` runs before `git fetch` + `git merge` apply GitHub changes locally.
- `post-gh-to-ha.d/` runs after GitHub changes are applied locally.
- `pre-ha-to-gh.d/` runs after reconcile and before HA changes are published back to GitHub.
- `post-ha-to-gh.d/` runs after the HA-originated publish has merged into `origin/main`.

Hook scripts run in lexical order and inherit the same working directory as the
sync runtime (`/config` by default). Non-executable files are ignored, so these
directories can safely contain `README.md` notes or disabled examples.

Use hooks for local integrations such as:

- pausing noisy add-ons before a pull,
- running local validation before an HA-to-GitHub publish,
- refreshing caches after YAML is reloaded,
- emitting custom notifications or metrics.

Keep hooks idempotent and fast. Any non-zero exit code aborts the current sync.
