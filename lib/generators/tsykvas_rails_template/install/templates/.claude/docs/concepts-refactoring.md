# Concepts Pattern — Guide

## What a controller looks like

```ruby
# frozen_string_literal: true

class Admin::UsersController < Admin::BaseController
  def index
    endpoint Admin::User::Operation::Index, Admin::User::Component::Index
  end

  def show
    endpoint Admin::User::Operation::Show, Admin::User::Component::Show
  end
end
```

Every action is a one-liner: `endpoint OperationClass, ComponentClass`. For redirect-only actions the component can be omitted (the operation must set `self.redirect_path`). No AR queries, no `if`/`else`, no flash juggling in controllers.

---

## File structure

```
app/concepts/<namespace>/<feature>/
  operation/
    index.rb       # business logic for index
    show.rb
    create.rb
    update.rb
    destroy.rb
  component/
    index.rb            # ViewComponent class
    index.html.slim     # template (note .html.slim — required by ViewComponent 4.8+)
    show.rb
    show.html.slim
    form.rb             # shared form for new/edit
    form.html.slim
    new.rb              # subclass of Form (breadcrumbs/title)
    edit.rb
```

Mirror the same paths under `spec/concepts/...`.

---

## How `endpoint` works

`endpoint` is defined in `app/controllers/concerns/operations_methods.rb`. It:

1. Calls `operation.call(params:, current_user:)`
2. Verifies authorization was invoked (or skipped) via `check_authorization_is_called(result)`
3. Yields to the optional block (used by `Users::RegistrationsController` for Devise sign-in glue)
4. Dispatches by `action_name` and response format

| `action_name` | Success behavior | Failure behavior |
|---|---|---|
| `index`, `show`, `edit`, `new` | Render `component.new(**kwargs)` | Same, with flash alert |
| `create`, `update`, anything containing `destroy` | Redirect to `result.redirect_path` (or `<controller_name>_path`) with flash notice | Re-render component with 422 |
| `format.js` (for any action) | Redirect via `window.location.href = '<path>'` | Render component into `#modals` and toggle Bootstrap modal |
| `format.json` | `result.model.map(&:select2_search_result)` with pagination JSON | (same) |

Component kwargs come from `result.model`:

- `OpenStruct` → `component.new(**result.model.to_h)` (recommended for multi-value results)
- Single AR object → `component.new(<concept>: model)` where `<concept>` is the operation's top-level namespace, singularized for show/edit/new and pluralized for index/create/update/destroy

---

## Writing an operation

```ruby
# frozen_string_literal: true

class Feature::Operation::Action < Base::Operation::Base
  def perform!(params:, current_user:)
    # 1. Authorization (REQUIRED — pick one)
    authorize! record, :action?
    # or
    self.model = ::OpenStruct.new(items: policy_scope(Item))
    # or
    skip_authorize       # only when there's no AR record to authorize

    # 2. Business logic / data loading

    # 3. Set the result model
    self.model = ::OpenStruct.new(key: value, ...)

    # 4. (For create/update/destroy) trigger redirect
    self.redirect_path = some_path
    notice(I18n.t('notices.created'))
  end
end
```

### Authorization rules

- Internal AR models → `authorize! record, :action?` (or `policy_scope(...)` for collections, or `authorize_and_save!`)
- Anything truly auth-free → `skip_authorize` and (if iterating a collection) `skip_policy_scope`
- Per-domain base policies (`Admin::BasePolicy`, `Crm::BasePolicy`, `Screener::BasePolicy`) drive the redirect destination on `Pundit::NotAuthorizedError` — keep your `<Domain>Policy < <Domain>::BasePolicy` hierarchy intact.

### Triggering a redirect from an operation

Set `self.redirect_path` and `endpoint` will redirect:

```ruby
self.redirect_path = Rails.application.routes.url_helpers.crm_root_path
notice(I18n.t('notices.updated'))
```

For "resource not found" in a `show`-style action:

```ruby
def resource_not_found?(record)
  return false unless record.nil?

  add_error :base, I18n.t('alerts.resource_not_found')
  invalid!
  self.redirect_path = Rails.application.routes.url_helpers.admin_users_path
  true
end
```

### Flash messages

```ruby
notice(I18n.t('notices.created'))                       # success → result.message
notice(I18n.t('alerts.warning'), level: :alert)         # warning → result.message_level == :alert
add_error :base, I18n.t('alerts.failed'); invalid!      # failure → result.error_message
```

### `OpenStruct` model

Pass multiple values via `::OpenStruct`. `endpoint` spreads it as kwargs:

```ruby
self.model = ::OpenStruct.new(
  users: paginated_users,
  request_params: params           # only if the slim template needs request params
)
```

```ruby
component.new(**result.model.to_h)  # Component.new(users: ..., request_params: ...)
```

### Sub-operations

```ruby
run_operation(OtherOp, params: params, current_user: current_user)
# Failures bubble up automatically. Pass manually_handle_errors: true to handle them yourself.
```

---

## Writing a component

```ruby
# frozen_string_literal: true

class Feature::Component::Index < Base::Component::Base
  def initialize(users:, request_params: nil)
    @users = users
    @request_params = request_params
  end
end
```

Rules:

- Always `# frozen_string_literal: true`.
- Pure presentation: data only via `initialize`. No AR queries.
- Use `I18n.t('full.key')` — never `t('.relative_key')`.
- Template at `app/concepts/<ns>/<feature>/component/<action>.html.slim` next to the `.rb`.
- For request params, prefer `@request_params` (passed through OpenStruct) over `helpers.params`.

---

## Non-standard action names

`endpoint` triggers a redirect when `result.redirect_path` is set, regardless of action name. So custom actions like `archive_property` work without special handling — just make sure the operation sets `self.redirect_path`.

---

## Refactor checklist

1. Read the controller — understand each action's intent.
2. Move logic into operations under `app/concepts/<ns>/<feature>/operation/`.
3. Create or verify components under `app/concepts/<ns>/<feature>/component/`.
4. Replace controller actions with `endpoint Op, Component`.
5. Update every locale file under `config/locales/` to mirror the new keys.
6. Add specs: operation spec (happy path + Pundit failure path), component spec for non-trivial render logic.
7. Validate: `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec rspec`.
