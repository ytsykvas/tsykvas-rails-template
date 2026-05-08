# Changelog

All notable changes to this project will be documented in this file. The format
loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project follows [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.1] - 2026-05-08

### Changed (post real-world test 2026-05-08)

- **All 20 architecture docs now ship at install** (previously only the 3
  gem-canonical ones). The 17 reference templates moved out of
  `templates/.claude/docs/_generated/` into `templates/.claude/docs/`
  alongside the gem-canonical ones, were scrubbed of all sport-project
  specifics (Company / Property / Run Club Heritage palette / `sport`
  Kamal service / Ukrainian-locale assumptions), and ship verbatim.
  Hosts now have full architecture coverage immediately after
  `bin/rails g tsykvas_rails_template:install` — no `/tsykvas-claude`
  step required to see real instructions.
- **`/tsykvas-claude` Phase 2b** is now "refresh probe-driven sections in
  pre-shipped docs", not "instantiate from `_generated/` and trim
  aggressively". The shipped depth is intentional and project-agnostic;
  the slash command swaps placeholders for real values without
  regenerating or shortening content.
- **README expanded.** Quickstart broken into 5 numbered steps with
  per-step "what just happened" annotations + a "Verify it worked"
  checklist (Bootstrap markers visible on home page). Added a full
  Troubleshooting section covering foreman auto-install, dartsass
  silenced flags, broken-initializer recovery, db connection issues,
  zeitwerk failures, and missing-probe diagnostics. Architecture
  references list expanded to all 20 docs with one-line summaries.

### Fixed (post real-world test 2026-05-08)

- **`bundle_command` crash in `:companions`.** Replaced with
  `Bundler.with_unbundled_env { run "bundle install" }`. The companions
  generator now actually completes its bundle step.
- **`uninitialized constant ViewComponent` in `zeitwerk:check`.** Added
  `require "view_component"` to the shipped `Base::Component::Base`. Same
  fix for `Base::Operation::Base` with `require "pundit"`.
- **Install no longer overwrites an existing `CLAUDE.md`.** Skips with a
  yellow warning suggesting `/tsykvas-claude`. Supports the
  `claude init` → install gem → reinit workflow.
- **CI smoke job now runs `bundle install` after the first `:companions`
  invocation** (dropped `--skip-bundle`) so subsequent `bin/rails g` calls
  can boot Rails. Without this, `Bundler.setup` failed on the stale
  `Gemfile.lock` (devise / simple_form / etc. listed in Gemfile but not
  installed).
- **CI test for concept-generator input validation** now grep stdout for
  the expected validation message instead of relying on exit code.
  `bin/rails g` swallows `Thor::Error` exit codes (Rails generators print
  the message but exit `0`), so the previous "expect non-zero on bad
  input" check inverted its own logic and reported the success branch
  every time.

### Changed

- **Install scaffolds a `Home` example concept by default** (controller +
  `app/concepts/home/{operation,component}/` + `root "home#index"` route).
  `bin/rails server` after install shows a working welcome page. New
  `--skip-home-example` flag opts out.
- **Trimmed `.claude/docs/` shipped at install from 13 to 3.** Only the
  gem-canonical docs (`tsykvas_rails_template.md`, `forms.md`,
  `companions.md`) ship by default. The other 10 (architecture, code-style,
  commands, testing, ui-components, stimulus-controllers, concepts-
  refactoring, api-endpoints, modal-refactoring, testing-examples) live
  under `lib/.../install/templates/.claude/docs/_generated/` and get
  instantiated by `/tsykvas-claude` from probe data + actual host
  code. Massive token-economy win for every Claude session in the host
  project.
- `CLAUDE.md.tt` routing table trimmed to 3 rows (the shipped docs).
  `/tsykvas-claude` adds rows when it generates the corresponding
  host-specific docs.
- **`/tsykvas-claude` redesigned** with split Phase 2a (CLAUDE.md
  fence integration — preserves user-authored content outside fences) and
  Phase 2b (host-specific doc generation from `_generated/` reference
  templates with probe-driven gating).

### Added

- **`tsykvas_rails_template:companions` generator** — adds the recommended
  companion gems used across the author's reference projects (devise,
  omniauth-rails_csrf_protection, simple_form, mini_magick,
  mission_control-jobs gated on solid_queue, rspec-rails, factory_bot_rails,
  faker, shoulda-matchers, webmock, dotenv-rails) and runs their
  `:install` sub-generators. Idempotent on re-runs. Per-group opt-out
  flags (`--skip-auth`, `--skip-forms`, etc.) plus `--skip-bundle` and
  `--skip-post-install`.
- **No User model generated** — explicit scope decision; run
  `rails g devise User` yourself when the user schema is ready.
- **MissionControl::Jobs admin-only mount** — auto-injected into
  `config/routes.rb` with a Warden lambda that's robust to a missing
  User model at boot (`req.env["warden"]&.user.respond_to?(:admin?) &&
  user.admin?`). Without `User#admin?` all `/jobs` requests return 404.
- **`.claude/docs/companions.md`** — per-gem reference shipped with the
  gem; documents what each companion does, the `--skip-X` matrix, and
  the MissionControl::Jobs constraint reasoning.
- **`.claude/docs/tsykvas_rails_template.md`** — comprehensive 10-section
  gem reference loaded by Claude in any host project. Covers the four
  pillars, all three generators, Probe + fences, `/tsykvas-claude`
  workflow, slash commands + subagents, common gotchas, and a cross-doc
  index. Treated as gem-canonical: `/tsykvas-claude` keeps it
  verbatim.
- Two new routing-table rows in shipped `CLAUDE.md.tt`:
  `tsykvas_rails_template.md` (big-picture) and `companions.md`.
