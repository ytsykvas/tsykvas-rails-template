# Forms — when to introduce a Form object

The default flow for simple CRUD is to permit params directly inside the
operation:

```ruby
class Crm::Property::Operation::Create < ::Base::Operation::Base
  def perform!(params:, current_user:)
    property = Crm::Property.new
    authorize! property, :create?

    property.assign_attributes(property_params(params))
    property.save!

    self.model = property
    self.redirect_path = crm_property_path(property)
    notice(I18n.t("crm.property.create.success"))
  end

  private

  def property_params(params)
    params.require(:property).permit(:name, :description)
  end
end
```

This is fine when the form maps 1:1 to ActiveRecord columns. Once the form
gets non-trivial, **promote `_params` into a dedicated `<Concept>::Form`
class** instead of growing the operation.

## When to promote to a Form object

Introduce a `Form` class as soon as **any** of these is true:

- The form has **virtual attributes** that aren't AR columns (e.g. a
  settlement reference, an external API code, raw address pieces that resolve
  to a city_id).
- The form needs **pre-assignment cleanup** (deep symbolize, reject blanks,
  coerce arrays, normalize booleans).
- The form **calls a sub-operation mid-assignment** (e.g. resolving a
  `settlement_ref` to a `city_id` before the AR record is saved).
- The form aggregates **multiple AR records** under one submit (e.g.
  parent + nested has_many with custom permit logic).
- Strong params alone can't express the rule (conditional permits, branches
  by user role, attributes coming from multiple top-level keys).

If none of those hold, keep the inline `_params` method. **Do not introduce
a Form object preemptively** — simple CRUD does not need the indirection.

## The pattern

Layout:

```
app/concepts/<feature>/
├── form.rb               <- the Form class
├── operation/
│   ├── create.rb         <- uses the Form
│   ├── update.rb         <- uses the Form
│   └── …
└── component/…
```

Class shape:

```ruby
class <Concept>::Form
  ASSIGNABLE_TO_AR    = %i[name description …].freeze
  ASSIGNABLE_NESTED   = %i[photos_attributes working_hours_attributes].freeze
  VIRTUAL_ATTRIBUTES  = %i[external_ref settlement_name source_code].freeze

  attr_reader :record, *VIRTUAL_ATTRIBUTES

  delegate :valid?, :invalid?, :errors, :save, :save!, to: :record

  def initialize(record)
    @record = record
    VIRTUAL_ATTRIBUTES.each { |a| instance_variable_set("@#{a}", nil) }
  end

  def assign(raw_params)
    return self if raw_params.blank?

    permitted = sanitize(raw_params)
    extract_virtual_attributes!(permitted)
    @record.assign_attributes(permitted)
    self
  end

  private

  def sanitize(raw_params)
    raw = raw_params.respond_to?(:to_unsafe_h) ? raw_params.to_unsafe_h : raw_params.to_h
    sym = raw.deep_symbolize_keys

    permitted = {}
    ASSIGNABLE_TO_AR.each   { |k| permitted[k] = sym[k] if sym.key?(k) }
    ASSIGNABLE_NESTED.each  { |k| permitted[k] = sym[k] if sym.key?(k) }
    VIRTUAL_ATTRIBUTES.each { |k| permitted[k] = sym[k] if sym.key?(k) }
    permitted
  end

  def extract_virtual_attributes!(permitted)
    VIRTUAL_ATTRIBUTES.each do |a|
      next unless permitted.key?(a)

      instance_variable_set("@#{a}", permitted.delete(a))
    end
  end
end
```

Usage from the operation:

```ruby
def perform!(params:, current_user:)
  record = <Resource>.new
  authorize! record, :create?

  form = <Concept>::Form.new(record).assign(params[:<concept>])
  apply_external_resolution!(form, current_user) if form.external_ref.present?

  record.save!

  self.model = record
  self.redirect_path = "/<plural>/#{record.id}"
  notice(I18n.t("<concept>.create.success"))
end

private

def apply_external_resolution!(form, current_user)
  result = <Concept>::Operation::ResolveSomething.call(
    params: { ref: form.external_ref },
    current_user: current_user
  )

  if result.failure?
    form.record.errors.add(:base, I18n.t("<concept>.create.errors.unresolved"))
    raise ActiveRecord::RecordInvalid.new(form.record)
  end

  form.assign_resolved!(result.model)
end
```

## What NOT to do

- **Do not put complex param logic inside the operation's `_params` method.**
  Once you need virtual attributes, conditional permits, or sub-operations,
  promote to a Form object.
- **Do not use Reform, dry-validation, or other DSL gems.** This stack is
  intentionally plain Ruby — Form objects are POROs that delegate validations
  to the AR record.
- **Do not skip `authorize!`** because the Form is involved. The operation
  still authorizes the AR record before calling `form.assign(...)`.
- **Do not generate a Form via the concept generator.** The
  `tsykvas_rails_template:concept` scaffold intentionally emits the inline
  `_params` shape — it covers the simple case. Promote by hand when the
  form actually needs it.

## Checklist when promoting

1. Move strong-params logic out of the operation into `app/concepts/<feature>/form.rb`.
2. Update `Operation::Create` and `Operation::Update` to call
   `Form.new(record).assign(params[:concept])` instead of
   `record.assign_attributes(_params(params))`.
3. Add a spec for the Form: `spec/concepts/<feature>/form_spec.rb`. Test that
   permitted attributes are kept, virtual attributes are extracted into reader
   methods, and unknown keys are rejected.
4. If virtual attributes drive a sub-operation, write a request spec
   exercising the failure path (e.g. unresolvable settlement) so the
   `add_error` + `raise ActiveRecord::RecordInvalid` flow is covered.
