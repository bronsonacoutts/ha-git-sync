# Prerequisites

This page lists everything you need before setting up ha-git-sync.

## Home Assistant host requirements

| Requirement | Notes |
|---|---|
| **git** | Must be installed on the HA host. The [Advanced SSH & Web Terminal](https://github.com/hassio-addons/addon-ssh) addon includes git. Alternatively, install the [Git](https://github.com/home-assistant/addons/tree/master/git) addon. |
| **bash** | Required by the sync scripts. Available by default in all standard HA addon environments. |
| **curl** | Required if you use the REST API reload option in `hooks/post-merge`. Available in most HA addon terminals. |
| **Internet access** | The HA host must be able to reach `github.com` on port 443 (HTTPS) or port 22 (SSH). |

## Git repository setup

1. **Initialise the config directory as a git repository** (if not already done):

   ```bash
   cd /config
   git init
   git remote add origin git@github.com:<your-org>/<your-repo>.git
   ```

2. **Make the first commit and push**:

   ```bash
   git add -A
   git commit -m "chore: initial HA config"
   git push -u origin main
   ```

## SSH key authentication (recommended)

Automated scripts cannot enter an SSH passphrase interactively. Use a
deploy key or a dedicated SSH key without a passphrase.

1. **Generate a key** (on the HA host or your workstation):

   ```bash
   ssh-keygen -t ed25519 -C "ha-git-sync" -f ~/.ssh/ha_git_sync_ed25519 -N ""
   chmod 600 ~/.ssh/ha_git_sync_ed25519
   ```

   > **Security note**: Keep this key's privileges minimal. Use a **Deploy key**
   > scoped to a single repository rather than a user SSH key where possible.
   > Protect the private key file: ensure `chmod 600` is applied and the key is
   > stored only on the HA host.

2. **Add the public key to GitHub**:
   - As a **Deploy key** (read/write) on the target repository:
     `Your repo → Settings → Deploy keys → Add deploy key`
   - Or as a **user SSH key** under `github.com → Settings → SSH and GPG keys`.

3. **Configure the SSH client** on the HA host (e.g. in `/root/.ssh/config` or
   `/home/user/.ssh/config`):

   ```
   Host github.com
       IdentityFile /root/.ssh/ha_git_sync_ed25519
       IdentitiesOnly yes
         StrictHostKeyChecking yes
         UserKnownHostsFile /root/.ssh/known_hosts
   ```

      Then seed known hosts:

      ```bash
      ssh-keyscan -t ed25519 github.com >> /root/.ssh/known_hosts
      chmod 644 /root/.ssh/known_hosts
      ```

4. **Test the connection**:

   ```bash
   ssh -T git@github.com
   ```

   Expected output: `Hi <username>! You've successfully authenticated…`

## GitHub repository secrets

The `notify-ha.yml` GitHub Actions workflow requires one repository secret.
Set it at: `Your repo → Settings → Secrets and variables → Actions`

| Secret name | Purpose | Format | Used in |
|---|---|---|---|
| `HA_WEBHOOK_URL` | Full URL of the HA webhook endpoint that GitHub Actions POSTs to after each push to `main`. | `https://<your-ha-instance>/api/webhook/<git_sync_webhook_id>` | `.github/workflows/notify-ha.yml` |

## Home Assistant secrets

The pull automation references one HA secret. Add it to `/config/secrets.yaml`.

| Secret name | Purpose | Format | Used in |
|---|---|---|---|
| `git_sync_webhook_id` | Shared secret embedded in the webhook URL. Requests that omit this ID are ignored by HA. | Random URL-safe string ≥ 32 characters | `examples/automations/git_sync_pull.yaml` |

Generate a strong value:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

## Home Assistant external access

The GitHub Actions webhook must reach your HA instance over the internet:

- **Home Assistant Cloud (Nabu Casa)**: Provides a public HTTPS URL automatically. No additional configuration needed.
- **Reverse proxy / port-forwarding**: Ensure TCP 443 is forwarded to HA and a valid TLS certificate is in place.
- **No public access**: Use a self-hosted GitHub Actions runner inside your network instead of the default GitHub-hosted runner.

## Optional post-merge REST token

Default sync scripts do not call the HA REST notification endpoint. If you enable the optional REST API snippet in `hooks/post-merge`, provide `SUPERVISOR_TOKEN` (or another valid bearer token) through your environment and keep it out of tracked files.
