# Testing — Spec Examples by Type

## Operation

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Property::Operation::Edit do
  subject(:result) do
    described_class.call(params: ActionController::Parameters.new, current_user: user)
  end

  let(:user)    { create(:user, :owner) }
  let!(:property) { user.owned_property || create(:property, owner: user) }

  describe '#perform!' do
    context 'when user is owner of the property' do
      it 'is successful' do
        expect(result).to be_success
      end

      it 'returns the property wrapped in OpenStruct' do
        expect(result.model.property).to eq(property)
      end
    end

    context 'when user has no access to CRM' do
      let(:user) { create(:user, :customer) }

      it 'returns no records via policy_scope' do
        expect(result.model.property).to be_nil
      end
    end
  end
end
```

- Always test the authorization happy path AND the `Pundit::NotAuthorizedError` (or empty `policy_scope`) case.
- Use `change(...).by(n)` for DB count assertions.
- Pass `current_user:` and `params:` explicitly — every operation requires both.

## Component

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::User::Component::Index, type: :component do
  let(:users)     { create_list(:user, 3, :customer) }
  let(:component) { described_class.new(users: users) }

  it 'renders the table' do
    render_inline(component)
    expect(page).to have_text(I18n.t('admin.users.index.table.email'))
    users.each { |u| expect(page).to have_text(u.email) }
  end

  describe '#role_badge' do
    subject { component.send(:role_badge, 'admin') }
    it { is_expected.to include('badge bg-danger') }
  end
end
```

- Use `render_inline` + Capybara matchers for rendered output.
- Test private helpers via `.send(:method_name)`.
- Declare `type: :component` (not inferred from path).

## Model

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to belong_to(:property).optional }
  it { is_expected.to have_one(:owned_property).class_name('Crm::Property') }
  it do
    is_expected.to define_enum_for(:role)
      .with_values(admin: 0, customer: 1, owner: 2, employee: 3, manager: 4)
  end
end
```

- Use Shoulda-Matchers for validations and associations.
- Prefer `build` over `create` for validation tests.
- Declare `type: :model` (not inferred).

## Policy

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::PropertyPolicy do
  subject { described_class.new(user, property) }

  let(:owner)   { create(:user, :owner) }
  let(:property) { owner.owned_property }

  context 'when user is the owner' do
    let(:user) { owner }

    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
  end

  context 'when user is a different owner' do
    let(:user) { create(:user, :owner) }

    it { is_expected.not_to permit_action(:update) }
  end

  describe 'Scope' do
    subject(:resolved) { described_class::Scope.new(user, Crm::Property).resolve }

    let(:user) { create(:user, :admin) }
    before { create(:property, owner: create(:user, :owner)) }

    it { is_expected.to eq(Crm::Property.all) }
  end
end
```

## Controller / request

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::UsersController, type: :controller do
  let(:admin) { create(:user, :admin) }

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(admin)
  end

  describe 'GET #index' do
    it 'returns 200' do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end
end
```

- Always stub `authenticate_user!` and `current_user` in controller specs.
- Declare `type: :controller` or `type: :request` explicitly.

## Operation with sub-operations

```ruby
RSpec.describe Crm::Property::Operation::Create do
  subject(:result) do
    described_class.call(params: params, current_user: nil)
  end

  let(:params) do
    ActionController::Parameters.new(
      user: { name: 'Foo', email: 'foo@example.com', password: 'password', password_confirmation: 'password' },
      property_name: 'Riverside House'
    )
  end

  it 'creates a user with role :owner and a property' do
    expect { result }.to change(User, :count).by(1).and change(Crm::Property, :count).by(1)
    expect(result).to be_success
  end
end
```
