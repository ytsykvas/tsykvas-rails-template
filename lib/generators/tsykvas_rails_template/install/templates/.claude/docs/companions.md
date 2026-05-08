# Recommended companions

`bin/rails g tsykvas_rails_template:companions` adds the gems used across
every project the gem author maintains, plus runs their `:install`
sub-generators and injects standard configuration. Run **after**
`tsykvas_rails_template:install`.

This doc is gem-shipped reference; `/tsykvas-claude` keeps the body
verbatim and only swaps host-specific examples.

## What you get

| Gem | Group | Why | Post-install action |
|---|---|---|---|
| `devise` | top-level | Authentication (`current_user`, `before_action :authenticate_user!`). The gem's `OperationsMethods` and `Base::Operation::Base#authorize!` need a `current_user` source — Devise is the universal choice across reference projects. | `rails g devise:install` (initializer + locale). **No User model is generated** — run `rails g devise User` (or your resource name) when ready. |
| `omniauth-rails_csrf_protection` | top-level | CSRF guard for OAuth callbacks. Required if Devise + OmniAuth are used together. | none |
| `simple_form` | top-level | Form builder with cleaner DSL than `form_with`. Components and operation scaffolds work fine without it, but you'll likely use it once you have non-trivial forms. | `rails g simple_form:install` (with `--bootstrap` if Probe sees Bootstrap). |
| `mini_magick` | top-level | Image processing for ActiveStorage variants and `image_processing` gem. | none — but **ImageMagick must be installed system-wide** (`brew install imagemagick` / `apt install imagemagick`). The generator doesn't manage OS packages. |
| `mission_control-jobs` | top-level (gated on `:solid_queue`) | Web UI for SolidQueue at `/jobs`. | Injects an admin-only mount into `config/routes.rb`. See "MissionControl::Jobs constraint" below. |
| `rspec-rails` | `:development, :test` | The gem assumes RSpec for testing; operation-spec patterns documented in `testing.md`. | `rails g rspec:install` (creates `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`). |
| `factory_bot_rails` | `:development, :test` | Test data factories. | none |
| `faker` | `:development, :test` | Realistic fake data inside factories. | none |
| `shoulda-matchers` | `:test` | RSpec matchers for AR / Rails (`have_many`, `validate_presence_of`, etc.). The project explicitly avoids association/validation specs as a default — but matchers are still useful where appropriate. | Appends a `Shoulda::Matchers.configure` block to `spec/rails_helper.rb`. |
| `webmock` | `:test` | Stub external HTTP calls in tests. | Appends `WebMock.disable_net_connect!(allow_localhost: true)` to `spec/rails_helper.rb`. |
| `dotenv-rails` | `:development, :test` | Load env vars from `.env` files in dev/test. | Appends `.env` / `.env.*` / `!.env.example` rules to `.gitignore`. |

## Opt-out matrix

| Flag | Skips |
|---|---|
| `--skip-auth` | `devise` + `omniauth-rails_csrf_protection` + `devise:install` |
| `--skip-forms` | `simple_form` + `simple_form:install` |
| `--skip-images` | `mini_magick` |
| `--skip-jobs-ui` | `mission_control-jobs` + the routes mount |
| `--skip-test` | `rspec-rails` + `factory_bot_rails` + `faker` + `shoulda-matchers` + `webmock` + `rspec:install` + config injections |
| `--skip-dev` | `dotenv-rails` + `.gitignore` append |
| `--skip-bundle` | `bundle install` after Gemfile edits |
| `--skip-post-install` | All `:install` sub-generators and config injections (Gemfile additions still happen) |

Combine flags freely: `bin/rails g tsykvas_rails_template:companions --skip-auth --skip-forms` adds only the test/dev/images/jobs-ui groups.

## Idempotency

Re-running `:companions` is safe:

- **Gemfile additions** check existing contents via regex; skip if present.
- **`:install` sub-generators** skip if their canonical config file exists
  (`config/initializers/devise.rb`, `config/initializers/simple_form.rb`,
  `spec/rails_helper.rb`).
- **Config injections** check for marker strings (`Shoulda::Matchers`,
  `WebMock.disable_net_connect`, `MissionControl::Jobs::Engine`, `.env`)
  and bail if found.

You can re-run after edits without losing your work, and CI runs the
generator twice in the smoke job to verify this.

## MissionControl::Jobs constraint

The mount injected into `config/routes.rb`:

```ruby
mount MissionControl::Jobs::Engine,
      at: "/jobs",
      constraints: ->(req) {
        user = req.env["warden"]&.user
        user.respond_to?(:admin?) && user.admin?
      }
```

Why a lambda constraint and not `authenticated :user`:

- The lambda runs **per request**, so a missing `User` model at boot
  doesn't crash. You can install `:companions` before generating Devise's
  User; `/jobs` will return 404 on every request until `User` exists with
  an `admin?` method, which is exactly what you want (lock-by-default).
- Works with **any Warden-based auth** (Devise, custom Warden mounts).
  Doesn't require Devise's `devise_for :users` to have run yet.
- `respond_to?(:admin?)` keeps the lambda from raising `NoMethodError`
  if your User model doesn't define `admin?` yet — the route just 404s.

If your auth stack isn't Warden-based, swap the constraint:
```ruby
constraints: ->(req) {
  current_user = YourAuthHelper.current_user_from(req)
  current_user&.admin?
}
```

## Common follow-ups

After `bin/rails g tsykvas_rails_template:companions`:

1. **Devise User model.** When your domain is ready: `rails g devise User`.
   Add `admin:boolean` if you want the `/jobs` mount to actually show its
   UI: `rails g devise User admin:boolean`. Then `rails db:migrate`.
   Don't forget to update the Devise routes line: `devise_for :users`.
2. **simple_form configuration.** If you skipped `--bootstrap` and want it
   later, re-run `rails g simple_form:install --bootstrap` (it'll prompt
   to overwrite the initializer; say yes).
3. **shoulda-matchers + RSpec.** The appended config block targets RSpec.
   If you migrated to a different test framework after running
   `:companions`, remove the block manually.
4. **WebMock allow-list.** If your tests need to hit a real internal
   service (e.g. a containerized backend), wrap the call:
   ```ruby
   WebMock.disable! { real_call }   # or WebMock.allow_net_connect!
   ```

## Why these gems specifically

These are the gems that appear across the gem author's reference projects AND aren't part of the default `rails new` Gemfile. The gem deliberately doesn't ship gems that:

- Already come with Rails (Puma, Importmap, Turbo, Stimulus, Bootsnap,
  SolidQueue / SolidCache / SolidCable, Brakeman, Rubocop-Rails-Omakase, …).
- Vary across projects (Tailwind vs custom CSS as alternatives to Bootstrap, MySQL vs
  Postgres, Sidekiq vs SolidQueue when both are valid).
- Are essential to one project but not universal (Swagger generators, alternate
  pagination libraries, search DSLs).

The `:companions` set is the **least common denominator across the gem
author's projects**, not "every gem you might want".

## Skipping `:companions` entirely

If your stack is incompatible (CanCanCan instead of Pundit, Tailwind
instead of Bootstrap with simple_form, Minitest instead of RSpec), don't
run `:companions`. The gem's core (`:install` + `:concept`) is stack-
agnostic and works fine without any of these.
