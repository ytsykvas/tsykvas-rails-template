Audit RSpec coverage for all `.rb` files changed on this branch vs `main`, then write or update specs where coverage is missing.

Follow project conventions from `.claude/docs/testing.md` and `.claude/docs/testing-examples.md`.

## Step 1: Find changed `.rb` files

```bash
git diff main --name-only 2>&1 | grep '\.rb$'
```

If `main` does not exist as a remote ref, fall back to:

```bash
git diff origin/main --name-only 2>&1 | grep '\.rb$'
```

If working directly on `main` with uncommitted changes:

```bash
git diff --name-only 2>&1 | grep '\.rb$'
git diff --cached --name-only 2>&1 | grep '\.rb$'
```

From the output, collect only files under `app/` (skip `spec/`, `db/migrate/`, `config/`, `lib/` unless they contain real business logic).

## Step 2: Filter — skip files with no testable logic

For each changed `app/**/*.rb` file, read the actual diff and the full file. **Skip** the file if it matches any of these:

- Component `.rb` that only defines `initialize` (parameter wrapper, no methods)
- Migration file
- Pure configuration (`config/`, `initializers/`)
- Empty class with no methods beyond `initialize` and `attr_reader`/`attr_accessor`
- Route file, `application.rb`, or similar framework glue

**Include** everything else: operations, services, models, controllers, jobs, policies, concerns with logic.

## Step 3: Audit each file

For every included file, do all three:

1. **Read the diff** — `git diff main -- <file>` — understand exactly what changed or was added
2. **Find the spec** — mirror the `app/` path under `spec/`:
   - `app/concepts/admin/user/operation/index.rb` → `spec/concepts/admin/user/operation/index_spec.rb`
   - `app/services/foo.rb` → `spec/services/foo_spec.rb`
   - `app/controllers/admin/users_controller.rb` → `spec/controllers/admin/users_controller_spec.rb` or `spec/requests/admin/users_spec.rb`
   - `app/models/user.rb` → `spec/models/user_spec.rb`
   - `app/jobs/foo_job.rb` → `spec/jobs/foo_job_spec.rb`
   - `app/policies/crm/company_policy.rb` → `spec/policies/crm/company_policy_spec.rb`
3. **Verify coverage** — read the spec (if it exists) and confirm every new/changed public method, branch, and business logic path introduced by the diff is tested. Do not assume coverage — read the spec line by line.

## Step 4: Present findings before writing

Show a table of files that need action:

| File | Spec | Status | Action |
|------|------|--------|--------|
| `app/...` | `spec/...` | Missing / Incomplete | Create / Update |

Then ask:

> Found N file(s) that need test coverage. Proceed?
> 1. Yes, write/update all
> 2. Let me pick which ones
> 3. Skip

**Wait for user response before writing any specs.**

## Step 5: Write or update specs

Work through each file **one at a time**:

### Writing a new spec

- `# frozen_string_literal: true` at the top
- `require 'rails_helper'`
- Use `described_class`, not the class name directly
- Use `let` / `let!`, FactoryBot with Faker
- Structure: `describe '.call'` → `context 'when ...'` → `it '...'`
- Cover: happy path, authorization failure (`raise_error(Pundit::NotAuthorizedError)`), error branches, edge cases
- Declare `type:` explicitly (this project does NOT enable `infer_spec_type_from_file_location!`)

### Updating an existing spec

- Add new `context` blocks for new branches; do not rewrite existing passing tests
- Keep the same describe/context depth and naming style as the rest of the file

### Skip spec creation if:

- The file contains only component initialization (no logic methods)
- The change is cosmetic (rename, whitespace, comment)

## Step 6: Run the specs

After writing/updating, run **only the affected spec files**:

```bash
bundle exec rspec <spec_file_1> <spec_file_2> ... --format documentation 2>&1
```

Do **not** run the full suite — run only the files you touched.

## Step 7: Fix failures

For each failing example:

1. Read the failure message and backtrace
2. Read the source file and the spec
3. Determine root cause: bug in the spec (wrong stub, wrong expectation) or bug in the source code
4. Fix the appropriate file
5. Re-run only that spec to confirm: `bundle exec rspec <file>:<line> 2>&1`

If a failure reveals a real source code bug — fix the source and note it in the final report.

## Step 8: Report

After all specs pass, report:

```
## Test Coverage Update

| File | Spec | Action taken | Result |
|------|------|--------------|--------|
| app/... | spec/... | Created / Updated / Skipped | ✅ X examples, 0 failures |
```

If any spec still fails after fix attempts — show the failure and ask for guidance.

## Rules

- Never run the full suite (`bundle exec rspec`) — run only changed spec files
- Never delete existing passing tests
- Use `instance_double` over plain `double` wherever the interface is known
- Write tests in English
- Keep tests focused — one logical assertion per `it` block
