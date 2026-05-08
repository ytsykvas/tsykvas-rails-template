# Routing & Namespaces

This app is split into three top-level domains. Each has its own URL namespace, layout, base controller, and base policy. Read this before adding a new controller — placement is not optional.

## Domain → namespace map

| Domain | URL prefix | Layout | Base controller | Base policy | Concepts root |
|---|---|---|---|---|---|
| **Admin** (administrators) | `/admin/...` | `app/views/layouts/admin.slim` | `Admin::BaseController` | `Admin::BasePolicy` (`user.admin?`) | `app/concepts/admin/` |
| **CRM** (business users) | `/crm/...` | `app/views/layouts/crm.slim` | `Crm::BaseController` | `Crm::BasePolicy` (admin / owner / employee / manager) | `app/concepts/crm/` |
| **Screener** (end consumers) | `/` (root) and `/screener/...` | `app/views/layouts/screener.slim` | `Screener::BaseController` | `Screener::BasePolicy` | `app/concepts/screener/` (not yet created — first feature in this domain creates it) |

Each `BaseController` runs a `before_action` that instantiates its `BasePolicy` with `current_user, nil` and raises `Pundit::NotAuthorizedError` if `policy.index?` is false. `ApplicationController#user_not_authorized` then dispatches the redirect:

| Policy class on the exception | Where the user is sent |
|---|---|
| `Admin::BasePolicy` | `crm_root_path` if owner/employee/manager, else `root_path` |
| `Crm::BasePolicy` | `crm_root_path` for crm-eligible users, else `root_path` |
| `Screener::BasePolicy` | `crm_root_path` |
| anything else | `redirect_back(fallback_location: root_path)` |

The redirect hinges on the **policy class name**, so keep `<Domain>Policy < <Domain>::BasePolicy` intact when you add new policies.

## Adding a controller

1. Inherit from the matching base controller — never from `ApplicationController` directly.
2. Mount under the matching `namespace` block in `config/routes.rb`.
3. Place operations + components under `app/concepts/<namespace>/<feature>/`.
4. Each action is a one-liner: `endpoint Op, Component` (see `concepts-refactoring.md`).

```ruby
# config/routes.rb
namespace :crm do
  resources :reports, only: [:index, :show]
end

# app/controllers/crm/reports_controller.rb
class Crm::ReportsController < Crm::BaseController
  def index
    endpoint Crm::Report::Operation::Index, Crm::Report::Component::Index
  end
end
```

## Custom (non-`resources`) routes

Some flows don't map cleanly to REST — for example `Crm::PropertyController#edit` uses a singular path with no `id` (an owner edits *their* property):

```ruby
namespace :crm do
  get "property/edit", to: "property#edit", as: :edit_property
end
```

Use a custom path when:
- the resource is implicitly the current user's (no id needed), OR
- the action name doesn't fit `index/show/new/create/edit/update/destroy` (e.g. `archive_property`, `confirm`, `archive`).

`endpoint` handles non-standard action names automatically: if the operation sets `self.redirect_path`, it redirects; otherwise it renders the component.

## How `endpoint` derives the redirect target

After a successful `create` / `update` / `destroy` (or any action name containing `destroy`), `endpoint` redirects to:

```ruby
result.redirect_path || public_send("#{controller_name}_path")
```

Two consequences:

1. **Set `self.redirect_path` explicitly** for non-trivial cases. The fallback only works if a route helper exists with the exact name `<controller_name>_path`.
2. **Controller name matters.** `Crm::propertiesController` falls back to `properties_path`, NOT `crm_properties_path`. If your controller's pluralized name doesn't match a route helper, you must set `self.redirect_path`.

## Named route helpers (cheat-sheet)

- `root_path` → `Screener::HomeController#index` (public landing)
- `screener_root_path` → same controller, namespaced URL
- `admin_root_path` → `Admin::DashboardController#index`
- `crm_root_path` → `Crm::DashboardController#index`
- `crm_edit_property_path` → `Crm::PropertyController#edit`
- `new_user_session_path` / `destroy_user_session_path` — Devise sign-in/out
- `new_user_registration_path` / `user_registration_path` — Devise sign-up (uses `Users::RegistrationsController`)
- `rails_health_check_path` → `/up` (uptime probes)

When linking from an operation, prefer route helpers via `Rails.application.routes.url_helpers`:

```ruby
self.redirect_path = Rails.application.routes.url_helpers.crm_root_path
```

## Devise routes

```ruby
devise_for :users, controllers: { registrations: "users/registrations" }
```

Only `registrations` is overridden — see `authentication.md` for the custom sign-up flow. Other Devise controllers (sessions, passwords) use defaults.

## What lives where

```
config/routes.rb                # All routes — keep namespaced
app/controllers/
  application_controller.rb     # Pundit + OperationsMethods + redirect dispatch
  admin/base_controller.rb      # layout + Admin::BasePolicy gate
  crm/base_controller.rb        # layout + Crm::BasePolicy gate
  screener/base_controller.rb   # layout + Screener::BasePolicy gate
  users/registrations_controller.rb  # custom Devise sign-up
app/policies/
  application_policy.rb         # Pundit baseline
  admin/base_policy.rb
  crm/base_policy.rb
  screener/base_policy.rb
```
