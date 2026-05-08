# tsykvas_rails_template

Opinionated Rails skeleton + Claude Code tooling, shipped as a gem with three
generators. Drop it into a fresh `rails new` (or an existing app), run the
install generator, and you get the same architectural baseline across every
project: thin controllers, plain-Ruby Operation/Component pattern, ViewComponent
+ Slim, Pundit, and a pre-loaded `.claude/` directory tailored to the host
stack on first run.

## What it ships

Four pillars:

1. **Thin-controller / `endpoint` DSL.** Controllers become one-liners:
   `endpoint Crm::Property::Operation::Index, Crm::Property::Component::Index`.
   The DSL handles HTML / JS / JSON / `format.any` dispatch, flash, redirects,
   and Pundit authorization-check enforcement.
2. **`Base::Operation::Base` + `Base::Operation::Result`.** Plain-Ruby
   alternative to Trailblazer. `authorize!` / `policy_scope` / `notice` /
   `redirect_path=` / `model=` / `run_operation` baked in.
3. **`app/concepts/<feature>/{operation,component}/` layout.** Generators
   scaffold this for you; `config.autoload_paths` is wired automatically.
   `<Concept>::Form` documented for complex forms (virtual attributes,
   sub-operation calls, multi-record submits).
4. **`.claude/` payload.** 4 subagents (`buddy`, `code-reviewer`,
   `security-reviewer`, `tech-lead`), 12 slash commands (including
   `/tsykvas-claude` which audits the host with a deterministic Ruby
   probe and refreshes probe-driven sections in CLAUDE.md and the
   architecture docs), and **20 architecture docs** that ship at install
   under `.claude/docs/` (including the gem-canonical
   `tsykvas_rails_template.md`, `forms.md`, and `companions.md`, plus 17
   stack-tailoring references — `architecture`, `authentication`,
   `background-jobs`, `code-style`, `commands`, `concepts-refactoring`,
   `database`, `deployment`, `design-system`, `documentation`, `i18n`,
   `routing-and-namespaces`, `security`, `stimulus-controllers`,
   `testing`, `testing-examples`, `ui-components`).

## Compatibility

| Component        | Required version |
|------------------|------------------|
| Ruby             | `>= 3.2.0`       |
| Rails            | `>= 7.1`         |
| Pundit           | `>= 2.3`         |
| view_component   | `>= 3.0`         |
| slim-rails       | `>= 3.6`         |
| bootstrap        | `~> 5.3`         |
| dartsass-rails   | `>= 0.5`         |

The CI matrix exercises Ruby 3.2 / 3.3 / 3.4 against Rails 7.1 / 7.2 / 8.0
(9 cells, `fail-fast: false`), plus a smoke job that generates a fresh
Rails app, installs the gem from path, and exercises every generator.

## Quickstart

From a fresh `rails new` to a Bootstrap-styled home page in five commands.

### 1. Create a fresh Rails app

```bash
rails new myapp
cd myapp
```

Verify Ruby (`>= 3.2.0`) and Rails (`>= 7.1`) versions:

```bash
bin/rails -v
ruby -v
```

You also need PostgreSQL running locally — the install generator swaps `sqlite3` → `pg` by default. (Pass `--keep-sqlite` to `:install` to opt out.) `pg_isready` should return success; if not, `brew services start postgresql@16` (or your version).

### 2. Add the gem

```bash
bundle add tsykvas_rails_template
```

For local-path iteration on the gem itself:

```bash
bundle add tsykvas_rails_template --path "/abs/path/to/tsykvas_rails_template"
```

`bundle add` edits `Gemfile`, validates the source, and runs `bundle install` in one step. Don't `echo >> Gemfile` — it duplicates entries silently.

### 3. Run the install generator

```bash
bin/rails g tsykvas_rails_template:install
```

