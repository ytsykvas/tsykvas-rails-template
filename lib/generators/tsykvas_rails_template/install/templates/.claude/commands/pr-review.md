Review a GitHub Pull Request using the project's code review standards.

## Usage

`/pr-review <PR_NUMBER_OR_URL>`

Examples:
- `/pr-review 123`
- `/pr-review https://github.com/org/repo/pull/123`

## Steps

1. Extract the PR number from the argument (strip URL if needed).

2. Fetch PR metadata:
   ```
   gh pr view <number> --json number,title,body,author,baseRefName,headRefName,labels,additions,deletions,changedFiles
   ```

3. Fetch list of changed files:
   ```
   gh pr diff <number> --name-only
   ```

4. Launch **three agents in parallel** using the Agent tool, giving each the PR metadata and list of changed files — let them read the files and diff themselves:

   **Agent 1 — code-reviewer** (subagent_type: `code-reviewer`)
   Prompt: "Review the changes in PR #<number> '<title>'. Changed files: [list]. Use `gh pr diff <number>`, Read, Glob, Grep to read the files and understand what changed. Focus on Concepts Pattern compliance, code style, and best practices."

   **Agent 2 — security-reviewer** (subagent_type: `security-reviewer`)
   Prompt: "Security audit the changes in PR #<number> '<title>'. Changed files: [list]. Use `gh pr diff <number>`, Read, Glob, Grep to read the files and understand what changed."

   **Agent 3 — tech-lead** (subagent_type: `tech-lead`)
   Prompt: "Pre-PR architectural review of PR #<number> '<title>' by <author>. Base: <baseRef> ← <headRef>. PR description: <body>. Changed files: [list]. Use `gh pr diff <number>`, Read, Glob, Grep to read the files and understand what changed."

5. Collect results from all three agents and present a unified report.

## Output format

Present the final report in **English** with the following structure:

```
# PR Review: #<number> — <title>

**Author:** <author> | **Branch:** <headRef> → <baseRef>
**Changes:** +<additions> / -<deletions> across <changedFiles> files

## Changed Files
<list of changed files with a brief one-line description of what changed in each>

---

## Code Review (Concepts Pattern, style, best practices)
<output from code-reviewer agent>

---

## Security
<output from security-reviewer agent>

---

## Architecture & Assessment
<output from tech-lead agent>

---

## Summary

**Merge readiness:** ✅ Ready / ⚠️ Needs fixes / 🔴 Blocker

<3–5 bullet points: critical blockers, required fixes, optional improvements>
```

## Rules

- If no PR number is provided, print usage instructions and stop.
- If `gh` returns an error (not authenticated, PR not found), report it clearly and stop.
- Do not check out the branch or modify the working tree.
- Skip locale files unless a key is missing, duplicated, or used inconsistently.
- Every finding must include the file path and line number.
