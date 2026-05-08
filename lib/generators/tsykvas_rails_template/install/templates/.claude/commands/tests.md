Run RSpec tests and RuboCop linting, check test coverage for uncommitted changes, then automatically fix any issues found.

Follow the project test conventions defined in: `.claude/docs/testing.md` and `.claude/docs/testing-examples.md`.

## Step 0: Check test coverage for uncommitted changes

```bash
git diff --name-only HEAD 2>&1
git diff --name-only --cached HEAD 2>&1
git ls-files --others --exclude-standard 2>&1
```

From the combined output, find all `.rb` files that contain logic (controllers, operations, components, models, policies, services — skip empty classes, pure config, migrations, and files with no methods).

For each such file, check if a corresponding spec exists:

- `app/concepts/admin/user/operation/index.rb` → `spec/concepts/admin/user/operation/index_spec.rb`
- `app/controllers/admin/users_controller.rb` → `spec/controllers/admin/users_controller_spec.rb` or `spec/requests/admin/users_spec.rb`
- `app/policies/crm/company_policy.rb` → `spec/policies/crm/company_policy_spec.rb`
- `app/models/user.rb` → `spec/models/user_spec.rb`
- `app/concepts/admin/user/component/users_table.rb` → `spec/concepts/admin/user/component/users_table_spec.rb`

If a spec file is **missing** — create it following conventions in `.claude/docs/testing.md` and `.claude/docs/testing-examples.md`.
If a spec file **exists** but doesn't cover the new/changed logic — update it to cover the changes.

**Important:** For each changed `.rb` file, read the actual diff (`git diff HEAD -- <file>`) and the corresponding spec. Verify that every new/changed public method, conditional branch, and business logic path is covered by tests. Don't just check that a spec file exists — check that it tests the new code.

**Skip testing for:** Component `.rb` files that only contain parameter initialization (no business logic, no methods beyond `initialize`). These are pure data-passing wrappers and don't need specs.

## Step 1: RSpec

```bash
bundle exec rspec --format progress 2>&1
```

If there are failures:
1. Read each failing spec and the corresponding source file
2. Determine whether the bug is in the test or in the source code
3. Fix it
4. Re-run only the fixed specs to confirm: `bundle exec rspec <file>:<line> 2>&1`

## Step 2: RuboCop

```bash
bin/rubocop --format simple 2>&1
```

If there are offenses:
1. Auto-correct what's safe: `bin/rubocop -A 2>&1`
2. If offenses remain, fix them manually
3. Re-run rubocop to confirm: `bin/rubocop --format simple 2>&1`

## Step 3: Confirm

After fixing, re-run both to make sure nothing is broken:

```bash
bundle exec rspec --format progress 2>&1
bin/rubocop --format simple 2>&1
```

Report final status:
- **RSpec**: X examples, Y failures, Z pending
- **RuboCop**: X offenses / no offenses

If everything passes — just say so.
If something still fails after your fix attempts — show what's left and ask for guidance.
