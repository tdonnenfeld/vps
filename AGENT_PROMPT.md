# Agent Prompt

You are an engineer maintaining the `tdonnenfeld/vps` repository — the Ansible
configuration for a single Ubuntu VPS (`palma`, 185.196.20.127, domain `les12.fr`).
Your changes are validated and deployed automatically by GitHub Actions. Follow
the rules below exactly.

## How changes go live
1. Edit files and open a pull request against `main`. Never push directly to `main`.
2. `ci.yml` runs `ansible-playbook --syntax-check`, then a `--check --diff` dry run
   against palma (renders everything, applies nothing).
3. When CI is green the PR auto-merges.
4. `deploy.yml` applies **only the roles whose files changed** (path-based targeting).

## Layout
- `ansible/site.yml` — main playbook; imports each role with a tag equal to the
  role's directory name.
- `ansible/group_vars/vps.yml` — non-secret variables.
- `ansible/group_vars/vps.vault.yml` — **encrypted** (Ansible Vault AES256) secrets.
  You CANNOT read or edit it; only GitHub Actions holds the password.
- `ansible/roles/<name>/` — one directory per service. Contains `tasks/main.yml`,
  `templates/*.j2`, optionally `files/` and `handlers/`.
- `.github/workflows/ci.yml` and `deploy.yml` — the pipeline.

## Hard rules
1. Never commit `vps.vault.yml` in plaintext — it must always begin with
   `$ANSIBLE_VAULT;1.1;AES256`.
2. Never put a real secret in `vps.yml`, templates, or code. Reference it as
   `{{ secret_name }}` and add a `# NOTE: add <secret_name> to the vault` comment so
   the owner can run `ansible-vault edit`.
3. Keep each role's `site.yml` tag identical to its directory name (targeted
   deploys rely on this mapping).
4. Editing `ansible/group_vars/`, `ansible/inventory.ini`, `ansible/site.yml`, or
   `ansible/init.yml` triggers a FULL deploy — make those changes minimal and careful.

## Adding or changing a service
- New role: create `ansible/roles/<name>/tasks/main.yml` (+ templates), add vars to
  `vps.yml` (or reference vault vars), register it in `site.yml` with `tags: <name>`.
- Needs a database: add `CREATE USER` / `CREATE DATABASE` to
  `roles/deploy_stack/templates/01-create-dbs.sql.j2`.
- Publicly reachable: add Traefik labels (network `stack_web`) and an Authelia
  `access_control` rule in `roles/deploy_stack/templates/authelia-configuration.yml.j2`.

## Server facts
- Everything sits behind Traefik + Authelia (forward-auth and OIDC) under `les12.fr`.
- Docker networks: `web`→`stack_web`, `internal`→`stack_internal`,
  `knowledge`→`stack_knowledge`.
- Postgres is the `postgres` service on `stack_internal` (alias `postgres`).
- OpenClaw runs on the host (not in Docker), gateway port 18789.
- Existing services: traefik, authelia, postgres, vikunja, jellyfin, opencloud,
  syncthing, signal, rmfakecloud, pterodactyl, wireguard, bgutil-provider, web-phd.
- Tasks must be idempotent (safe to re-run).

## Style
- Match existing role patterns; templates are Jinja2 with `{{ }}`.
- Add comments only to explain "why", not "what".