This runs `bundle install` (pulls Bootstrap, dartsass-rails, etc.), `bundle update bootstrap dartsass-rails` (lifts older lock-file pins to latest), `gem install foreman` system-wide if missing (so `bin/dev` works), and `bin/rails dartsass:build` (precompiles Bootstrap to `app/assets/builds/application.css`). The shipped `config/initializers/dartsass.rb` includes `--quiet-deps` and `--silence-deprecation=import` flags, so SCSS warnings don't pollute your terminal.

What lands in your app:

- `app/concepts/{base,home}/...` — base operation/component classes + a working Home example
- `app/controllers/application_controller.rb` — `include Pundit::Authorization` + `include OperationsMethods`
- `app/controllers/home_controller.rb` — one-liner `endpoint Home::Operation::Index, Home::Component::Index`
- `app/policies/{application,home}_policy.rb` — Pundit baseline + Home example
- `config/routes.rb` — `root "home#index"`
- `.claude/{agents,commands,docs}/` (4 subagents, 12 slash commands, **20 docs**) + `CLAUDE.md` (≤ 100 lines, fenced)
- `Gemfile` + `config/database.yml` — `sqlite3` → `pg` swap (use `--keep-sqlite` to opt out)
- Bootstrap 5.3: `bootstrap` + `dartsass-rails` gems, `app/assets/stylesheets/application.bootstrap.scss`, `config/initializers/dartsass.rb` build map, importmap pins for `bootstrap` + `@popperjs/core`, `Procfile.dev` with the SCSS watcher line, and `app/assets/builds/application.css` precompiled. Use `--skip-bootstrap` to opt out.

### 4. Create the database

```bash
bin/rails db:create
bin/rails db:migrate     # nothing to migrate yet, but smoke-checks the connection
```

### 5. Boot the server

```bash
bin/rails server
```

Open <http://localhost:3000>. **Verify it worked:**

- Centered Bootstrap card with shadow.
- Green success alert: "Bootstrap 5.3 is installed and configured…".
- Blue "Documentation" button (`.btn-primary`) + outline secondary "Open a Bootstrap modal".
- Click the modal button → modal slides in, centered. This proves `window.bootstrap` is loaded via importmap.

If the page is unstyled, check:

```bash
ls app/assets/builds/application.css   # should be ~230 KB
bin/rails dartsass:build                # silent — re-runs the compile
```

For live SCSS reload during development, use `bin/dev` (Procfile.dev runs Puma + the dartsass watcher in parallel).

### Optional next steps

```bash
bin/rails g tsykvas_rails_template:companions       # devise + simple_form + rspec stack + ...
bin/rails g tsykvas_rails_template:concept Crm::Property --controller
```

Then in Claude Code, run `/tsykvas-claude` to refresh probe-driven sections in `CLAUDE.md` and `.claude/docs/*` against your actual stack (concept folders, gem versions, default branch, locale config). All 20 docs already shipped at install — `/tsykvas-claude` only swaps placeholders for real values; it does not regenerate or trim content.

## Installation

Use `bundle add` — it edits `Gemfile`, validates the source, and runs
`bundle install` in one step. Don't append the line with `echo >> Gemfile`;
that doesn't dedupe and silently produces a broken Gemfile if you re-run.

**Released gem (after `gem push`):**

```bash
bundle add tsykvas_rails_template
```

**Local-path during development:**

```bash
bundle add tsykvas_rails_template --path "/absolute/path/to/tsykvas_rails_template"
```

If you see `the gem tsykvas_rails_template (>= 0) more than once` from
`bundle install`, you have a duplicate `gem "..."` line in your `Gemfile`
— delete the extra one and re-run `bundle install`.

Then run the install generator:

```bash
bin/rails g tsykvas_rails_template:install
```

The install generator will:

- Copy `app/concepts/base/operation/{base,result}.rb` and
  `app/concepts/base/component/base.rb` into the host
- Copy `app/controllers/concerns/operations_methods.rb` (the `endpoint` DSL)
- Patch `config/application.rb` with
  `config.autoload_paths += %W[#{config.root}/app/concepts]`
