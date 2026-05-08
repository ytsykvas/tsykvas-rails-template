Run all project health checks and report issues with option to fix them.

## Steps

Run ALL 3 checks below in order. Never stop early — always run every check even if earlier ones fail.

### 1. Zeitwerk autoloading
```bash
bin/rails zeitwerk:check 2>&1
```

### 2. RSpec test suite
```bash
bundle exec rspec --format progress 2>&1
```

### 3. RuboCop linting
```bash
bin/rubocop --format simple 2>&1
```

## Reporting

After ALL checks are done, present results:

### Summary table

| Check | Status | Issues |
|-------|--------|--------|
| Zeitwerk | pass/FAIL | ... |
| RSpec | pass/FAIL | X failures, Y pending |
| RuboCop | pass/FAIL | X offenses |

### Issue details (only for failed checks)

For each issue:
- **Where**: `file_path:line_number`
- **What**: the specific problem
- **Why**: brief explanation

### Decision

If there are fixable issues, ask:

> Found N issue(s). Fix them?
> 1. Yes, fix all
> 2. No

Wait for user response. If yes — fix all issues. If some fixes are ambiguous, list them separately and ask for confirmation.

If ALL checks pass — just say so, no questions needed.
