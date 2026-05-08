# Testing Guide

## Framework & Setup

- **RSpec** + `rails_helper` (required in every spec file)
- **FactoryBot** — `create`, `build`, `build_stubbed` available globally (`config.include FactoryBot::Syntax::Methods` in `spec/rails_helper.rb`)
- **Faker** — realistic test data; unique sequences cleared between examples (`Faker::UniqueGenerator.clear`)
- **Shoulda-Matchers** — model/association matchers (configured for `:rspec` + `:rails`)
- **Capybara + selenium-webdriver** — system tests
- `config.use_transactional_fixtures = true` — DB isolation per test
- `infer_spec_type_from_file_location!` is **NOT** enabled — declare `type:` explicitly when needed (`type: :request`, `type: :component`, `type: :model`, ...)

## File location

Mirror `app/` in `spec/`:

| Source | Spec |
|---|---|
| `app/concepts/admin/user/operation/index.rb` | `spec/concepts/admin/user/operation/index_spec.rb` |
| `app/concepts/admin/user/component/users_table.rb` | `spec/concepts/admin/user/component/users_table_spec.rb` |
| `app/policies/admin/base_policy.rb` | `spec/policies/admin/base_policy_spec.rb` |
| `app/models/user.rb` | `spec/models/user_spec.rb` |
| `app/controllers/admin/users_controller.rb` | `spec/controllers/admin/users_controller_spec.rb` (or `spec/requests/admin/users_spec.rb`) |

## Spec structure

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::User::Operation::Show do
  subject(:result) do
    described_class.call(params: { id: target_user.id }, current_user: admin_user)
  end

  let(:admin_user)  { create(:user, :admin) }
  let(:target_user) { create(:user, :customer) }

  describe '#perform!' do
    context 'when user is admin' do
      it 'returns success' do
        expect(result).to be_success
      end

      it 'returns the user wrapped in OpenStruct' do
        expect(result.model.user).to eq(target_user)
      end
    end

    context 'when user is not admin' do
      let(:admin_user) { create(:user, :customer) }

      it 'raises Pundit::NotAuthorizedError' do
        expect { result }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end
```

- Use `described_class`, `let` (lazy), `let!` only when a record must exist before the example.
- `describe` → `context` → `it`; one logical assertion per example.
- Always test the **happy path** AND the **`Pundit::NotAuthorizedError` path** for operations.

## Factories

`spec/factories/users.rb` already defines traits: `:admin`, `:customer`, `:owner`, `:employee`, `:manager`, `:with_property`. Reuse them:

```ruby
let(:admin)    { create(:user, :admin) }
let(:owner)    { create(:user, :owner) }
let(:employee) { create(:user, :employee) }
```

Rules for new factories:

- Always use **Faker** with `unique` for unique fields (`Faker::Internet.unique.email`).
- Use `trait` for variations.
- Use `association` for required relations.
- Prefer `build` over `create` in unit tests; `build_stubbed` for attribute-only logic.

## Mocks, stubs & doubles

Prefer `instance_double` (verifies interface) over plain `double`. Use plain `double` only for value objects.

```ruby
# Setup in before, assert separately
before { allow(service).to receive(:call).and_return(result) }
it { expect(service).to have_received(:call).once }

# Controller auth stubs
before do
  allow(controller).to receive(:authenticate_user!).and_return(true)
  allow(controller).to receive(:current_user).and_return(user)
end
```

If you need HTTP stubbing later, add WebMock and `stub_request` — the project doesn't currently use it.

## Running tests

```bash
bundle exec rspec                                                        # all
bundle exec rspec spec/concepts/admin/user/operation/show_spec.rb        # single file
bundle exec rspec spec/models/user_spec.rb:42                            # by line
bundle exec rspec --tag focus                                            # by tag
```

## Anti-patterns

- ❌ `FactoryBot.create` — use shorthand `create`
- ❌ Hardcoded strings in factories — use Faker
- ❌ `double` when `instance_double` is available
- ❌ `expect(...).to receive(...)` in `before` — use `allow` + `have_received`
- ❌ Skipping authorization assertions for operations
- ❌ Writing tests unless explicitly requested by the user
