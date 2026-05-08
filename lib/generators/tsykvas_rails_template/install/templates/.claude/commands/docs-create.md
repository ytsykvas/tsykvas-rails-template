Write comprehensive technical documentation for the feature described in the arguments.

## Input

The user will provide context in the arguments — feature name, relevant file paths, or a short description of what the feature does. Use this as the starting point.

## Steps

1. **Read all provided files** from the arguments. If paths are given, read each one in full.

2. **Explore related files** — follow the code: controllers call operations, operations call services/jobs, jobs call other jobs. Read everything involved in the full workflow. Also check:
   - Routes (`config/routes.rb`) for the relevant endpoints
   - Locale files (`config/locales/<your-default>.yml`, `config/locales/<other>.yml`) if I18n keys are used
   - Relevant models if they are referenced
   - Pundit policies if authorization is involved

3. **Map the complete workflow** — trace the full flow from entry point (HTTP request / job trigger / user action) to final output. Note every file, class, and method involved.

4. **Identify potential bugs** — look for: race conditions, synchronous calls that block requests, hardcoded values that should be ENV vars, missing error handling, stale cached state, SQL injection, misleading variable names, missing authorization, etc.

5. **Determine the output path** — use `docs/<feature_name>.md`. If the feature belongs to an existing subdirectory (e.g. `docs/admin/`, `docs/crm/`), place it there. Create the `docs/` directory if it doesn't exist.

6. **Write the documentation file.**

## Output format

```markdown
# <Feature Name>

> Last updated: <today's date>

<1–2 sentence summary of what this feature does and why it exists.>

---

## Architecture Overview

<High-level table or bullet list: what components are involved and how they relate.>

---

## Flow Diagram

<ASCII diagram of the complete workflow — from trigger to final state.>

---

## Step-by-Step Description

### Step 1: <Entry Point>

**File:** `path/to/file.rb`

<Detailed explanation of what happens here. Include: method names, params, validations, branches, edge cases.>

### Step 2: ...

(continue for every step in the flow)

---

## Key Models

<Only include if models are central to the feature. List fields with types and purpose.>

---

## Authorization

<How Pundit policies gate this feature. Which base policy domain (Admin/Crm/Screener)? What are the rules?>

---

## Potential Bugs

| # | Location | Description | Severity |
|---|----------|-------------|----------|
| 1 | `ClassName#method` | Description | Low / Medium / High |

---

## Environment Variables

- `VAR_NAME` — What it's used for

---

## Gem Dependencies

- `gem-name` — What it does in this feature
```

## Rules

- **Write for developers on this team**, not end users — use class names, file paths, method names.
- **Be specific**: always reference the exact file path and method, not just the class name.
- **Include the full flow** — do not skip steps even if they seem obvious.
- **Bugs section is mandatory** if you find any — no matter how minor.
- Omit sections (Key Models, Authorization, Env Vars, Gems) only if they are genuinely not applicable.
- Do not summarize — document. The goal is that a developer can understand the entire feature without opening a single file.

ARGUMENTS: $ARGUMENTS
