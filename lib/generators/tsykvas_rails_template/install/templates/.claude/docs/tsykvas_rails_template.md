# tsykvas_rails_template — gem reference

Read this file when you need to understand how the gem is built, what each
generator does, and how the `.claude/` payload is supposed to be used. It
ships with the gem and lands in every host project's `.claude/docs/`.

This file is **gem-canonical**: `/tsykvas-claude` keeps it verbatim
and never tailors it per-project. If a section feels out of date, that's a
gem update, not a project tailoring — bump the gem and re-run install.

## 1. What the gem is

Four pillars:

1. **Thin-controller / `endpoint` DSL.** Controllers become one-liners:
   `endpoint Crm::Property::Operation::Index, Crm::Property::Component::Index`.
   `OperationsMethods` (the controller concern shipped at
   `app/controllers/concerns/operations_methods.rb`) handles HTML / JS /
   JSON / `format.any` dispatch, flash, redirects, and the Pundit
   authorization-check enforcement.
2. **`Base::Operation::Base` + `Base::Operation::Result`.** Plain-Ruby
   alternative to Trailblazer. Operations subclass `Base::Operation::Base`,
   implement `perform!(params:, current_user:)`, set `self.model = ...` /
   `self.redirect_path = ...`, call `notice(text)` and at least one of
   `authorize!` / `policy_scope` / `skip_authorize` / `skip_policy_scope`.
   `run_operation(OpClass, params)` chains sub-operations; `add_errors` /
   `invalid!` flag failures; `Result#success?` / `failure?` decide flow.
3. **`Base::Component::Base` + `app/concepts/<feature>/{operation,component}/`
   layout.** Components extend `ViewComponent::Base`, take constructor
   kwargs with **specific data names** (`initialize(events:)`, never
   `initialize(model:)`), and live next to a `.html.slim` template.
   `config.autoload_paths += %W[#{config.root}/app/concepts]` is patched
   into `config/application.rb` by the install generator.
4. **`.claude/` payload.** 4 subagents (`buddy`, `code-reviewer`,
   `security-reviewer`, `tech-lead`), 12 slash commands (incl. the
   probe-driven `/tsykvas-claude`), 12 architecture docs incl. this
   file. `CLAUDE.md` at the repo root is the navigation index, capped at
   100 lines for token economy.

## 2. How `:install` works

`bin/rails g tsykvas_rails_template:install` runs these steps in order:

1. `directory app/concepts/base, ...` — copies `app/concepts/base/operation/{base,result}.rb`
   and `app/concepts/base/component/base.rb` into the host.
2. `copy_file app/controllers/concerns/operations_methods.rb` — drops the
   `endpoint` DSL.
3. **Patches `config/application.rb`** with
   `config.autoload_paths += %W[#{config.root}/app/concepts]`. Idempotent —
   re-runs detect the existing line and skip.
4. **Wires `ApplicationController`** unconditionally:
   `inject_into_class` adds `include Pundit::Authorization` and
   `include OperationsMethods`. The `endpoint` DSL itself uses
   `try(:current_user)`, so it works whether or not Devise is mounted —
   `current_user` resolves to `nil` until you add an auth source. Both
   includes are idempotent — re-runs check existing content.
5. `app/policies/application_policy.rb` — generated only if missing.
6. **Home example concept** (`generate_home_example` + `add_root_route`):
   scaffolds `HomeController#index` (one-line `endpoint` call),
   `Home::Operation::Index`, `Home::Component::Index` (+ Slim template),
   `HomePolicy`, and `root "home#index"`. Skipped via `--skip-home-example`
   or if any of the targets already exist.
7. `directory .claude/{agents,commands,docs}` — drops the full Claude
   payload.
8. `template CLAUDE.md.tt → CLAUDE.md` — fenced layout, ≤ 100 lines (skipped
   if `CLAUDE.md` already exists, so `claude init` output stays untouched).

