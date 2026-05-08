# Architecture

## Concepts Pattern (primary feature organization)

All features live in `app/concepts/<namespace>/<feature>/` with two sub-directories:

- **`operation/`** — business logic, authorization, data loading
- **`component/`** — ViewComponent UI classes + Slim templates

Top-level namespaces (illustrative — name them after your access tiers):

- `admin/` — administrators (`user.admin?`)
- `crm/` — business users (`user.owner?`)
- `public/` — unauthenticated visitors / end consumers
- `base/` — shared building blocks (`Base::Operation::Base`, `Base::Component::Base`, `Base::Component::Btn`, `Base::Component::Table::Table`, `Base::Component::TitleRow`, `Base::Operation::Sortable`)
- `shared/` — cross-domain UI (sidebars, navbars)

`config/initializers/view_component.rb` sets `view_component_path = "app/concepts"`. ViewComponent resolves templates inside the concepts tree, NOT under `app/views/`. `app/views/` only holds layouts (one per top-level namespace, e.g. `admin.slim`, `crm.slim`, `public.slim`), Devise views, and PWA stubs.

Controllers are thin wrappers that call `endpoint`:

```ruby
class Admin::UsersController < Admin::BaseController
  def index
    endpoint Admin::User::Operation::Index, Admin::User::Component::Index
  end

  def show
    endpoint Admin::User::Operation::Show, Admin::User::Component::Show
  end
end
```

The `endpoint` method (defined in `app/controllers/concerns/operations_methods.rb`) runs the operation, extracts `result.model`, and passes it to the component for rendering.

### How `endpoint` dispatches

`endpoint` decides the response based on `action_name` and the response format:

- **`format.html`** — for `index/show/edit/new` it renders the component; for `create/update/destroy` it redirects to `result.redirect_path` or `<controller_name>_path`. Flash from `result.message` / `result.error_message`. On `create/update` failure it re-renders the component with HTTP 422.
- **`format.js`** — used for Bootstrap modal new/edit dialogs. Renders the component into `#modals` via JS or redirects on success.
- **`format.json`** — used by select2 search. Returns `result.model.map(&:select2_search_result)` with pagination.
- **`format.any`** — fallback for auto-submit/null requests.

Component constructor kwargs are derived from `result.model`:

- If `result.model` is an `OpenStruct` — splatted as kwargs (`component.new(**result.model.to_h)`).
- Otherwise — passed as `<concept>: model` (singular for show/edit/new, pluralized for index), where `<concept>` is the operation's top-level namespace underscored (e.g. `Admin::User::Operation::Index` → `admin: ...`). Keep this naming in sync between operation and component when not using `OpenStruct`.

### `format.js` — Bootstrap modal flow

For new/edit dialogs that should render inside an already-loaded page (no full navigation), submit the form with `data-turbo: false` and let the response come back as JS. `endpoint`'s `format.js` branch:

- **Success on create/update/destroy** → emits `window.location.href = '<path>'`. The browser navigates to `result.redirect_path` (or the `<controller_name>_path` fallback).
- **Failure / new / edit** → renders the component to a string, hides any currently-open Bootstrap modal, then injects the rendered HTML into `<div id="modals"></div>` and shows it. The injected HTML must contain a `.modal` element at the root.

Required scaffolding on the page:

```slim
/ in the layout / shared partial
#modals
```

```ruby
/ trigger button
render ::Base::Component::Btn.new(
  type: 'add',
  text: I18n.t('admin.users.new'),
  path: new_admin_user_path,
  data: { remote: true, turbo: false }   # request format.js
)
```

The component template should wrap content in a Bootstrap modal:

```slim
.modal.fade tabindex="-1" id="user_modal"
  .modal-dialog
    .modal-content
      .modal-header
        h5.modal-title = I18n.t('admin.users.new.title')
        button.btn-close type="button" data-bs-dismiss="modal"
      .modal-body
        / form
```

`escape_javascript` is used to safely interpolate the rendered HTML into the JS response — see `OperationsMethods#endpoint`. Don't bypass it.

### `format.json` — select2 search

The JSON branch is wired for select2 (jQuery select2 with remote data). Operation requirements:

