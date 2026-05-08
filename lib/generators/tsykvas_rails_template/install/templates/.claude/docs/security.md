# Security

Defaults Rails 8.1 ships with, plus a few project-specific settings. Run `bin/brakeman --no-pager` before opening a PR — it's part of CI.

## Authorization

**Pundit** is mandatory in every operation. `OperationsMethods#check_authorization_is_called` enforces this — any operation that doesn't call one of `authorize!` / `policy_scope` / `skip_authorize` / `authorize_and_save!` raises `Pundit::AuthorizationNotPerformedError` after the operation runs.

See `architecture.md` for the full Pundit setup. Per-domain base policies (`Admin::BasePolicy`, `Crm::BasePolicy`, `Screener::BasePolicy`) gate entire namespaces via the `BaseController#before_action`.

## Parameter filtering

`config/initializers/filter_parameter_logging.rb`:

```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt,
  :certificate, :otp, :ssn, :cvv, :cvc
]
```

`:passw` is a partial match (covers `password`, `password_confirmation`, ...). `:email` is filtered out of logs to satisfy data-protection norms — be aware that even server logs won't show emails.

When you add a new sensitive attribute, add the matching token here.

## Content Security Policy

`config/initializers/content_security_policy.rb` is currently **commented out** (Rails default). When you enable it for production:

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.script_src  :self, :https, :unsafe_inline  # only if needed for importmap nonces
    policy.style_src   :self, :https
    policy.img_src     :self, :https, :data
    policy.font_src    :self, :https, :data
    policy.object_src  :none
  end

  config.content_security_policy_nonce_generator = ->(req) { req.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
```

Then audit Stimulus controllers and Bootstrap usage for inline scripts/styles that need nonces.

## CSRF

Rails default — `protect_from_forgery with: :exception` is implicit in `ActionController::Base`. Devise + Turbo handle the token automatically. **Don't** disable CSRF on a controller unless it's a webhook endpoint, in which case use a different authentication mechanism (signature verification).

## XSS

- Slim auto-escapes by default. `==` and `raw` and `html_safe` bypass it — never use them on user input.
- ViewComponents render via Slim, so the same rule applies.
- `escape_javascript` is used in `OperationsMethods#endpoint`'s `format.js` branch when injecting modal HTML — keep that helper in any new JS-response code that interpolates a string.

## SQL injection

- ActiveRecord query methods (`where`, `joins`) auto-escape when given hashes / arrays. Never interpolate user input into raw SQL: prefer `where("name LIKE ?", "%#{q}%")` (parameterized) over `where("name LIKE '%#{q}%'")`.
- For `order(...)`, user-controlled column names are dangerous — use the `Base::Operation::Sortable#apply_sorting` helper, which validates against an `allowed_columns` allowlist.

## Browser support

`ApplicationController` calls `allow_browser versions: :modern`. Old browsers receive a 426 page. This is intentional: it lets us assume modern JS / CSS and simplifies CSP and Hotwire support.

## Devise modules currently enabled

`:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable`.

NOT enabled (and probably should be, eventually):

- `:lockable` — lock account after N failed attempts (sensible to add).
- `:trackable` — record sign-in count / IP / timestamps.
- `:confirmable` — email confirmation.
- `:timeoutable` — auto-logout after inactivity.

Adding any of these requires a migration (see Devise docs) plus enabling them in `User`.

## Brakeman

`bin/brakeman --no-pager` runs in CI. If it flags something:

1. Fix the underlying issue if possible.
2. If it's a false positive, document why with a comment and add an inline ignore (`# brakeman:ignore`) — but prefer fixes over ignores.

## importmap audit

`bin/importmap audit` runs in CI and flags JS dependencies with known CVEs. Pinned via `config/importmap.rb`.

## Mass assignment

Use **strong parameters** in operations:

```ruby
def perform!(params:, current_user:)
  attrs = params.require(:property).permit(:name, :description)
  self.model = Crm::Property.new(attrs)
  authorize_and_save!
end
```

Never `params.permit!` or `params.to_unsafe_h` unless you have a *very* specific reason and a comment explaining it.

## Webhook / unauthenticated endpoints

There are none in the project right now. When the first one lands:

- Skip Devise: `skip_before_action :authenticate_user!`
- Skip CSRF: `protect_from_forgery with: :null_session, only: [:webhook]`
- Verify the request signature (HMAC, JWT, etc.) inside the operation.
- `skip_authorize` only after signature verification passes — and document why.

## Anti-patterns

- ❌ Skipping authorization in operations (`skip_authorize` without a comment explaining why).
- ❌ Building SQL with string interpolation.
- ❌ `params.permit!` / `params.to_unsafe_h`.
- ❌ `==` / `raw` / `html_safe` in Slim or ViewComponent templates on anything user-controlled.
- ❌ `before_action :skip_authorization` on an entire controller.
- ❌ Logging request bodies that contain unfiltered sensitive data.
- ❌ Using `find_by_sql` with interpolated input.
