# UI Components

For visual tokens (palette, typography, geometry, motion) see [`design-system.md`](design-system.md). This page documents the component APIs that ship with the template.

## Buttons — always use `Base::Component::Btn`

```ruby
render ::Base::Component::Btn.new(type: 'add',    text: t('admin.users.new'),    path: new_admin_user_path)
render ::Base::Component::Btn.new(type: 'save',   text: t('forms.save'),         submit: true)
render ::Base::Component::Btn.new(type: 'remove', text: t('admin.users.delete'), modal_target: "delete_modal_#{user.id}")
```

Valid types: `add`, `cancel`, `check`, `edit`, `next`, `save`, `search`, `show`, `remove` (constants in `Base::Component::Btn::VALID_TYPES`). Each maps to a Bootstrap Icon and a CSS variant:

| `type` | Variant | Use |
|---|---|---|
| `add`, `save`, `next`, `search`, `cancel` | `.btn-primary` | Primary action |
| `show`, `edit` | `.btn-outline-secondary` | Secondary / informational action |
| `check` | `.btn-outline-success` | Confirm / positive action |
| `remove` | `.btn-danger` | Destructive action only |

Sizes: `XS`, `SM` / `S` (default), `M`, `L`. Use `S` for table action buttons and `L` for full-width form submits / page-header CTAs.

Other parameters: `disabled:` (Boolean), `path:` (renders `<a>`), `submit:` (renders `<button type="submit">`), `method:` (HTTP method), `data:` (hash of data attributes), `target: '_blank'`, `prefetch:` (Turbo prefetch override), `formaction:`, `modal_target:` (Bootstrap modal id without `#`).

When you need multiple buttons in a single table cell, wrap them in a flex container:

```ruby
safe_join([
  render(::Base::Component::Btn.new(type: 'show', text: t('view'), path: admin_user_path(user))),
  render(::Base::Component::Btn.new(type: 'remove', text: t('delete'), path: admin_user_path(user), method: :delete))
])
```

