Pre-flight checks, commit, and push to current branch on GitHub. Validates nothing sensitive is committed, runs full health checks, then commits and pushes.

Five phases: **Update docs → Update rules → Safety scan → Health checks → Commit & push**. Stop and ask the user if any phase finds problems.

## Phase 0a: Update documentation

Run the `/update-docs` command first. This checks whether documentation in `docs/` (project root) needs updating based on code changes. Follow its full flow (present findings, ask for confirmation, update if approved).

## Phase 0b: Update rules

Run the `/update-rules` command. This checks whether `.claude/docs/` or `CLAUDE.md` need updating based on changes to base classes. Follow its full flow (present proposed changes, require explicit confirmation before any edits).

## Phase 1: Safety scan

Check that we are not committing something we shouldn't.

### 1a. Scan staged and unstaged changes for sensitive files

```bash
git status --short 2>&1
```

Look for files that should NOT be in git:

| Pattern | Why |
|---------|-----|
| `.env`, `.env.*` (not `.env.example`) | Secrets, API keys |
| `*.key`, `*.pem`, `*.crt`, `*.p12` | Private keys / certs |
| `credentials.yml.enc` changes without `*.key` in gitignore | Encrypted credentials |
| `config/master.key` | Rails master key |
| `*.sqlite3`, `*.sqlite3-*` | Local databases |
| `node_modules/`, `vendor/bundle/` | Dependencies |
| `.idea/` (non-shared config), `*.iml` | IDE-specific files |
| `coverage/` | Test coverage reports |
| `/storage/*` | Uploaded files |
| `/log/*`, `/tmp/*` | Logs and temp files |
| `*.dump`, `*.sql` | Database dumps |
| Files containing hardcoded tokens/passwords | Secrets in code |

Also check:
```bash
git diff --cached --name-only 2>&1
git diff --name-only 2>&1
```

### 1b. Grep for accidental secrets in changed files

```bash
git diff -U0 | grep -iE '(api_key|secret|password|token|private_key)\s*[:=]' 2>&1
git diff --cached -U0 | grep -iE '(api_key|secret|password|token|private_key)\s*[:=]' 2>&1
```

### 1c. Check if .gitignore is missing common patterns

Verify `.gitignore` covers: `.env*`, `*.key`, `/log/*`, `/tmp/*`, `/storage/*`, `/coverage`, `/public/assets`.

### If problems found

Show a table:

| File / Pattern | Problem | Suggestion |
|----------------|---------|------------|
| ... | ... | ... |

Ask:
> Found N safety issue(s). Fix them?
> 1. Yes, fix (add to .gitignore / unstage / remove)
> 2. No, continue anyway
> 3. Abort

Wait for response. Fix if asked, abort if asked, or continue.

---

## Phase 2: Health checks

Run the full check suite as defined in `/check`:

1. `bin/rails zeitwerk:check 2>&1`
2. `bundle exec rspec --format progress 2>&1`
3. `bin/rubocop --format simple 2>&1`

Run ALL checks, never stop early.

### If problems found

Show the summary table:

| Check | Status | Issues |
|-------|--------|--------|
| ... | ... | ... |

Then show issue details and ask:
> Found N issue(s). Fix them before pushing?
> 1. Yes, fix all
> 2. No, push anyway
> 3. Abort

Wait for response. If yes — fix issues, re-run failing checks to confirm, then continue.

---

## Phase 3: Commit & push

### 3a. Stage changes

```bash
git add -A
```

Review what's being committed:
```bash
git diff --cached --stat 2>&1
```

### 3b. Create commit

- Write a concise 1-sentence commit message that describes WHAT changed and WHY
- Use imperative mood ("Add...", "Fix...", "Refactor...", "Update...")
- Keep under 72 characters

```bash
git commit -m "$(cat <<'EOF'
Your commit message here

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### 3c. Push to current branch

Determine the current branch:
```bash
git branch --show-current 2>&1
```

Push:
```bash
git push origin HEAD 2>&1
```

### If push fails

- **No upstream**: run `git push -u origin HEAD 2>&1`
- **Rejected (non-fast-forward)**: try `git pull --rebase origin <branch> 2>&1`, resolve conflicts if any, then push again
- **Merge conflict during rebase**: show the conflicts and ask for guidance
- **Needs force push**: **NEVER force push automatically**. Show the situation and ask:
  > Push was rejected. Force push with `--force-with-lease`?
  > 1. Yes
  > 2. No, abort

### 3d. Confirm

Show final status:
```
Pushed to <branch> → <remote-url>
Commit: <short-hash> <message>
Files changed: N
```
