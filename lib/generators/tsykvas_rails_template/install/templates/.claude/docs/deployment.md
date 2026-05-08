# Deployment (Kamal)

The app deploys via **Kamal** (`config/deploy.yml`). Single web server runs Puma + SolidQueue + the Thruster proxy in one container.

## Where things live

```
config/deploy.yml         # Service config — servers, registry, env, volumes, builder
.kamal/secrets            # Pulls secrets from local env / 1Password (NEVER raw creds)
.kamal/hooks/             # Lifecycle hooks (pre-build, post-deploy, ...) — all .sample by default
Dockerfile                # Production image
config/master.key         # NEVER committed — used to decrypt config/credentials.yml.enc
```

## Service overview

From `config/deploy.yml`:

- **Service name**: `<your-app>` (set in `config/deploy.yml` — match the host app's name)
- **Image**: `your-user/<your-app>` (replace `your-user` with your container registry user before first deploy)
- **Servers**: web servers under `servers.web`
- **SSL**: Let's Encrypt via Kamal proxy (`proxy.ssl: true`)
- **Volumes**: `app_storage:/rails/storage` for Active Storage (rename to match your service)
- **Builder arch**: `amd64`
- **SolidQueue runs in Puma**: `SOLID_QUEUE_IN_PUMA=true` (single-server setup). Split it onto `servers.job` once you scale.

## Secrets

```bash
.kamal/secrets    # Resolves at deploy time, never holds raw secrets
```

Current setup pulls:
- `KAMAL_REGISTRY_PASSWORD` from local env
- `RAILS_MASTER_KEY` from `config/master.key`

To add a new secret:

1. Add the variable name to `.kamal/secrets` and resolve it (env, 1Password, file).
2. Reference it under `env.secret:` in `config/deploy.yml`.
3. The container will receive it as an env var at runtime.

**Never** put raw credentials in `config/deploy.yml` or `.kamal/secrets` — both are committed.

## Common commands

```bash
bin/kamal setup              # First-time setup (one-shot per server)
bin/kamal deploy             # Build + push image + reload containers
bin/kamal redeploy           # Redeploy without rebuilding
bin/kamal rollback           # Rollback to the previous version
bin/kamal logs -f            # Tail logs (alias defined in deploy.yml)
bin/kamal console            # Open a Rails console on the server
bin/kamal shell              # Bash shell on the server
bin/kamal dbc                # Open a dbconsole

bin/kamal app exec ...       # Run an ad-hoc command in the app container
bin/kamal proxy ...          # Manage the Kamal proxy container
```

`config/deploy.yml.aliases` defines `console`, `shell`, `logs`, `dbc` as shortcuts.

## Build & release flow

1. `bin/kamal deploy` builds the image locally (or via remote builder if configured).
2. Pushes to the registry.
3. Triggers `pre-deploy` hooks (none by default — `.sample` files).
4. Runs `db:prepare` inside the app container (handled by Rails on boot).
5. Replaces running containers.
6. Triggers `post-deploy` hooks.

Bridging in-flight requests across asset versions: `asset_path: /rails/public/assets` (Kamal copies the new and old asset directories so neither generation 404s during the swap).

## Lifecycle hooks

`.kamal/hooks/` ships with samples:

- `pre-build` — before the image is built (e.g. compile assets externally)
- `pre-connect` — before Kamal connects to servers
- `pre-deploy`, `post-deploy` — around the deploy
- `pre-app-boot`, `post-app-boot` — around the app container start
- `pre-proxy-reboot`, `post-proxy-reboot` — around the Kamal proxy

Drop the `.sample` extension to enable a hook. They are shell scripts run from the deploy machine.

## Rollback strategy

```bash
bin/kamal rollback           # Reverts to previous image version
```

Rollbacks are fast (just swap container images), but **migrations are not auto-reverted** — if you rolled forward a destructive migration, you need to manually fix the schema before rolling back.

For destructive migrations, prefer the two-step pattern:
1. Deploy a release that *adds* the new column / table without removing the old one.
2. Backfill data + switch reads/writes.
3. Deploy a follow-up release that drops the old column.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every PR:

- `bin/brakeman --no-pager`
- `bin/importmap audit`
- `bin/rubocop`
- `bundle exec rspec` (against PostgreSQL 16)

All four must pass before merge. CI does NOT auto-deploy — production deploys are manual via `bin/kamal deploy`.

## Environment variables

Set in `config/deploy.yml` under `env.clear` (visible) or `env.secret` (resolved from `.kamal/secrets`):

- `RAILS_MASTER_KEY` (secret) — decrypts credentials
- `SOLID_QUEUE_IN_PUMA=true` — runs queue inline with web
- `JOB_CONCURRENCY` — number of SolidQueue processes (default 1)
- `WEB_CONCURRENCY` — number of Puma workers (default 1)
- `DB_HOST` — when using an external Postgres
- `RAILS_LOG_LEVEL` — defaults to `info`

In development, use `.env` (loaded by `dotenv-rails`).

## Adding a new server

1. Add the IP under `servers.web` in `config/deploy.yml`.
2. Run `bin/kamal setup` against that server (one-time).
3. Run `bin/kamal deploy`.

Once you have multiple web servers, **move SolidQueue to a dedicated `servers.job` host** (set `SOLID_QUEUE_IN_PUMA=false` and use `cmd: bin/jobs`). Otherwise jobs run on every web box and double-execute.

## Anti-patterns

- ❌ Committing `config/master.key`.
- ❌ Hardcoding secrets in `config/deploy.yml` or `.kamal/secrets`.
- ❌ `kamal redeploy` after a schema change without re-running migrations (use `deploy`).
- ❌ Running `bin/kamal deploy` from a branch with uncommitted changes.
- ❌ Force-pushing to `main` (CI gates production-bound code).
- ❌ Multi-host deploys with `SOLID_QUEUE_IN_PUMA=true` (jobs double-execute).
