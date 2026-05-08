# Documentation Standards

## Directory structure

```
docs/
├── <domain>/                  # Feature domain directory (admin, crm, screener, ...)
│   ├── overview.md            # Domain-level overview (entry points, key concepts)
│   ├── operations.md          # Operations and their flows
│   ├── components.md          # ViewComponents in this domain
│   └── <specific_feature>.md  # Specific feature docs
└── <standalone_topic>.md      # Cross-domain infrastructure topics
```

### Existing domains

`admin`, `crm`, `screener`, `shared`, `base`. New documentation should slot into one of these or sit at the root if cross-cutting.

### Placement rules

- Feature belongs to an existing domain → put in that domain's directory
- Feature crosses multiple domains → primary domain, reference from others
- Standalone infrastructure → root of `docs/`

## When to create documentation

- New feature with non-obvious flow (multi-file, jobs, API calls)
- Bug fix that reveals non-obvious behavior worth remembering
- Flow that involves race conditions, caching, or async processing
- Integration with an external service

## When NOT to create documentation

- Simple CRUD operations that follow the Concepts Pattern
- Trivial UI changes
- Something already well-documented in code

## Document template

```markdown
# <Feature Name>

> Last updated: YYYY-MM-DD

<1–2 sentence summary.>

---

## Overview

<What this feature does, why it exists, who uses it.>

---

## Flow

<ASCII diagram or numbered steps from trigger to result.>

```
Trigger (UI / Job / API)
  └─ Controller#action
       └─ Operation#perform!
            └─ Service / Job / etc.
```

---

## Key Files

| File | Role |
|------|------|
| `app/path/to/file.rb` | What it does |

---

## Potential Issues

| # | Location | Description | Severity |
|---|----------|-------------|----------|
| 1 | `Class#method` | Description | Low/Medium/High |
```

## Writing rules

- **Audience**: developers on this team, not end users.
- **Be specific**: use file paths, method names, class names.
- **Include the full flow**: don't skip steps.
- **Document behavior, not implementation**: focus on what happens, not line-by-line code.
- **Language**: English.
