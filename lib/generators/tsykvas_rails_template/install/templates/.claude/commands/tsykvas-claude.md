# /tsykvas-claude

Bootstrap and tailor `CLAUDE.md` + `.claude/docs/` to **this** project.

If `CLAUDE.md` doesn't exist yet, run `claude init` first to seed Claude's
own opinionated overview of the host. Then run `bundle exec rake tsykvas:probe`
for a deterministic inventory, integrate the gem's fenced sections into
`CLAUDE.md` (preserving anything Claude wrote outside the fences), and
**generate** host-specific docs (architecture, code-style, commands, testing,
ui-components, etc.) from the gem's reference templates.

Supports `--dry-run` to print a unified diff without writing.

---

## Phase 0a — Bootstrap CLAUDE.md if missing

Check whether `CLAUDE.md` exists at the repo root:

```bash
test -f CLAUDE.md && echo "exists" || echo "missing"
```

- **Exists** → continue to Phase 0b.
- **Missing** → run `claude init` (the built-in Claude Code command, NOT a
  shell command — invoke it the same way the user would). It produces a
  baseline `CLAUDE.md` with project overview / commands / architecture
  inferred from the codebase. Wait for it to complete, then continue.

Why first: every subsequent phase assumes `CLAUDE.md` exists. The gem's
fence-based rewrite preserves user-authored content outside the fences;
running `claude init` first gives us a richer baseline (project name,
commands, conventions Claude inferred) for later phases to wrap fences
around — instead of starting from a blank shell.

If the user invoked `/tsykvas-claude` immediately after `bin/rails g
tsykvas_rails_template:install` (which creates a CLAUDE.md from the gem's
template), `claude init` is skipped — the file already exists.

## Phase 0b — Inventory the host project (deterministic)

Always run the Ruby probe first:

```bash
bundle exec rake tsykvas:probe
```

Output (schema v=2):

```json
{
  "schema_version": 2,
  "ruby_version": "3.4.7",
  "rails_version": "8.0.2",
  "default_branch": "main",
  "api_only": false,
  "engine_host": false,
  "template_engine": "slim",
  "auth": { "method": "devise", "devise": true, ... },
  "authorization": "pundit",
  "has_api_v1": false,
  "has_bootstrap": false,
  "test_framework": "rspec",
  "background_jobs": ["solid_queue"],
  "databases": ["primary"],
  "concept_folders": ["home", "crm"],
  "application_controller_includes": ["Pundit::Authorization", "OperationsMethods"]
}
```

Bind this Hash to `probe`. If `probe.api_only` is true, skip every
HTML-rendering doc. If `probe.engine_host` is true, treat the host as
a Rails Engine (skip Application-only instructions).

If the probe rake task is missing, the host hasn't run
`rails g tsykvas_rails_template:install`. Stop and tell the user.

(After Phase 0a + 0b are done, treat what follows as starting from "Phase 1".)

If the host project has its own `README.md`, read it once for "what is this
app" copy that should seed the project-overview section.

## Phase 1 — Read existing state

For `CLAUDE.md`:

- If it doesn't exist → fresh-install case; you'll write it from
  `.claude/docs/tsykvas_rails_template.md` cross-doc index plus the
  fenced-section template.
- If it exists with `<!-- tsykvas-template:start v=X section=NAME -->` /
  `<!-- tsykvas-template:end -->` markers → you'll **only rewrite content
  inside those markers**. User-authored content above, between, or below
  the fences is sacred.
- If it exists **without** any fences (the user ran `claude init` before
  the gem's install, then ran `:install` which now leaves CLAUDE.md
  alone) → you'll **add** the gem's fenced sections to a sensible position
  (after user's existing content, separated by a horizontal rule).
  Don't touch user prose.

For `.claude/docs/`:

- All 20 docs ship at install (under `.claude/docs/<name>.md`).
- The 3 gem-canonical (`tsykvas_rails_template.md`, `forms.md`,
  `companions.md`) are kept **verbatim**.
- The other 17 may be **refreshed** in fenced sections to reflect the
  host's actual stack (concept folder names, gem versions, default
  branch, locale config). The reference content is project-agnostic
  and ships scrubbed of any specific domain — refreshing is purely
  about swapping in real values where the templates use placeholders.

## Phase 2a — Plan CLAUDE.md fence integration

Target sections (each its own fence in `CLAUDE.md`):