**Opt-out flags:** `--skip-application-policy`, `--skip-autoload-paths`,
`--skip-claude`, `--skip-home-example`, `--keep-sqlite`. Each maps to a
single step above.

## 3. How `:concept` works

`bin/rails g tsykvas_rails_template:concept Crm::Property [--controller] [--actions index show new create]`.

1. **Validates input.** First step is `validate_concept_name`. Regex:
   `/\A[A-Za-z][A-Za-z0-9]*(?:(?:::|\/)[A-Za-z][A-Za-z0-9]*)*\z/`. Empty
   string, leading `::` or `/`, or characters outside the alphabet raise
   `Thor::Error` immediately. No file is touched if validation fails.
2. **Generates 7 operations** by default (subset via `--actions`):
   `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`. Files
   land at `app/concepts/<path>/operation/<action>.rb`.
3. **Generates 4 components** (`index`, `show`, `new`, `edit`) with both
   `<action>.rb` and `<action>.html.slim`.
4. **`--controller`** generates `app/controllers/<path>_controller.rb` with
   thin actions calling `endpoint Op, Component`.
5. **`create.rb` and `update.rb` raise `NotImplementedError`** in their
   `_params` method. This is intentional — `params.require(:foo).permit`
   without an attribute list silently saves empty records, which is worse
   than failing loud. The error message tells you to either inline-permit
   `params.require(:foo).permit(:name, :description)` or promote to a
   `<Concept>::Form` object (see `forms.md`).
6. **Re-run safety.** Thor prompts on file conflicts by default. Don't pass
   `--force` unless you intend to overwrite hand-written code.

## 4. How `:companions` works

`bin/rails g tsykvas_rails_template:companions [--skip-X ...]`. Adds the
recommended companion gems used across the gem author's reference projects
and runs their `:install` sub-generators. Run **after** `:install`.

Groups (default: all enabled):

- `auth` — `devise` + `omniauth-rails_csrf_protection`.
  Post-install: `rails g devise:install`. **Does NOT generate a User model**
  — run `rails g devise User` (or your resource name) yourself when ready.
- `forms` — `simple_form`. Post-install: `rails g simple_form:install`,
  with `--bootstrap` if Probe sees Bootstrap in the host.
