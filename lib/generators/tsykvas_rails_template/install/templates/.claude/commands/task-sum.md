Generate a user-facing release notes Markdown file based on the current git changes in this branch.

## Steps

1. Run `git log main..HEAD --oneline` to see all commits in the current branch.

2. Run `git diff main...HEAD --stat` to get a high-level overview of changed files.

3. Run `git diff main...HEAD` to read the full diff.

4. Read any key changed files (components, operations, views, locale files) to understand *what* the feature actually does from the user's perspective.

5. Determine a short, descriptive filename for the release notes based on the feature, e.g. `RELEASE_NOTES_<FEATURE_NAME>.md`.

6. Write the file to the **project root** (`<filename>.md`).

## Output format

The file must be written in **English** and follow this structure:

```markdown
# <Feature Title>

## What's New

<1–3 sentences describing the new feature or improvement and the problem it solves.>

## How It Works

<Step-by-step or bullet-point explanation of the feature from the user perspective.>

## Where to Find It

<Tell the user where in the UI this appears and how to access it.>

## Notes

<Optional. Any caveats, edge cases, or useful context for the user.>
```

## Rules

- Write for **end users**, not developers — no class names, no file paths, no framework terms.
- Focus on **what changed** and **why it matters**, not how it was implemented.
- If the branch contains multiple unrelated changes, create one file that covers all of them in separate sections.
- Keep the tone clear, concise, and professional.
- Do not include a "Notes" section if there is nothing meaningful to say.
