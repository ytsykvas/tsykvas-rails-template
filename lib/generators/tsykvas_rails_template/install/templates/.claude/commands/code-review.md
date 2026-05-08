Review all code changes in the current branch against the main branch.

## Steps

1. Run `git diff main...HEAD --stat` to get a high-level overview of changed files.

2. Run `git diff main...HEAD --name-only` to get the list of changed files.

3. Run `git log main..HEAD --oneline` to get the commit history for context.

4. Launch **three agents in parallel** using the Agent tool, giving each the list of changed files and commits — let them read the files themselves:

   **Agent 1 — code-reviewer** (subagent_type: `code-reviewer`)
   Prompt: "Review the changes in the current branch vs main. Changed files: [list]. Recent commits: [log]. Use git diff, Read, Glob, Grep to read the files and understand what changed. Focus on Concepts Pattern compliance, code style, and best practices."

   **Agent 2 — security-reviewer** (subagent_type: `security-reviewer`)
   Prompt: "Security audit the changes in the current branch vs main. Changed files: [list]. Recent commits: [log]. Use git diff, Read, Glob, Grep to read the files and understand what changed."

   **Agent 3 — tech-lead** (subagent_type: `tech-lead`)
   Prompt: "Pre-PR architectural review of the current branch vs main. Changed files: [list]. Recent commits: [log]. Use git diff, Read, Glob, Grep to read the files and understand what changed. Evaluate architecture, design decisions, and PR readiness."

5. Collect results from all three agents and present a unified report.

## Output format

Present the final report in **English** with the following structure:

```
# Code Review: <branch name>

## Changed Files
<list of changed files with brief description of what changed>

---

## Code Review (Concepts Pattern, style, best practices)
<output from code-reviewer agent>

---

## Security
<output from security-reviewer agent>

---

## Architecture & Pre-PR Assessment
<output from tech-lead agent>

---

## Summary
<3–5 bullet points: overall readiness, critical blockers, recommended fixes before merge>
```

## Rules

- If there are no changes compared to main, report that there is nothing to review.
- Do not review lock files (`Gemfile.lock`, `yarn.lock`, `package-lock.json`), binary files, or locale files unless a key is missing or mistranslated.
- Focus only on files changed in this branch — do not review unrelated code.
- Every finding must include the file path and line number.