- `images` — `mini_magick`. Post-install: nothing (you need ImageMagick
  installed system-wide; the gem doesn't try to install OS packages).
- `jobs-ui` — `mission_control-jobs`, gated on `:solid_queue` being in
  `Gemfile.lock`. Post-install: injects an admin-gated mount into
  `config/routes.rb`:
  ```ruby
  mount MissionControl::Jobs::Engine,
        at: "/jobs",
        constraints: ->(req) {
          user = req.env["warden"]&.user
          user.respond_to?(:admin?) && user.admin?
        }
  ```
  The lambda runs per request, so a missing User model at boot doesn't
  crash. Without `User#admin?` all `/jobs` requests return 404
  (lock-by-default). Assumes Warden-based auth (Devise or compatible);
  swap the constraint for non-Warden stacks.
- `test` — `rspec-rails`, `factory_bot_rails`, `faker` (in `:development, :test`)
  + `shoulda-matchers`, `webmock` (in `:test`). Post-install:
  `rails g rspec:install` + appends shoulda-matchers and WebMock config
  blocks to `spec/rails_helper.rb`.
- `dev` — `dotenv-rails`. Post-install: appends `.env`, `.env.*`, and
  `!.env.example` rules to `.gitignore`.

**Opt-out flags:** `--skip-auth`, `--skip-forms`, `--skip-images`,
`--skip-jobs-ui`, `--skip-test`, `--skip-dev`, plus `--skip-bundle` and
`--skip-post-install` for the tail-end steps.

**Idempotency:** every Gemfile addition checks current contents first; every
`:install` sub-generator skips if its canonical config file already exists;
every config injection (rails_helper.rb, routes.rb, .gitignore) checks for
its marker and bails if present. Re-running is safe.

## 5. How `Probe` + `tsykvas:probe` work

`TsykvasRailsTemplate::Probe.run(root: Dir.pwd)` returns a Hash with:

- `schema_version: 2` — bump if the structure changes.
- `gem_version`, `root` — provenance.
- `ruby_version`, `rails_version`, `default_branch`.
- `api_only` — `true` if `config.api_only = true` in `application.rb`.
- `engine_host` — `true` if app class inherits `Rails::Engine`.
- `template_engine` — `:slim` / `:haml` / `:erb` / `nil` (api_only).
- `auth` — Hash with `devise`, `omniauth`, `omniauth_openid_connect`,
  `warden`, `jwt`, `basic_auth`, `custom_current_user`, plus a coarse
  `method` classification (`:devise`, `:devise_omniauth`, `:warden`,
  `:jwt`, `:basic_auth`, `:custom`, `:none`).
- `authorization` — `:pundit` / `:action_policy` / `:cancancan` / `:none`.
- `has_api_v1` — `true` if routes have `namespace :api` + `:v1`, `scope "api/v1"`,
  or `app/controllers/api/v1/` directory exists.
- `has_bootstrap`, `test_framework`, `background_jobs`, `databases`,
  `concept_folders`, `application_controller_includes`.

Surface: pure-Ruby, no Rails dependency in the class itself. Wrapped in a
Rake task via `TsykvasRailsTemplate::Railtie`:
```bash
bundle exec rake tsykvas:probe   # JSON inventory of the host
```

When in doubt, **read probe output before improvising**. Probe is the
deterministic source of truth that `/tsykvas-claude` consumes; you
should consume it the same way.

## 6. Fence-based idempotency in `CLAUDE.md`

Gem-owned sections in `CLAUDE.md` are wrapped in HTML comments:

```markdown
<!-- tsykvas-template:start v=0.1.0 section=must-know-rules -->
## Must-know rules
...
<!-- tsykvas-template:end -->
```

`/tsykvas-claude` rewrites only the content between matching markers.
User-edited content above the first start marker, between fences, or below
the last end marker is preserved. Section names are stable across versions;
the `v=` tag changes when a section's structure changes meaningfully.

**Hard rule: `CLAUDE.md` ≤ 100 lines.** Token economy — `CLAUDE.md` sits in
every Claude session's context, so each line is a per-prompt token tax.
Push depth into `.claude/docs/<topic>.md` and link from the routing table.
Phase 5 of `/tsykvas-claude` runs `wc -l CLAUDE.md` and rolls back any
rewrite that exceeds 100 lines. The shipped template is currently ~95
lines with ~5 lines of headroom; if you need more, compress, don't grow.

## 7. `/tsykvas-claude` workflow

Six phases:

- **Phase 0** — `bundle exec rake tsykvas:probe`. Source of truth.
- **Phase 1** — Read existing fenced content and unfenced (user-authored)
  content. The latter is sacred.
- **Phase 2** — Plan rewrite per fence section, budgeting against the
  100-line cap. Drop docs that the host doesn't need (e.g.
  `api-endpoints.md` if `probe.has_api_v1` is false).
- **Phase 3** — If `--dry-run`, print unified diff and exit. Otherwise show
  a confirmation table and ask `yes / no / dry-run / diff <file>`.
- **Phase 4** — Apply only inside fences. Never touch unfenced content.
- **Phase 5** (mandatory verify, rollback on failure):
  1. `wc -l CLAUDE.md` ≤ 100 — HARD GATE.
  2. Every internal link resolves.
  3. Every fence has matching start/end.
  4. `bin/rails zeitwerk:check` passes.
  5. Probe re-run matches the values that drove this rewrite.

If any verify check fails, restore the pre-write state from the in-memory
snapshot. Never leave the repo in a half-rewritten state.

## 8. Slash commands and subagents

