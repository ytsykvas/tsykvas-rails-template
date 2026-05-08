Refactor the provided files following the project's architecture and clean code principles.

## Input

Files to refactor: $ARGUMENTS

If no files are provided, ask the user which files they want to refactor.

## Steps

### 1. Read and understand

Read every file listed in `$ARGUMENTS`. Also read any closely related files needed for full context:

- The `.slim` template when refactoring a component `.rb`
- The operation when refactoring the component that consumes it
- **Sibling files of the same type** (e.g. if refactoring `users_table.rb`, also read `companies_table.rb`) — they often share duplicated logic that should be extracted together

### 2. Analyse for issues

Before writing any code, identify all issues in the files:

**Clean code:**
- Methods longer than 30 lines or conceptually doing more than one thing
- Classes longer than 150 lines — investigate whether the class can be split
- Logic that can be extracted into a well-named private method
- Repeated expressions or patterns — both within the file **and across sibling files**. When logic is duplicated across files, extract it (a shared concern, a helper class, or a method on `Base::Component::Base`)
- Variables or methods with unclear names
- Deep nesting (more than 2–3 levels) that can be flattened
- Long parameter lists — group with a value object or keyword args
- Magic constants — extract to a named constant
- Comments that explain *what* instead of *why* (replace with expressive code)

**Ruby / Rails style (per `.claude/docs/code-style.md`):**
- Missing `# frozen_string_literal: true`
- Use of `t()` shorthand instead of `I18n.t('full.key')` in components and operations
- `DateTime.parse(...)` — replace with `Time.zone.parse(...)`
- Missing trailing commas in multi-line arrays and hashes
- Missing locale keys in `config/locales/<your-default>.yml` and `config/locales/<other>.yml`
- `rubocop:disable` annotations — investigate each one; fix the underlying issue if possible

**Concepts Pattern (per `.claude/docs/architecture.md`):**
- Components that fetch data (must be pure presentation — only `initialize` + helpers)
- Operations that contain presentation logic
- Missing `authorize!` / `policy_scope` / `skip_authorize` in operations
- Non-compact class notation (nested modules instead of `class Feature::Op::Action`)
- Controllers that do more than `endpoint Op, Component`
- Index operations missing `Base::Operation::Sortable` allowlist for sorting params

**ViewComponent specifics:**
- `call`-style components: long `call` methods that mix column definitions with logic — extract cell helpers
- Duplicated column/cell rendering logic across table components
- `tag.div`/`tag.span` chains that can be extracted into named helper methods
- Buttons not using `Base::Component::Btn` (all buttons must use it with a valid `type:`)
- Multiple buttons in a table cell not wrapped in `safe_join([render(...), ...])`

**Stimulus controllers (per `.claude/docs/stimulus-controllers.md`):**
- Document-level event listeners not using arrow-function class fields (or properly stored bound references)
- Missing `disconnect()` cleanup for any listener added in `connect()`
- `.bind(this)` used in `connect()` without storing the reference for later removal
- Controller doing more than one responsibility — split into focused controllers

### 3. Refactor

Apply all improvements found in step 2. Rules:

- **Preserve all existing behaviour exactly** — this is a refactor, not a rewrite
- **Extract private methods** for any logic block that has a clear single responsibility or is used more than once
- **Name methods after what they return or do**, not how they do it (`role_badge` not `build_span_with_class`)
- **Keep public interface identical** — same `initialize` signature, same `call` output
- **One concern per method** — data transformation, formatting, and rendering should not mix
- **Slim templates**: keep logic minimal; move Ruby expressions into the component `.rb`
- **Operations**: split `perform!` into private steps when it has more than 3–4 distinct phases
- **Shared logic across files**: when the same method exists in two or more files, extract it once and call it from both — do not leave duplicates
- **OpenStruct keys**: if a key in `self.model = ::OpenStruct.new(...)` is never read by the component, remove it from both the operation and the component `initialize`
- Do NOT add features, change behaviour, or "improve" things that were not identified as issues
- Do NOT add docstrings or inline comments unless the logic is genuinely non-obvious

### 4. Update locales if needed

If you added or renamed any `I18n.t()` call, update both:
- `config/locales/<your-default>.yml`
- `config/locales/<other>.yml`

### 5. Run specs for refactored files

For each `.rb` file refactored, check whether a corresponding spec exists by mirroring the path under `spec/`. If a spec exists, run it:

```bash
bundle exec rspec <spec_file_path>
```

If tests fail:
- **Caused by our changes** (e.g. renamed a private method that was tested directly, changed a return value) — fix the source code or the spec to match the new structure while preserving the intent of the test
- **Pre-existing failures unrelated to our changes** — report them but do not fix; note them in the output as "pre-existing"

Do NOT delete or weaken tests to make them pass.

### 6. Validate

Run in order and fix any failures before reporting:

```bash
bin/rails zeitwerk:check
bin/rubocop -A
bin/rubocop
```

Run `-A` (autocorrect) first to fix all auto-correctable offenses, then run plain `rubocop` to address any remaining issues manually.

## Output format

After completing the refactor, report:

```
## Refactored files
<list of files changed>

## What changed
<for each file: bullet list of specific changes made and why>

## Validation
<result of zeitwerk / rubocop>
```

## Rules

- Never skip the validation step.
- If a file is already clean and well-structured, say so and make no changes.
- If a refactor would require changing a public API used by other files, read those callers first and update them too.
- Prefer many small focused private methods over few large ones.
- The final code must be easier to read than the original — that is the only success criterion.