| Fence section | What goes inside |
|---|---|
| `project-overview` | 5–8 bullets pulled from `probe.ruby_version`, `probe.rails_version`, `probe.template_engine`, `probe.auth`, `probe.background_jobs`, `probe.test_framework`, `probe.default_branch`, `probe.databases`. |
| `architecture` | One paragraph; do not mention gems the host doesn't have (e.g. don't claim Bootstrap if `probe.has_bootstrap` is false). |
| `must-know-rules` | Pull from `code-style.md` (after Phase 2b generates it) and **always preserve** the `<Concept>::Form` rule with a link to `.claude/docs/forms.md`. |
| `routing` | Drop rows whose target doc was not generated (e.g. `api-endpoints.md` if `probe.has_api_v1` is false; `modal-refactoring.md` if `probe.has_bootstrap` is false). |
| `slash-commands`, `subagents` | Verbatim from the gem template unless host has added/removed files in `.claude/{commands,agents}/`. |
| `communication` | Verbatim default unless user has a stated preference. |

**Budget: `CLAUDE.md` must end up ≤ 100 lines.** Plan within that budget
before writing anything. Roughly: project-overview ≤ 8 lines, architecture
≤ 8 lines, must-know-rules ≤ 12 lines, routing table 4–10 rows, slash-
commands + subagents tables compact, communication ≤ 4 lines. If a section
needs more, push the overflow into a new `.claude/docs/<topic>.md` and
link it from the routing table. Phase 5 will reject the rewrite if
`wc -l CLAUDE.md` > 100.

## Phase 2b — Plan `.claude/docs/` refresh

All 20 docs already ship at install under `.claude/docs/`. Your job here
is **light refresh**: swap in probe-driven values where the shipped
template uses placeholders. **Do not trim, summarise, or rewrite the
shipped content.** The depth is intentional — that's why it ships.

| Doc | Refresh strategy |
|---|---|
| `architecture.md` | Replace example concept names (`Crm::Property`, `Admin::User`) with the host's actual top-level `concept_folders` if different. |
| `concepts-refactoring.md` | Keep verbatim — pure architecture walkthrough. |
| `routing-and-namespaces.md` | Replace example concept names with host's real ones. Keep the example route patterns. |
| `code-style.md` | Verify references to `.rubocop.yml`, `lefthook.yml`, `.github/workflows/*` resolve to files that actually exist; otherwise mark them with a TODO note. |
| `commands.md` | If `Procfile.dev` exists, point to `bin/dev`. Otherwise note that the watcher must be run separately. Verify test/lint commands match `bin/`. |
| `testing.md` + `testing-examples.md` | Confirm `probe.test_framework` (rspec / minitest). Replace any framework-specific snippets accordingly. |
| `ui-components.md` | Verbatim — Bootstrap is the gem default. |
| `stimulus-controllers.md` | Verbatim if `app/javascript/controllers/` exists; otherwise add a note that Stimulus is not currently wired. |
| `forms.md` | **Keep verbatim** (gem-canonical). |
| `companions.md` | **Keep verbatim** (gem-canonical). |
| `tsykvas_rails_template.md` | **Keep verbatim** (gem-canonical). |
| `authentication.md` | Confirm `probe.auth.method`. If `:devise`, leave as is. If custom/warden/jwt/basic_auth, replace the Devise-specific section with the host's actual auth source. |
| `design-system.md` | Verbatim — generic Bootstrap-default starting point. Host customises to taste. |
| `i18n.md` | Replace the example default-locale references with the host's actual default locale (read from `config/application.rb`). |
| `database.md` | Reflect actual `config/database.yml` adapters (postgres / sqlite / mysql / multi-DB). Replace the `<app_name>` placeholder with the actual host app name. |
| `background-jobs.md` | Confirm `probe.background_jobs`. If SolidQueue, leave as is. If Sidekiq / GoodJob / etc., replace the queue-class references. |
| `security.md` | Reflect host's actual Brakeman / bundler-audit / CSP setup. |
| `deployment.md` | If `config/deploy.yml` exists, replace `<your-app>` placeholders with host app name + image. If only `Dockerfile`, mark Kamal sections as optional. |
| `documentation.md` | Verbatim — generic standards doc. |

For each doc you refresh:

1. Read `.claude/docs/<name>.md` from the host.
2. Identify placeholder patterns (`<your-app>`, `<app_name>`, `Crm::Property`, `Admin::User`) and probe-driven hooks.
3. Substitute real values. Do **not** summarise or trim sample code; the
   shipped depth is intentional and project-agnostic, so it stays.
4. Write back to `.claude/docs/<name>.md`.

For each doc that's already correct (no placeholders to substitute):
mark `keep-verbatim` in the change log.

## Phase 3 — Show the plan and wait for confirmation

If `--dry-run`:

1. Build the new content for every fence section + every doc to generate
   in memory.
2. Print a unified diff (`diff -u` style) for every file that would change.
3. Exit. Do not write.

Otherwise present a compact plan table with **four action types**:

| File | Action | Reason |
|---|---|---|
| `CLAUDE.md` (`project-overview` fence) | rewrite-fence | seed from probe |
| `CLAUDE.md` (no fences yet) | create-fence | install left it untouched; integrate gem sections |
| `.claude/docs/architecture.md` | refresh | swap example concept names for host's actual `concept_folders` |
| `.claude/docs/deployment.md` | refresh | replace `<your-app>` with host service name |
| `.claude/docs/forms.md` | keep-verbatim | gem-canonical |
| … | … | … |

Ask:

> Proceed with N changes? (yes / no / dry-run / diff <file>)

- `yes` → apply.
- `no` → abort.
- `dry-run` → switch to dry-run mode and print the full diff.
- `diff <file>` → show the proposed diff for one file, then re-prompt.

## Phase 4 — Apply

For `CLAUDE.md`:
- If fences exist: replace **only** the content between matching
  `<!-- tsykvas-template:start ... -->` and `<!-- tsykvas-template:end -->`
  markers. Leave content above the first marker, between fences, and below
  the last marker untouched.
- If no fences exist: append the gem's fenced sections after the user's
  existing content, separated by `\n\n---\n\n`. Don't modify user prose.

For `.claude/docs/`:
- `keep-verbatim` files (the 3 gem-canonical + any doc with no placeholders to substitute): no-op.
- `refresh` files: write the placeholder-substituted content to `.claude/docs/<name>.md`. Do not trim or summarise.

## Phase 5 — Verify (mandatory; failure = roll back)

Before declaring success, run all of:

1. **CLAUDE.md ≤ 100 lines (HARD GATE).** Run `wc -l CLAUDE.md`. If
   the result is > 100, the rewrite is rejected — `CLAUDE.md` sits in
   every Claude session's context, so each extra line is a per-prompt
   token tax. Re-plan, re-confirm, then re-apply.
2. **Link integrity.** Every `[…](.claude/docs/X.md)` in `CLAUDE.md`
   resolves to a real file. Every slash command listed exists in
   `.claude/commands/`. Every agent listed exists in `.claude/agents/`.
3. **Fence balance.** Every `tsykvas-template:start` has a matching
   `tsykvas-template:end`. No unclosed or orphan markers.
4. **Code health.** Run `bin/rails zeitwerk:check`.
5. **Probe re-run match.** Re-run the probe. The deterministic fields it
   reports should still match the values that drove this rewrite. (If the
   user edited Gemfile during the run, abort.)

If any check fails, restore the pre-write state from your in-memory
snapshot and report which check failed. **Never leave the repo in a
half-rewritten state.**

## Phase 6 — Self-update

If you discover during this run that the gem's shipped templates have
diverged from what the host needs (e.g., a new must-know rule that should
live in every project), make a note in your memory file under
`memory/feedback_*.md` so future runs of this command in other repos start
from a better baseline.

---

## Constraints

- **Never edit content outside fence markers without explicit user
  confirmation.** Treat unfenced content as user-authored.
- **Never edit `.claude/*.md` or `CLAUDE.md` without the Phase 3 confirmation
  prompt.** No silent runs.
- **Never skip Phase 0.** The probe is the source of truth.
- **`CLAUDE.md` must stay ≤ 100 lines.** Hard rule, enforced at Phase 5.
- Use relative paths for all internal links: `.claude/docs/architecture.md`,
  not absolute URLs.
- Do not commit. The user runs `/pushit` (or `git commit` themselves) when
  they are happy with the diff.
- **Preserve gem-canonical docs verbatim.** `tsykvas_rails_template.md`,
  `forms.md`, and `companions.md` ship with the gem and are the canonical
  reference. If a section feels out of date, that's a gem update (bump the
  gem version), not a project tailoring.