- 38 new specs in `spec/generators/companions_generator_spec.rb`
  (175 / 175 total).

### Changed

- `:install` generator's `announce_completion` now shows three next
  steps: companions → concept → `/tsykvas-claude`.
- `/tsykvas-claude` Phase 2 plan includes both new docs with
  explicit handling rules (companions = host examples may be tailored;
  tsykvas_rails_template = strictly verbatim).
- README's Usage section starts with the companions generator before the
  concept generator; the README absorbed the previous `WORKFLOW.md` and
  `UPGRADING.md` files (now deleted from the project root).
- `dummy_app` test fixture's Gemfile trimmed to bare essentials so
  companion-generator opt-out tests can verify what's added without
  fixture pollution.

### Removed

- Internal helper markdown files at the project root: `ASSESSMENT.md`,
  `TODO.md`, `WORKFLOW.md`, `UPGRADING.md`. Their useful content was
  consolidated into the README; the rest was internal authoring notes
  (assessment scoring, in-progress TODOs) that don't belong in a public
  gem repo.

## [0.1.0] - 2026-05-07

Initial public release.

### Added

> **Pundit version pin**: `>= 2.3` (no upper bound). Pundit's API has been
> stable since 2.x; we trust SemVer rather than guessing where future
> breakage might land. CI exercises whatever resolves at install time.

#### Core architecture

- `Base::Operation::Base` and `Base::Operation::Result` (plain-Ruby
  alternative to Trailblazer; Pundit-aware via `authorize!` / `policy_scope`
  / `skip_authorize` / `skip_policy_scope`; `notice` / `redirect_path=` /
  `model=` / `run_operation` baked in).
- `OperationsMethods` controller concern shipping the `endpoint Op, Component`
  DSL (HTML / JS / JSON / `format.any` dispatch with feature-checked Bootstrap
  modal handling).
- `Base::Component::Base` (ViewComponent) + `app/concepts/<feature>/{operation,component}/`
  layout (autoloaded via `config.autoload_paths`).

#### Generators

- `rails g tsykvas_rails_template:install` — copies the base classes, patches
  `config/application.rb`, unconditionally wires `Pundit::Authorization` +
  `OperationsMethods` into `ApplicationController` (the `endpoint` DSL uses
  `try(:current_user)`, so it works whether or not Devise is mounted),
  generates `ApplicationPolicy` if missing, scaffolds a Home example concept
  (controller + operation + component + `HomePolicy` + `root "home#index"`),
  drops `.claude/{agents,commands,docs}/` payload + fenced `CLAUDE.md`.
  Idempotent on re-runs.
- `rails g tsykvas_rails_template:concept Crm::Property` — scaffolds CRUD
  operations (with `NotImplementedError`-raising `_params` to fail loud rather
  than silently save defaults), components, Slim templates, and an optional
  thin controller (`--controller`). Validates the concept name (rejects empty,
  leading `::`/`/`, invalid characters).
- Opt-out flags: `--skip-application-policy`, `--skip-autoload-paths`,
  `--skip-claude`, `--skip-home-example`, `--keep-sqlite`.

#### Probe + Claude tooling

- `TsykvasRailsTemplate::Probe` — deterministic Ruby inventory of the host
  Rails app. Detects: Ruby/Rails versions, default git branch, API-only
  configuration, Rails-Engine hosts, template engine (Slim / Haml / ERB),
  auth stack (Devise / OmniAuth / Warden / JWT / BasicAuth / custom
  `current_user`), authorization (Pundit / action_policy / cancancan), API
  v1 presence, Bootstrap presence, test framework, background-job processors
  (SolidQueue / Sidekiq / GoodJob / Delayed Job / Resque / Que),
  multi-database configuration, top-level concept folders, ApplicationController
  includes. Schema-versioned (`SCHEMA_VERSION = 2`).
- `bundle exec rake tsykvas:probe` — Rake task wrapper that prints the JSON
  inventory. Exposed via `TsykvasRailsTemplate::Railtie`.
- 4 subagents: `buddy`, `code-reviewer`, `security-reviewer`, `tech-lead`.
- 12 slash commands: `/check`, `/code-review`, `/pr-review`, `/refactor`,
  `/tests`, `/update-tests`, `/update-docs`, `/update-rules`, `/pushit`,
  `/task-sum`, `/docs-create`, `/tsykvas-claude`.
- 11 architecture docs under `.claude/docs/`.
- Fence-based idempotency in `CLAUDE.md` (gem-owned content lives between
  `<!-- tsykvas-template:start v=X section=NAME -->` and
  `<!-- tsykvas-template:end -->` markers; user-edited content outside fences
  is preserved across re-runs of `/tsykvas-claude`).
- `/tsykvas-claude` workflow: probe-driven inventory, dry-run mode with
  unified diff preview, mandatory verification phase (link integrity, fence
  balance, `bin/rails zeitwerk:check`, probe re-run match) with rollback on
  failure.

#### Quality

- `Form`-object pattern documented in `.claude/docs/forms.md` with explicit
  promotion criteria (virtual attributes, sub-operation calls during
  assignment, multi-record submits).
- 128 RSpec examples (probe edge cases, install generator structure +
  idempotency, concept generator validation + scaffold quality).
- CI matrix: Ruby 3.2 / 3.3 / 3.4 against Rails 7.1 / 7.2 / 8.0 (9 cells,
  `fail-fast: false`).
- CI smoke job: generates a fresh Rails app, installs the gem from path, runs
  both generators, verifies idempotency, runs `bin/rails zeitwerk:check`.

[Unreleased]: https://github.com/ytsykvas/tsykvas-rails-template/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/ytsykvas/tsykvas-rails-template/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/ytsykvas/tsykvas-rails-template/releases/tag/v0.1.0
