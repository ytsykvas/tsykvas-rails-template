Check if documentation in `docs/` matches current code changes and update or create docs as needed.

## Step 1: Identify what changed

Compare current branch against `main`:

```bash
git diff main --name-only 2>&1
```

If working directly on `main` with uncommitted changes:

```bash
git diff --name-only 2>&1
git diff --cached --name-only 2>&1
```

## Step 2: Understand the changes

Read the changed files and understand what flows or features were added or modified. Focus on:

- New controllers, operations, components
- Changed model logic (validations, callbacks, scopes)
- New or modified routes
- New mailers or jobs
- Configuration changes that affect behavior
- New integrations or external services

## Step 3: Audit existing documentation

Check what documentation already exists:

```bash
find docs/ -name "*.md" -type f 2>&1
```

For each changed flow, determine:

1. **No doc exists** — a new doc file is needed
2. **Doc exists but is outdated** — the doc needs updating
3. **Doc exists and is current** — no action needed

## Step 4: Present findings and ask for confirmation

Show a table:

| Flow / Feature | Doc file | Status | Action needed |
|----------------|----------|--------|---------------|
| ... | `docs/...` or *none* | Current / Outdated / Missing | None / Update / Create |

Then ask:

> Found N doc(s) that need attention. Proceed?
> 1. Yes, update/create all
> 2. Let me pick which ones
> 3. Skip

**Wait for user response.** Do NOT make any changes without confirmation.

## Step 5: Update or create documentation

For **new docs**:
- Create in `docs/<domain>/` matching the feature domain (existing domains: `admin`, `crm`, `screener`, `shared`, `base` — or root for cross-cutting)
- Use clear markdown with sections: overview, how it works, configuration (if any), examples
- Keep it concise and practical — document behavior, not internal code structure
- Use the same style and level of detail as existing docs in `docs/` and the template in `.claude/docs/documentation.md`

For **existing docs**:
- Update only the sections affected by the changes
- Do not rewrite unrelated sections
- Add new sections if the change introduces new behavior

## Rules

- Documentation language: English
- Never delete documentation without asking
- Keep docs focused on **what the feature does and how to use it**, not internal code structure
- If unsure whether a change warrants documentation — include it in the table and let the user decide