See [`design-system.md`](design-system.md#buttons) for the full variant catalog (including manual classes like `.btn-secondary`, `.btn-outline-light`, `.btn-ghost` not surfaced via `Btn`).

---

## Tables — always use `Base::Component::Table::Table`

Extract the table itself into a dedicated ViewComponent (e.g. `Admin::User::Component::UsersTable`). Inside, build the table imperatively:

```ruby
def call
  table = Base::Component::Table::Table.new(rows: @users)

  table.add_column(
    header: I18n.t('admin.users.index.table.id'),
    sort_field: :id,
    sort_path: @sorting_path,
    sort_data_type: 'number'
  ) { |user| user.id.to_s }

  table.add_column(
    header: I18n.t('admin.users.index.table.role'),
    sort_field: :role,
    sort_path: @sorting_path,
    sort_data_type: 'string',
    stack: { to: :mobile, prefix: :header, smaller_than: :lg },
    hide:  { smaller_than: :md }
  ) { |user| role_badge(user.role) }

  table.add_column(header: I18n.t('admin.users.index.table.actions'), type: :button) do |user|
    action_buttons(user)
  end

  render table
end
```

Column options: `header:`, `align:`, `type:` (`:regular` or `:button`), `stack:` (collapse columns on small screens — `{ to:, prefix:, smaller_than: }`), `hide:` (`{ smaller_than: }`), `sort_field:`, `sort_path:`, `sort_data_type:` (`'number'` / `'string'`), and a `&block` returning the cell content.

Sortable columns require a `sort_path` matching the controller's index path; the operation must use `Base::Operation::Sortable#apply_sorting` with the same allowlist.

`Table#format_date(date)` is a helper that returns a locale-formatted date string (configured in `config/locales/<locale>.yml` under `date.formats.default`).

Action buttons inside cells use `.table-action-btn` (square hairline 32px) — see [`design-system.md`](design-system.md#tables).

---

## Title row — `Base::Component::TitleRow`

```ruby
render ::Base::Component::TitleRow.new(
  title: I18n.t('admin.users.index.title'),
  back_path: admin_root_path,
  back_text: I18n.t('common.back'),
  divider: true
)
```

Renders a header with optional back-link and `<hr>` divider. Configure via `Base::Component::TitleRowConfig` if you need to share configuration across pages. The `<h1>` it renders inherits typography from your design-system stylesheet.

---

## Stat cards (dashboard tiles)

Replacement for the colored Bootstrap `.card.bg-primary/.bg-success/.bg-warning` tiles. Two visual variants — both use neutral surfaces and rely on type/spacing for hierarchy rather than colour.

```slim
.stat-card.stat-card--emphasis
  span.stat-card-label = I18n.t('admin.dashboard.users.title')
  span.stat-card-figure = users_count
  p.stat-card-description = I18n.t('admin.dashboard.users.description')

.stat-card
  span.stat-card-label = I18n.t('admin.dashboard.properties.title')
  span.stat-card-figure = properties_count
  p.stat-card-description = I18n.t('admin.dashboard.properties.description')
```

- **`.stat-card--emphasis`** — primary-coloured surface, inverse text. Use for ONE primary metric per dashboard.
- **`.stat-card`** — neutral hairline-bordered card. Use for everything else.

Structure parts:
- `.stat-card-label` — uppercase small label.
- `.stat-card-figure` — large display number.
- `.stat-card-description` — small body line.

Lay them out inside `.row.g-4` with `.col-md-4` (Bootstrap grid). Don't put more than ~3 in a row.

---

## Forms

ViewComponent does not auto-mix Rails form helpers. Inside Slim templates of components, call `simple_form_for` via `helpers.`:

```slim
= helpers.simple_form_for @property, url: crm_edit_property_path, method: :patch do |f|
  = f.input :name, label: t('crm.property.edit.name'), placeholder: t('crm.property.edit.name_placeholder')
  = render ::Base::Component::Btn.new(type: 'save', text: t('crm.property.edit.submit'), submit: true)
```

For new/edit pages, follow the **Form / New / Edit** triad:

- `form.rb` + `form.html.slim` — shared form fields
- `new.rb` — subclass that sets title/breadcrumbs, embeds `Form`
- `edit.rb` — same, for edit

Two visual variants:

| Class | Use |
|---|---|
| `.form-control` | Standard forms (CRM, admin) — boxed input, hairline border, primary focus halo |
| `.form-control--underline` | Auth pages — no box, just bottom hairline that thickens on focus |

`auth.scss` automatically applies underline-style inputs to anything inside `.auth-form`. For non-auth forms use the standard `.form-control`.

See [`forms.md`](forms.md) for the full form pattern.

---

## Section / overline text

Utility classes for small uppercase labels (used as section titles, stat-card labels):

```slim
span.section-label = I18n.t('ui.sections.workspace')
```

Pair with a display heading below for editorial dashboard headers:

```slim
.dashboard-header
  span.section-label = I18n.t('ui.sections.administration')
  h1.mb-0.mt-2 = I18n.t('admin.navbar.dashboard')
  hr.divider
```

Define `.section-label` as a small uppercase tracked label in your design system; `.divider` as a hairline border divider.

---

## Layouts

Three top-level layouts under `app/views/layouts/` (one per top-level concept namespace):

- `admin.slim` — used by `Admin::BaseController` (renders the admin sidebar)
- `crm.slim` — used by CRM controllers
- `public.slim` — public-facing layout for unauthenticated visitors
- `application.html.erb` — default Devise wrapper (sign-in / sign-up)

All layouts load the same stylesheet entry (`application.bootstrap.scss` by default — see `design-system.md`).

`Shared::Sidebar::*` and `Shared::Navbar::*` live under `app/concepts/shared/`.

---

## Other base components

- `Base::Component::Btn` / `Base::Component::BtnConfig` — buttons (above)
- `Base::Component::Table::Table` / `TableRow` — tables (above)
- `Base::Component::TitleRow` / `TitleRowConfig` — page headers (above)
- `Base::Component::InformationCard` (`+ InformationCardConfig`) — detail card on user-show / property-show pages. Header strip + hairline divider + monogram tile (square, no rounded avatar).
- `Shared::Navbar::Component::*` — top navigation per domain
- `Shared::Sidebar::Component::*` — sidebar per domain
