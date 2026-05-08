Check if `.claude/docs/` or `CLAUDE.md` need updating after changes to base classes, application controller, or policies.

## Step 1: Detect changes to watched files

Check if any of these files were modified:

```bash
git diff main --name-only -- \
  app/concepts/base/ \
  app/controllers/concerns/operations_methods.rb \
  app/controllers/application_controller.rb \
  app/policies/application_policy.rb \
  app/policies/admin/base_policy.rb \
  app/policies/crm/base_policy.rb \
  app/policies/screener/base_policy.rb \
  2>&1
```

If on `main` with uncommitted changes:

```bash
git diff --name-only -- \
  app/concepts/base/ \
  app/controllers/concerns/operations_methods.rb \
  app/controllers/application_controller.rb \
  app/policies/application_policy.rb \
  app/policies/admin/base_policy.rb \
  app/policies/crm/base_policy.rb \
  app/policies/screener/base_policy.rb \
  2>&1
git diff --cached --name-only -- \
  app/concepts/base/ \
  app/controllers/concerns/operations_methods.rb \
  app/controllers/application_controller.rb \
  app/policies/application_policy.rb \
  app/policies/admin/base_policy.rb \
  app/policies/crm/base_policy.rb \
  app/policies/screener/base_policy.rb \
  2>&1
```

**If none of these files changed — stop here. No action needed.**

## Step 2: Understand what changed

Read the diffs for each changed file:

```bash
git diff main -- <file> 2>&1
```

Understand what was added, removed, or modified in terms of:

- New methods or method signatures
- Changed behavior of existing methods
- New conventions or patterns
- Removed or deprecated features

## Step 3: Audit current rules

Read the relevant doc files and `CLAUDE.md`. Map each change to the doc file it affects:

| Changed file | Doc file |
|---|---|
| `app/concepts/base/operation/base.rb` | `.claude/docs/architecture.md`, `.claude/docs/concepts-refactoring.md` |
| `app/concepts/base/operation/result.rb` | `.claude/docs/architecture.md` |
| `app/concepts/base/operation/sortable.rb` | `.claude/docs/architecture.md` |
| `app/concepts/base/component/base.rb` | `.claude/docs/architecture.md`, `.claude/docs/ui-components.md` |
| `app/concepts/base/component/btn.rb` (or `btn_config.rb`) | `.claude/docs/ui-components.md` |
| `app/concepts/base/component/table/*.rb` | `.claude/docs/ui-components.md` |
| `app/concepts/base/component/title_row.rb` | `.claude/docs/ui-components.md` |
| `app/controllers/concerns/operations_methods.rb` | `.claude/docs/architecture.md`, `.claude/docs/concepts-refactoring.md` |
| `app/controllers/application_controller.rb` | `CLAUDE.md`, `.claude/docs/architecture.md` |
| `app/policies/application_policy.rb` | `.claude/docs/architecture.md` |
| `app/policies/<domain>/base_policy.rb` | `.claude/docs/architecture.md` |

## Step 4: Present proposed changes — MANDATORY

**You MUST present a table of all proposed changes and get explicit confirmation before editing ANY file in `.claude/` or `CLAUDE.md`.**

Show:

| Doc file | Section | Current text (summary) | Proposed change | Why |
|----------|---------|----------------------|-----------------|-----|
| ... | ... | ... | ... | ... |

Then ask:

> Proposed N change(s) to docs/instructions. Apply them?
> 1. Yes, apply all
> 2. Let me pick which ones
> 3. Skip all

**Wait for user response. Do NOT make any changes without explicit confirmation.**

## Rules

- **NEVER edit `.claude/` or `CLAUDE.md` without user confirmation.** This is non-negotiable.
- Keep docs concise — do not add unnecessary text that wastes tokens.
- Only document patterns that Claude needs to follow. If it's obvious from the code, don't add a rule for it.
- Remove outdated rules when the underlying code changes.
- Prefer updating existing sections over adding new ones.
