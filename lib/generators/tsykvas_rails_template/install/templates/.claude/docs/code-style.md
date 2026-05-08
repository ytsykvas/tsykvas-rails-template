# Code Style

## Ruby / Rails

- `# frozen_string_literal: true` on the first line of every Ruby file under `app/` and `spec/`.
- RuboCop is `rubocop-rails-omakase` (see `.rubocop.yml`). Run with `bin/rubocop` and autocorrect via `bin/rubocop -A`.
- Compact class notation: `class Feature::Operation::Action < Base::Operation::Base`. Never nested `module` blocks.
- Business logic belongs in operations under `app/concepts/<...>/operation/`. Controllers are `endpoint Op, Component` one-liners; models hold validations/associations only.
- Trailing commas in multi-line arrays and hashes (Omakase enforces it).
- Use `Time.zone.parse(...)` rather than `DateTime.parse(...)` (Rails timezone-aware).

## I18n

- Default locale is set in `config/application.rb`. Every locale file under `config/locales/` must be kept in sync (mirror the same keys).
- Always `I18n.t('full.key')` in operations and components — never `t('key')` or `t('.relative_key')` shorthand.
- Devise strings are split into `config/locales/devise.en.yml`.

## ViewComponent / Slim

- View component path is `app/concepts/` (`config/initializers/view_component.rb`). Templates live next to the `.rb` file: `app/concepts/<ns>/<feature>/component/<action>.html.slim`. (ViewComponent 4.8+ requires the explicit `.html.` prefix; Rails layouts under `app/views/layouts/` keep the bare `.slim` extension.)
- Feature components inherit from `Base::Component::Base`; generic base primitives (`Btn`, `Table`) inherit from `ViewComponent::Base`.
- Use `::Base::Component::Btn` (with `::` prefix) when referencing components from namespaced contexts.
- Templates: keep logic minimal — push Ruby into the component `.rb` file. Slim auto-escapes; never use `==`/`raw`/`html_safe` on user input.

## Forms

- Use `simple_form_for` (gem `simple_form`). Forms must call it via `helpers.simple_form_for` inside ViewComponents:

  ```slim
  = helpers.simple_form_for @model, url: some_path, method: :post do |f|
  ```

- New/Edit pattern: extract a shared `Form` component; create distinct `New`/`Edit` subclasses (for breadcrumbs/title differences).
- On validation failure inside an operation: `add_error :base, message` + `invalid!` and re-`self.model = ...`. `endpoint` will re-render with 422.

## File layout cheatsheet

```
app/concepts/<namespace>/<feature>/
  operation/<action>.rb    # business logic, must call authorize!/policy_scope/skip_authorize
  component/<action>.rb    # ViewComponent::Base subclass
  component/<action>.html.slim  # template
```

Mirror the same structure under `spec/concepts/...` for tests.

# Anti-patterns checklist

Real examples of patterns that show up in code reviews. The ✅ side is what to write.

## Operations / Controllers

- ❌ AR queries in controllers → ✅ controller is `endpoint Op, Component`; queries live in the operation.
- ❌ `if/else` flow control in controllers → ✅ branch inside the operation; let `endpoint` handle redirect vs render.
- ❌ Forgetting Pundit (`Pundit::AuthorizationNotPerformedError` at runtime) → ✅ every operation calls `authorize!` / `policy_scope` / `skip_authorize` / `authorize_and_save!`.
- ❌ Nested module blocks (`module Admin; class User; ...`) → ✅ compact: `class Admin::User::Operation::Index < Base::Operation::Base`.
- ❌ Business logic in `before_save` callbacks → ✅ run it inside the operation that mutates the record.
- ❌ `params.permit!` / `params.to_unsafe_h` → ✅ explicit `params.require(:user).permit(:name, :email, ...)`.

## Components / Views

- ❌ AR queries inside a ViewComponent → ✅ data only via `initialize`; operation loads it.
- ❌ Reading `helpers.params` inside a component → ✅ pass through `OpenStruct` as `request_params:`.
- ❌ `==`, `raw`, `html_safe` on user input → ✅ trust Slim's auto-escape; if you need HTML, sanitize via Rails' `sanitize` helper with an allowlist.
- ❌ Inline literal strings in templates → ✅ `I18n.t('full.key')` with mirrors in every locale you ship.
- ❌ `t('.relative_key')` shorthand → ✅ `I18n.t('full.key')`. ViewComponent's lookup path makes relative keys unreliable.
- ❌ Raw `<form>` or `form_with` → ✅ `helpers.simple_form_for` (see `forms.md`).
- ❌ Raw `<button>`/`<a class="btn ...">` → ✅ `render ::Base::Component::Btn.new(...)`.
- ❌ Hand-rolled `<table>` for collections → ✅ `Base::Component::Table::Table` with `add_column`.
- ❌ Top-level constant references (e.g. `Base::Component::Btn`) inside another component → ✅ `::Base::Component::Btn.new(...)`. Without `::` Ruby's lookup falls through `ViewComponent::Base::Component` and crashes at render time.

## Visual / design-system

See `design-system.md` for the full token set + component catalog. Frequent traps:

- ❌ Hardcoded hex literals (`#0d6efd`) in component templates → ✅ design-system tokens (`var(--bs-primary)` or your own SCSS variable).
- ❌ Hardcoded `box-shadow` / `border-radius` values per component → ✅ shared `--bs-border-radius`, `--bs-box-shadow` tokens.
- ❌ Hardcoded `font-family` overrides per component → ✅ inherit from the cascade; set fonts once in your stylesheet entry.
- ❌ `class="bg-primary text-white text-center fw-bold p-3"` repeated everywhere → ✅ extract a small SCSS utility class or component partial.
- ❌ `active_nav_class('/crm')` for a dashboard link (matches every CRM page) → ✅ `active_nav_class('/crm', '/crm/dashboard', exact: true)`.
- ❌ Hardcoded brand strings (year, tagline, copyright) in templates → ✅ `I18n.t('ui.brand.year' / 'ui.brand.tagline')`.

## Time / dates

- ❌ `Time.now`, `DateTime.parse(...)`, `Date.today` → ✅ `Time.zone.now`, `Time.zone.parse(...)`, `Date.current` (timezone-aware, honors `config.time_zone`).
- ❌ Hardcoded format strings repeated everywhere → ✅ `Base::Component::Table::Table#format_date`, or register in `config/locales/*.yml` under `date.formats.*`.

## Tests

- ❌ `FactoryBot.create(...)` → ✅ shorthand `create(...)` (FactoryBot syntax included globally).
- ❌ Hardcoded fixtures (`email: "test@test.com"`) → ✅ `Faker::Internet.unique.email`.
- ❌ `double` when an interface exists → ✅ `instance_double(SomeClass)`.
- ❌ `expect(x).to receive(:y)` in `before` → ✅ `allow` + `have_received` after the call.
- ❌ Skipping the Pundit-failure test for an operation → ✅ always cover both happy and `Pundit::NotAuthorizedError` paths.

# Git Workflow

- Commit messages in **imperative present tense** ("Add feature", not "Added feature"), under 72 chars.
- Default branch is `main`. Feature branches PR into `main`.
- Before requesting review: run `bin/rubocop`, `bundle exec rspec`, and `bin/brakeman --no-pager` (all three are part of CI).
- Never force-push to `main`.
