# Authentication (Devise)

Auth uses **Devise** with the modules: `:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable` (see `app/models/user.rb`). Lockable / confirmable / trackable / timeoutable / omniauthable are NOT enabled — don't reach for `confirmation_sent_at` etc. unless you also turn them on.

## Routes

```ruby
# config/routes.rb
devise_for :users, controllers: { registrations: "users/registrations" }
```

Only `registrations` is overridden. Sessions and passwords use Devise defaults.

## Permitted parameters

`ApplicationController#configure_permitted_parameters` runs on every Devise request:

```ruby
devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role])
devise_parameter_sanitizer.permit(:account_update, keys: [:name, :role])
```

When you add a new column the user can edit, add it to both `:sign_up` and `:account_update`.

## Custom registration flow (optional)

If your app needs a richer sign-up — for example, atomically creating a related resource (an organisation, a tenant, a profile) when a user picks the "owner" role — override Devise's `RegistrationsController`:

```ruby
# config/routes.rb
devise_for :users, controllers: { registrations: "users/registrations" }
```

```ruby
# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  def create
    ActiveRecord::Base.transaction do
      build_resource(sign_up_params)
      resource.save || (raise ActiveRecord::Rollback)
      # create related records here, then promote roles if needed
    end
    super
  end
end
```

Why a transaction: cross-record validations ("owner must have a related X" + "X must have an owner") create a chicken-and-egg. A transaction lets you save the User first as a base role, build dependents inside the same transaction (with `save(validate: false)` for the inner record), then promote the User and re-validate everything at commit.

## Where redirects go after sign-up

```ruby
def after_sign_up_path_for(resource)
  resource.owner? ? crm_root_path : super
end
```

Override `after_sign_up_path_for` only if a specific role needs a non-default landing page. Otherwise Devise's default (`stored_location_for(resource) || root_path`) is correct.

## Sign-out / unauthorized redirects

Pundit failures route through `ApplicationController#user_not_authorized` — see `routing-and-namespaces.md` for the redirect matrix.

## I18n

Devise strings live in `config/locales/devise.<locale>.yml` (separate from your app locales). The custom-flow flash messages use:

- `set_flash_message! :notice, :signed_up` — Devise's standard key
- `I18n.t("authorization.admin_access_denied" | "crm_access_denied" | "action_access_denied")` — defined in your app locales

When you add a new flash, decide: Devise-flow → `devise.<locale>.yml`; app-flow → your app locales.

## Stubbing auth in tests

```ruby
# Controller spec
before do
  allow(controller).to receive(:authenticate_user!).and_return(true)
  allow(controller).to receive(:current_user).and_return(user)
end

# Operation spec — pass current_user explicitly
described_class.call(params: params, current_user: build(:user, :owner)  # adjust trait to match your factories)
```

For request specs, `sign_in(user)` works (Devise test helpers are loaded via `rails_helper`).

## Adding new fields

Steps when adding a new attribute users can set during sign-up or edit:

1. Migration → add column.
2. Model → validation if needed.
3. `ApplicationController#configure_permitted_parameters` → add the attribute to `:sign_up` and/or `:account_update`.
4. Devise views (`app/views/devise/...`) → add the field to the form.
5. Locales → add the label/placeholder to `devise.<locale>.yml` and your app locales.