- `result.model` is either a paginated relation OR an `OpenStruct` with a single pluralized key (e.g. `users:`).
- Each record must implement `#select2_search_result` returning `{ id:, text: }`.
- Pagination is detected via `respond_to?(:next_page)` (works with kaminari/pagy when configured).

```ruby
class User
  def select2_search_result
    { id: id, text: "#{name} <#{email}>" }
  end
end
```

The response shape:

```json
{ "result": [{"id": 1, "text": "..."}], "pagination": { "more": true } }
```

### Sub-operations in detail

`run_operation(OtherOp, params: ..., current_user: ...)` calls another operation, appends its `Result` to `result.sub_results`, and bubbles failures by default:

```ruby
def perform!(params:, current_user:)
  self.model = Crm::Property.new(name: params[:property_name])
  authorize_and_save!

  run_operation(
    Crm::Property::Operation::Notify,
    params: params,
    current_user: current_user
  )
  # If the sub-operation fails, its errors are copied onto self and ActiveRecord::RecordInvalid is raised.
end
```

To handle sub-operation errors yourself (e.g. swallow them or branch logic), pass `manually_handle_errors: true`:

```ruby
sub_result = run_operation(
  OtherOp,
  params: params,
  current_user: current_user,
  manually_handle_errors: true
)

if sub_result.failure?
  add_error :base, I18n.t('alerts.partial_failure')
  invalid!
end
```

`result.success?` / `result.failure?` consider the operation's own errors AND every sub-result, so authorization in sub-operations is enforced just like top-level ones.

### When to bypass `endpoint`

Use `endpoint` for every standard CRUD action. There is no `endpoint_partial` or `endpoint_json` helper in this project (yet). For ad-hoc Turbo Frame fragments or JSON endpoints, render directly from the controller and call `check_authorization_is_called(result)` after the operation, OR have the operation `skip_authorize` + `skip_policy_scope` and let the helper observe the flags.

## Operations (`Base::Operation::Base`)

```ruby
# frozen_string_literal: true

class Admin::User::Operation::Index < Base::Operation::Base
  include Base::Operation::Sortable

  def perform!(params:, current_user:)
    self.model = ::OpenStruct.new(users: nil)

    users = policy_scope(User)

    users = apply_sorting(
      users,
      params: params,
      allowed_columns: %i[id name email role created_at],
      default_column: :id,
      default_direction: :desc
    )

    self.model.users = users
  end
end
```

Always use **compact class notation**: `class Feature::Operation::Action < Base::Operation::Base` — never nested `module` blocks.

Key methods available inside operations:

- `authorize!(record, query)` / `policy_scope(scope)` — Pundit authorization (mandatory in every operation; see below)
- `skip_authorize` / `skip_policy_scope` — bypass auth checks; usually used together
- `self.model = value` — data passed to component
- `self.redirect_path = path` — redirect after action (triggers redirect in `endpoint`)
- `notice(text, level: :notice)` — flash message
- `add_error(key, message)` / `add_errors(from)` / `invalid!` — failure handling
- `authorize_and_save!(auth_method = nil)` — `authorize!` then `model.save!` (defaults to `:create?` for new records, `:update?` otherwise)
- `run_operation(OperationClass, params)` — sub-operations; sub-results bubble failures unless `manually_handle_errors: true`

Result (`Base::Operation::Result` — includes `ActiveModel::Validations`):

- `result.success?` / `result.failure?` — considers `errors`, `model.errors`, and all `sub_results`
- `result.model` / `result.errors` / `result.message` / `result.message_level` / `result.redirect_path`
- `result.error_message` — `errors[:base].join(' ')`
- `result[:key]` — stash extra data via `@result[key] = ...`
- `invalid!` — force-fail even if no errors are recorded

### `OpenStruct` as model

Use `::OpenStruct` to pass multiple values to a component. `endpoint` spreads its keys as kwargs:

```ruby
self.model = ::OpenStruct.new(users: paginated, request_params: params)

# component receives:
def initialize(users:, request_params:)
```

When a slim template needs request params (search forms, sorting), pass them through the OpenStruct as `request_params:` rather than reaching for `params` inside the component.