| Command | Use when |
|---|---|
| `/check` | RSpec/Minitest + RuboCop + i18n-tasks. Run before commit. |
| `/code-review` | Parallel code-reviewer + security-reviewer + tech-lead audit. Run before PR. |
| `/pr-review <num>` | Same audit for a GitHub PR. |
| `/refactor <files>` | Refactor following code-style + architecture docs. |
| `/tests` / `/update-tests` | Audit + write missing specs. |
| `/update-docs` / `/update-rules` | Sync project docs / `.claude/` after meaningful changes. |
| `/pushit` | Full pre-push: docs → rules → safety scan → checks → commit + push. |
| `/task-sum` | Release notes from branch diff. |
| `/docs-create <feature>` | Deep technical doc for a feature. |
| `/tsykvas-claude` | Rebuild `.claude/` + `CLAUDE.md` against host stack. |

| Agent | Use when |
|---|---|
| `buddy` | Plan a new feature; produces `feature_plan.md`. |
| `code-reviewer` | Concepts Pattern + style review. |
| `security-reviewer` | Pundit auth, IDOR, mass assignment, SQL injection. |
| `tech-lead` | Architectural decisions, pre-PR review, design trade-offs. |

## 9. Common gotchas

- **`current_user` is `nil` in operations** → expected on a fresh install
  before you add Devise. `endpoint` uses `try(:current_user)`, so the call
  succeeds and `current_user:` is passed as `nil`. Operations that need a
  real user (anything past the home example) should authorize against the
  Pundit policy and let it deny `nil`. Once Devise is mounted, its
  `current_user` helper shadows the fallback automatically.
- **Bootstrap not loaded but app uses `format.js`** → modal dismiss step
  is feature-checked (`if (window.bootstrap && window.bootstrap.Modal)`),
  so it no-ops gracefully. The rest of the modal-injection JS still runs.
  If you don't use Bootstrap modals at all, replace the `format.js` branch
  in your generated `OperationsMethods`.
- **Concept generator silently overwrites** → it doesn't, unless you pass
  `--force`. Default behavior is Thor's interactive conflict prompt.
- **`mini_magick` works but conversions fail** → ImageMagick isn't
  installed system-wide. `brew install imagemagick` (mac) /
  `apt install imagemagick` (Linux).
- **Multi-DB project** — `Probe.run[:databases]` returns the list. The gem
  itself is stack-agnostic; the docs are if probe drives them.
- **Rails Engine host** (`Probe.run[:engine_host] == true`) — most of the
  install steps still apply; auth wiring may not. The gem hasn't been
  exercised against Engine hosts as much as Application hosts; treat
  results with a probe in hand.

## 10. Cross-doc index (when to read what)

| Doc | When to read |
|---|---|
| `.claude/docs/architecture.md` | Designing a new feature; need the Concepts Pattern in depth. |
| `.claude/docs/forms.md` | Form has virtual attributes, sub-operation calls, or multi-record submits. Promote to `<Concept>::Form`. |
| `.claude/docs/concepts-refactoring.md` | Migrating a legacy controller to the `endpoint` shape. |
| `.claude/docs/companions.md` | Choosing which `:companions` group to install or skip. |
| `.claude/docs/api-endpoints.md` | Building an HTTP API with `api_endpoint` + ParamsAdapters. |
| `.claude/docs/ui-components.md` | UI helpers — `Base::Component::Table`, `modal()`, `header()`. |
| `.claude/docs/stimulus-controllers.md` | Stimulus listener cleanup, action/target naming. |
| `.claude/docs/code-style.md` | Ruby style, I18n key format, git workflow. |
| `.claude/docs/testing.md` + `testing-examples.md` | Spec patterns; what NOT to test. |
| `.claude/docs/commands.md` | Project commands (bin/dev, test, lint). |
| `.claude/docs/modal-refactoring.md` | Migrating raw Bootstrap modals to the `modal()` helper. |
| **this file (`tsykvas_rails_template.md`)** | Big-picture gem reference; how generators / Probe / fences / slash commands fit together. |