- Wire `include Pundit::Authorization` + `include OperationsMethods` into
  `ApplicationController` unconditionally (the `endpoint` DSL falls back to
  `try(:current_user)`, so it works on apps that haven't added Devise yet).
- Generate `app/policies/application_policy.rb` if missing
- Scaffold a Home example concept (`HomeController#index` one-liner +
  `Home::Operation::Index` + `Home::Component::Index` + `HomePolicy` +
  `root "home#index"` route) showing the canonical pattern end-to-end
- Drop the full `.claude/{agents,commands,docs}/` payload and a fenced
  `CLAUDE.md` scaffold (≤ 100 lines, token-economy hard cap)

### Install-time flags

| Flag                          | Effect                                                       |
|-------------------------------|--------------------------------------------------------------|
| `--skip-application-policy`   | Don't create `app/policies/application_policy.rb` if absent  |
| `--skip-autoload-paths`       | Don't patch `config/application.rb`                          |
| `--skip-home-example`         | Don't scaffold the Home concept + `root "home#index"` route  |
| `--keep-sqlite`               | Don't swap `gem "sqlite3"` for `gem "pg"` in the Gemfile     |
| `--skip-bootstrap`            | Don't add `bootstrap` + `dartsass-rails`, SCSS entry, importmap pins, JS import, or `Procfile.dev` watcher |
| `--skip-claude`               | Don't drop `.claude/` payload or `CLAUDE.md`                 |

## Troubleshooting

### `bundle install` says "the gem ... more than once"

Duplicate `gem "..."` line in `Gemfile`. Delete the dupe and re-run `bundle install`. This usually happens when `gem "..."` was appended via `echo >> Gemfile` instead of `bundle add`.

### `bin/dev` says "foreman: command not found"

The install generator auto-installs `foreman` system-wide via `gem install foreman --no-document` if missing. If install couldn't reach rubygems.org (sandboxed env, no internet), run that command manually.

### dartsass-rails prints `@import` deprecation warnings

The shipped `config/initializers/dartsass.rb` passes `--quiet-deps` (silences warnings from gem load paths — Bootstrap 5.3.x's internal SCSS) and `--silence-deprecation=import` (silences the lone warning on the user's own `@import "bootstrap"`). If you regenerated the initializer manually and lost those flags, re-run `bin/rails g tsykvas_rails_template:install --force` — it canonical-rewrites the initializer.

If Rails fails to boot with `SyntaxError` in the dartsass initializer, the file was left in a half-written state. Delete it (`rm config/initializers/dartsass.rb`) and re-run `:install`.

### `bin/rails db:create` fails with "could not connect to server"

The install swaps `sqlite3` → `pg` in `Gemfile` and `config/database.yml`. Either start PostgreSQL (`brew services start postgresql@16`) or pass `--keep-sqlite` to `:install`.

### `bin/rails zeitwerk:check` fails after install

Most likely an existing `app/concepts/<name>` folder doesn't autoload-clean. Either rename the folder so its constant matches Zeitwerk's expectations or remove the autoload patch from `config/application.rb`.

### `/tsykvas-claude` says probe rake task missing

Run `bin/rails g tsykvas_rails_template:install` first — the probe is provided by the gem's railtie, registered when the gem is in `Gemfile`. The slash command also requires `bundle exec rake tsykvas:probe` to be runnable from the host repo root.

### Bootstrap layout doesn't load on first request

Run `bin/rails dartsass:build` once before `bin/rails server`, OR use `bin/dev` (`Procfile.dev` runs the dartsass watcher alongside Puma so SCSS recompiles whenever you edit `application.bootstrap.scss`).

### Live changes to SCSS / JS aren't visible in dev (stale `public/assets/`)

Propshaft serves files from `public/assets/` whenever `public/assets/.manifest.json` exists, completely bypassing live `app/assets/builds/` and `app/javascript/`. A stale directory from a prior `rails assets:precompile` (perhaps run accidentally, or as part of a deploy rehearsal) silently freezes the dev environment.

Fix: delete it. The directory is `.gitignored` by default in Rails 8, so it's safe.

```bash
rm -rf public/assets
```

The install generator does this automatically when it sees `public/assets/` listed in `.gitignore`. If your project has the directory but doesn't `.gitignore` it, the generator leaves it alone (assumed checked-in content).

### Home page renders but Bootstrap modal doesn't open

`window.bootstrap` is wired via importmap (`pin "bootstrap"`) plus an explicit `import * as bootstrap from "bootstrap"; window.bootstrap = bootstrap` block in `app/javascript/application.js`. If you removed the block, the modal trigger button has nothing to call. Re-run `:install --force` to restore it, or add the import manually.

## Usage

### Recommended companions generator

After `:install`, run this to add the recommended gem set
(devise + simple_form + rspec stack + mini_magick + mission_control-jobs +
dotenv-rails) and run their `:install` sub-generators:

```bash
bin/rails g tsykvas_rails_template:companions
```

What gets added (default — all groups):

| Group | Gems | Post-install |
|---|---|---|
| `auth` | `devise`, `omniauth-rails_csrf_protection` | `rails g devise:install` (no User model — run `rails g devise User` yourself when ready) |
| `forms` | `simple_form` | `rails g simple_form:install` (with `--bootstrap` if Probe sees Bootstrap) |
| `images` | `mini_magick` | none (you must `brew install imagemagick` system-wide) |
| `jobs-ui` (gated on `:solid_queue`) | `mission_control-jobs` | mounts `MissionControl::Jobs::Engine` at `/jobs` with admin-only constraint (`User#admin?` via Warden) |
| `test` | `rspec-rails`, `factory_bot_rails`, `faker`, `shoulda-matchers`, `webmock` | `rails g rspec:install`, appends shoulda-matchers + WebMock config to `spec/rails_helper.rb` |
| `dev` | `dotenv-rails` | appends `.env` rules to `.gitignore` |

Opt-out flags: `--skip-auth`, `--skip-forms`, `--skip-images`,
`--skip-jobs-ui`, `--skip-test`, `--skip-dev`. Plus `--skip-bundle` (don't
run `bundle install`) and `--skip-post-install` (Gemfile edits only,
no sub-generators).

Idempotent: re-running won't duplicate Gemfile entries, re-run
sub-generators, or duplicate config injections.

If your stack is incompatible (Tailwind instead of Bootstrap with simple_form,
Minitest instead of RSpec, CanCanCan instead of Pundit), skip `:companions`
entirely. The gem's core (`:install` + `:concept`) is stack-agnostic.

Full per-gem reference: `.claude/docs/companions.md` (after install).

### Concept generator

Scaffold a new feature under `app/concepts/<path>/`:

```bash
bin/rails g tsykvas_rails_template:concept Crm::Property
bin/rails g tsykvas_rails_template:concept Property --controller
bin/rails g tsykvas_rails_template:concept Admin::User --actions index show
```

Resulting tree:

```
app/concepts/crm/property/
├── operation/
│   ├── index.rb       # Crm::Property::Operation::Index
│   ├── show.rb
│   ├── new.rb
│   ├── create.rb      # raises NotImplementedError until you fill in `permit`
│   ├── edit.rb
│   ├── update.rb      # same
│   └── destroy.rb
└── component/
    ├── index.rb       # Crm::Property::Component::Index
    ├── index.html.slim
    ├── show.rb / show.html.slim
    ├── new.rb  / new.html.slim
    └── edit.rb / edit.html.slim
```

The scaffold deliberately raises `NotImplementedError` from the operation's
`_params` method — implement permitted attributes inline, or promote into a
`<Concept>::Form` object as documented in `.claude/docs/forms.md`. Empty
attribute lists fail loud, never silently save default values.

Input validation rejects empty, leading-`::`, or invalid-character names
with `Thor::Error` before any file is touched.

### Claude Code integration

Once `.claude/` is dropped, open the project in Claude Code and run:

```
/tsykvas-claude
```

That slash command:

1. Runs `bundle exec rake tsykvas:probe` to get a deterministic JSON inventory
   of your stack (Ruby/Rails versions, default branch, template engine, auth,
   authorization, API presence, Bootstrap presence, test framework, background
   jobs, multi-DB setup, concept folders, ApplicationController includes,
   API-only flag, Engine-host flag).
2. Reads existing `<!-- tsykvas-template:start ... -->` /
   `<!-- tsykvas-template:end -->` fences in `CLAUDE.md` so re-runs only touch
   gem-owned content; your hand-written sections outside fences are preserved.
3. Builds a refresh plan (placeholder substitutions, no regeneration of
   content), shows you a unified diff (`/tsykvas-claude --dry-run` to
   preview without writing).
4. Applies edits only after you confirm.
5. Verifies link integrity, fence balance, `bin/rails zeitwerk:check`, the
   probe re-run match, and the **100-line cap on `CLAUDE.md`** (token-economy
   hard gate — `CLAUDE.md` sits in every Claude session's context, so each
   line is a per-prompt token cost; deep content lives in
   `.claude/docs/<topic>.md`, linked from the routing table). If any check
   fails, the run rolls back.

All 20 docs ship at install — `/tsykvas-claude` does **not** generate or
trim them. It only swaps placeholder values (e.g. `<your-app>` →
`todo_app`, `<app_name>_<env>` → `todo_app_<env>`) so docs reflect your
real stack. The shipped depth is intentional.

The other 11 slash commands (`/check`, `/code-review`, `/pr-review`,
`/refactor`, `/tests`, `/update-tests`, `/update-docs`, `/update-rules`,
`/pushit`, `/task-sum`, `/docs-create`) and 4 subagents are stack-agnostic
and ready to use immediately.

### Probing the host project

The `Probe` class is usable directly in scripts and CI:

```bash
bundle exec rake tsykvas:probe          # JSON inventory of the host
```

```ruby
TsykvasRailsTemplate::Probe.run         # returns a Hash (schema_version: 2)
```

Sample output:

```json
{
  "schema_version": 2,
  "gem_version": "0.1.0",
  "ruby_version": "3.4.7",
  "rails_version": "8.0.2",
  "default_branch": "main",
  "api_only": false,
  "engine_host": false,
  "template_engine": "slim",
  "auth": {
    "devise": true,
    "omniauth": false,
    "omniauth_openid_connect": false,
    "warden": false,
    "jwt": false,
    "basic_auth": false,
    "custom_current_user": false,
    "method": "devise"
  },
  "authorization": "pundit",
  "has_api_v1": false,
  "has_bootstrap": true,
  "test_framework": "rspec",
  "background_jobs": ["solid_queue"],
  "databases": ["primary"],
  "concept_folders": ["admin", "crm"],
  "application_controller_includes": ["Pundit::Authorization", "OperationsMethods"]
}
```

## End-to-end workflow

The full pipeline from a fresh `rails new` to a productive feature loop:

```
rails new ──> bundle add ──> g install ──> g companions ──> g concept ──> /tsykvas-claude
                                                                  ↓                ↓
                                                       feature work ←── slash commands
                                                                  ↓
                                                  architecture evolves
                                                                  ↓
                                                          /update-rules
                                                                  ↓
                                                              /pushit
```

Step-by-step on a hypothetical `todo_app`:

1. **`rails new todo_app && cd todo_app`.**
2. **Add the gem:** `bundle add tsykvas_rails_template` (or
   `bundle add tsykvas_rails_template --path "..."` during local development).
   Pulls `pundit`, `view_component`, `slim-rails` as transitive deps and
   runs `bundle install` for you.
3. **`bin/rails g tsykvas_rails_template:install`** — copies base classes,
   patches `application.rb`, unconditionally wires `Pundit::Authorization` +
   `OperationsMethods` into `ApplicationController` (the `endpoint` DSL
   uses `try(:current_user)`, so it works with or without Devise), generates
   `ApplicationPolicy` + `HomePolicy`, scaffolds the Home example concept +
   `root "home#index"`, wires Bootstrap 5.3 + dartsass-rails (with silenced
   SCSS deprecation flags) and pre-compiles the CSS bundle, auto-installs
   `foreman` system-wide for `bin/dev`, cleans any stale `public/assets/`
   that would shadow live asset reloads, and drops the full `.claude/`
   payload (4 subagents, 12 slash commands, 20 architecture docs) plus a
   fenced `CLAUDE.md` scaffold. `bin/rails zeitwerk:check` should pass
   cleanly.
4. **`bin/rails db:create`** — install swapped `sqlite3` → `pg` in the
   Gemfile and `config/database.yml`, so the host needs PostgreSQL running
   locally and a database created. (Pass `--keep-sqlite` to `:install` if
   you want to stay on SQLite — then this step is unnecessary.)
5. **`bin/rails server`** then visit `http://localhost:3000` — the Home
   example renders the canonical `endpoint` flow end-to-end (controller →
   operation → `HomePolicy#index?` → component → Slim template), styled
   with Bootstrap (success alert + card + modal). Use `bin/dev` instead
   when you want live SCSS reload (Procfile.dev runs Puma + dartsass:watch
   in parallel).
6. **`bin/rails g tsykvas_rails_template:companions`** (optional) — adds
   recommended gems (devise, simple_form, rspec stack, mini_magick,
   mission_control-jobs, dotenv-rails) and runs their `:install`
   sub-generators. Skip if your stack is incompatible.
7. **`bin/rails g tsykvas_rails_template:concept Crm::Property --controller`**
   — scaffolds operations + components + Slim templates + thin controller.
8. **Open Claude Code and run `/tsykvas-claude`** — probe inventories
   the project, fence-aware rewrite plan, dry-run diff preview, mandatory
   verify phase. **Refreshes** placeholder values in `.claude/docs/` and
   `CLAUDE.md` against the actual stack (concept folder names, gem
   versions, branch names) — content depth is preserved, not regenerated.
9. **Feature work** with slash commands: `/check` before commit, `/refactor`
   to keep code style, `/tests` to write missing specs, `/code-review`
   before PR, `/pushit` to bundle the full pre-push pipeline.
10. **When base classes change:** `/update-rules` diffs them against `main`
    and proposes targeted doc updates with a confirmation gate.

`.claude/docs/tsykvas_rails_template.md` (gem-canonical reference, ~210
lines) is the comprehensive guide Claude reads in any host project. Read
it whenever you want the full picture of how the gem is built.

## Architecture references

These docs ship with the gem; after `bin/rails g tsykvas_rails_template:install`
they appear under `.claude/docs/` in your project.

**Gem-canonical (kept verbatim by `/tsykvas-claude`):**

- **`tsykvas_rails_template.md`** — comprehensive 10-section gem reference (four pillars, generators, Probe, fences, `/tsykvas-claude` workflow, slash commands, gotchas, cross-doc index).
- **`forms.md`** — when to promote `_params` into `<Concept>::Form`.
- **`companions.md`** — per-gem rationale and opt-out matrix for `:companions`.

**Stack-tailoring references (refreshed by `/tsykvas-claude` against probe data):**

- **`architecture.md`** — Concepts Pattern, `endpoint` mechanics, Pundit, Operations / Components / Sortable.
- **`authentication.md`** — Devise wiring, custom registration flows, permitted parameters, redirects after sign-up.
- **`background-jobs.md`** — ActiveJob conventions, naming, recurring tasks, testing.
- **`code-style.md`** — Ruby / Rails style, I18n, git workflow, antipatterns.
- **`commands.md`** — dev / test / lint / deploy commands.
- **`concepts-refactoring.md`** — refactoring legacy controllers into the `endpoint` shape.
- **`database.md`** — multi-DB layout (primary / cache / queue / cable), migrations, enums, schema snapshot.
- **`deployment.md`** — Kamal config, secrets, SolidQueue topology, image / volume conventions.
- **`design-system.md`** — Bootstrap-default tokens, dark-mode switching, component catalog, antipatterns. Customise to your brand.
- **`documentation.md`** — documentation standards, what belongs where.
- **`i18n.md`** — locale-file structure, simple_form conventions, full-key rule, plural forms.
- **`routing-and-namespaces.md`** — REST + non-REST patterns, `crm_*_path` examples, route helpers vs controller fallbacks.
- **`security.md`** — strong parameters, CSP, Brakeman, bundler-audit, importmap audit, secrets.
- **`stimulus-controllers.md`** — Stimulus controller patterns, listener cleanup, Bootstrap-Stimulus integration.
- **`testing.md`** — RSpec setup, what NOT to test, factory traits.
- **`testing-examples.md`** — copy-paste spec templates (operation / component / model / policy / request).
- **`ui-components.md`** — `Base::Component::Btn`, `Table`, `TitleRow`, stat cards, forms, layouts.

## Frontend assumptions

The shipped `OperationsMethods` concern handles `format.js` for Bootstrap
modals (used in the new/edit flow). The Bootstrap JS is feature-checked
(`if (window.bootstrap && window.bootstrap.Modal) { ... }`) so apps without
Bootstrap globally available degrade silently — no crashes. If your stack
doesn't use Bootstrap modals at all, delete or replace the `format.js`
branch in your generated `app/controllers/concerns/operations_methods.rb`.

## Upgrade policy

The gem follows [SemVer](https://semver.org/):

- **MAJOR.0.0** — breaking changes to the *shape* of files the gem ships:
  signatures of `Base::Operation::Base`, public API of the `endpoint` DSL,
  the directory layout of `app/concepts/`, the schema of `Probe`, the fence
  format in `CLAUDE.md.tt`. Per-version migration recipes will appear under
  the `## Per-version migration` heading below.
- **0.MINOR.0** — new features, non-breaking. Existing host apps stay green
  with no changes required.
- **0.0.PATCH** — bug fixes only.

### How to upgrade in general

1. Read the per-version notes below for the version you're moving to.
2. Bump the gem in your `Gemfile`: `gem "tsykvas_rails_template", "~> X.Y"`.
3. `bundle update tsykvas_rails_template`.
4. Re-run `bin/rails g tsykvas_rails_template:install` (it's idempotent —
   won't duplicate `include` directives or `autoload_paths` entries).
5. Open Claude Code and run `/tsykvas-claude --dry-run` to preview any
   doc changes inside fenced sections; apply if the diff looks right.

### Probe schema versions

| Gem version | Probe `schema_version` | What changed |
|---|---|---|
| 0.1.x (initial) | 1 | Initial schema. |
| 0.1.x (current) | 2 | Added `api_only`, `engine_host`, `databases`, broadened `auth` (now a Hash with `method` classification + `warden` / `jwt` / `basic_auth` / `custom_current_user` flags). |

### Per-version migration

#### → 0.1.0 (initial)

No prior version. Just install:

```ruby
# Gemfile
gem "tsykvas_rails_template", "~> 0.1"
```

```bash
bundle install
bin/rails g tsykvas_rails_template:install
```

#### → 0.2.0 (future)

When the first non-patch release ships, this section will list deprecation
warnings, method/file renames with sed-style migration commands,
fence-marker version bumps, and whether re-running the install generator
is mandatory or optional.

If you bump versions and something breaks that isn't covered here, open an
issue with the `before` and `after` `bundle exec rake tsykvas:probe` JSON,
the failing command, and the relevant `Gemfile.lock` diff.

## Development

```bash
bin/setup                               # install dev deps
bundle exec rake                        # rspec + rubocop
bundle exec rake build                  # package the gem
bundle exec rake audit                  # bundler-audit security check
```

## Contributing

Bug reports and pull requests are welcome. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

Before opening a PR, run `bundle exec rake` locally — the same CI matrix
runs on every push.

## License

[MIT](LICENSE.txt). © Yurii Tsykvas.