## Authorization (Pundit) — MANDATORY

Every operation MUST call one of:

- `authorize!(record, :action?)`
- `policy_scope(scope)`
- `skip_authorize` (alone — `OperationsMethods#check_authorization_is_called` already skips `policy_scope` on failure or `[:pundit_scope]`)
- `authorize_and_save!`

`OperationsMethods#check_authorization_is_called` enforces this after the operation runs by calling `skip_authorization` / `skip_policy_scope` only when the operation set `result[:pundit]` / `result[:pundit_scope]` (or the operation failed). Forgetting to call any of them → `Pundit::AuthorizationNotPerformedError`.

### Policies

Policies live in `app/policies/` and inherit from `ApplicationPolicy`. There are three per-domain base policies — they are also used by `ApplicationController#user_not_authorized` to decide where to redirect on `Pundit::NotAuthorizedError`:

- `Admin::BasePolicy` — `user.admin?`. Denied → `crm_root_path` for non-admin staff, otherwise root.
- `Crm::BasePolicy` — `user.admin? || user.owner?` (extend with the staff roles your app needs). Denied → root.
- `Public::BasePolicy` — anonymous-friendly base for unauthenticated layouts.

`Admin::BaseController` runs `Admin::BasePolicy#index?` in a `before_action` to gate the whole namespace.

Policy patterns in this project:

```ruby
class Crm::PropertyPolicy < Crm::BasePolicy
  def update?
    return false unless crm_access?
    return true if user.admin?
    return true if user.owner? && record.owner_id == user.id

    false
  end

  class Scope < Crm::BasePolicy::Scope
    def resolve
      return ::Crm::Property.none unless crm_access?

      if user.admin?
        scope.all
      elsif user.owner?
        scope.where(owner_id: user.id)
      else
        ::Crm::Property.none
      end
    end
  end
end
```

## Components (`Base::Component::Base`)

```ruby
# frozen_string_literal: true

class Admin::User::Component::Index < Base::Component::Base
  def initialize(users:)
    @users = users
  end
end
```

Template at `app/concepts/admin/user/component/index.html.slim`. Components are pure presentation — they receive data via `initialize` and never fetch it themselves.

`Base::Component::Base` exists in this project (`app/concepts/base/component/base.rb`) — it's a thin subclass of `ViewComponent::Base`. Feature components inherit from it. Generic base UI primitives (`Base::Component::Btn`, `Base::Component::Table::Table`) inherit directly from `ViewComponent::Base` because they are imported elsewhere.

Use `::` prefix when referencing other components from namespaced contexts (e.g. `::Base::Component::Btn`).

## Sorting

`Base::Operation::Sortable` provides `apply_sorting(relation, params:, allowed_columns:, default_column:, default_direction:)` for index operations. Always pass an `allowed_columns` allowlist — anything outside it falls back to the default.

```ruby
include Base::Operation::Sortable

users = apply_sorting(
  policy_scope(User),
  params: params,
  allowed_columns: %i[id name email role created_at],
  default_column: :id,
  default_direction: :desc
)
```

## Domain model (illustrative — substitute your own)

The examples above assume `User` (Devise-authenticated, with a `role` enum) and a representative business resource (`Crm::Property`). Replace with your domain:

```ruby
class User < ApplicationRecord
  enum :role, { admin: 0, owner: 1, customer: 2 }
  has_many :owned_properties, class_name: "Crm::Property", foreign_key: "owner_id"
end

class Crm::Property < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "owner_id"
end
```

Roles in the policy examples (`user.admin?`, `user.owner?`) come from this enum. Customise the role list to fit your access model.

## I18n

Locale files live in `config/locales/`. Default locale and fallbacks are configured in `config/application.rb`. Always use `I18n.t('full.key')` — never `t('.relative_key')` shorthand inside components/operations, since ViewComponent doesn't resolve relative keys the way Action View does.

`ApplicationController#user_not_authorized` reads I18n keys for redirect-on-deny messages (e.g. `authorization.admin_access_denied`, `authorization.crm_access_denied`, `authorization.action_access_denied`). Add those keys to your locale files; see `.claude/docs/i18n.md`.
