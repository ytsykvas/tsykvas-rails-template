# Design System

> **This is a Bootstrap-default starting point.** Customise tokens, typography, and component patterns to match your brand. The structure below shows what to document so future contributors (humans and AI) know the rules.

The shipped install wires `bootstrap` 5.3 + `dartsass-rails` and pre-compiles `app/assets/stylesheets/application.bootstrap.scss` → `app/assets/builds/application.css`. All tokens below come from Bootstrap's CSS custom properties unless your app overrides them.

If you change SCSS in `app/assets/stylesheets/` or add a new visual primitive under `app/concepts/base/component/`, update this file in the same PR.

## Principles

1. **Tokens before values.** Use `--bs-primary` / `$primary`, never hex literals.
2. **Type over colour.** Hierarchy comes from spacing and type weight first, colour second.
3. **One destructive cue.** `--bs-danger` (or your override) is reserved for destructive / single-CTA contexts. Don't sprinkle it.
4. **Components beat CSS.** New visual rules belong in `Base::Component::*` (or a sibling), not in inline class soup.
5. **One stylesheet entrypoint.** Everything imports from `application.bootstrap.scss`. No per-feature global CSS files.

## Tokens

### Palette — light mode (Bootstrap defaults)

```scss
$primary:     #0d6efd;   // --bs-primary
$secondary:   #6c757d;   // --bs-secondary
$success:     #198754;   // --bs-success
$info:        #0dcaf0;   // --bs-info
$warning:     #ffc107;   // --bs-warning
$danger:      #dc3545;   // --bs-danger
$light:       #f8f9fa;   // --bs-light
$dark:        #212529;   // --bs-dark
```

Surface tokens (page background, body text, hairline borders):

```scss
$body-bg:      #fff;
$body-color:   #212529;
$border-color: #dee2e6;
```

To rebrand: override the SCSS variables **above** the `@import "bootstrap"` line in `application.bootstrap.scss`. Bootstrap's `_variables.scss` uses `!default`, so your override wins.

```scss
// application.bootstrap.scss
$primary: #1F3D2C;       // your brand primary
$body-bg: #F4EFE6;       // your page background
@import "bootstrap";
```

### Palette — dark mode

Bootstrap 5.3 ships `data-bs-theme="dark"` switching via attribute. Toggle via a Stimulus controller (see `stimulus-controllers.md` — there's a `theme_controller.js` template that mirrors `data-bs-theme` on `<body>` from a `localStorage` toggle).

To customise dark-mode tokens, override `[data-bs-theme="dark"]` after the import:

```scss
@import "bootstrap";

[data-bs-theme="dark"] {
  --bs-body-bg: #1a1a1a;
  --bs-body-color: #e9ecef;
}
```

### Typography

Bootstrap default: system font stack (`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, ...`). Sizes:

| Token | Default | Use |
|---|---|---|
| `$h1-font-size` | 2.5rem | Page hero headings |
| `$h2-font-size` | 2rem | Section headings |
| `$h3-font-size` | 1.75rem | Sub-section headings |
| `$h4-font-size` | 1.5rem | Card / dashboard tile headings |
| `$h5-font-size` | 1.25rem | Form section headings |
| `$h6-font-size` | 1rem | Inline labels (caps + tracking) |
| `$font-size-base` | 1rem | Body |
| `$font-size-sm` | 0.875rem | Helper text, table headers |

To swap fonts (e.g. a Google Font for headings, Inter for body):

```scss
$font-family-sans-serif: "Inter", system-ui, -apple-system, sans-serif;
$headings-font-family: "Playfair Display", Georgia, serif;  // optional
@import "bootstrap";
```

Then add `<link>` tags or `@import url(...)` in your stylesheet. Document the exact fonts here once chosen.

### Geometry

```scss
$border-radius:    0.375rem;   // default cards, inputs, buttons
$border-radius-sm: 0.25rem;    // badges, small chips
$border-radius-lg: 0.5rem;     // modals, alerts
$border-radius-xl: 1rem;       // hero-section panels (rare)
$border-radius-pill: 50rem;    // pills (avoid for primary CTAs)
```

Spacing scale — Bootstrap's `0` through `5`:

| Token | Value | Common use |
|---|---|---|
| `$spacer` | 1rem | Base unit |
| `0` | 0 | Reset |
| `1` | 0.25rem | Inline gap |
| `2` | 0.5rem | Component-internal spacing |
| `3` | 1rem | Card body padding |
| `4` | 1.5rem | Section spacing |
| `5` | 3rem | Page-level rhythm |

Use the utility classes (`.p-3`, `.mb-4`, `.gap-2`) — don't hand-roll margins in component SCSS.

### Motion

Bootstrap ships `--bs-transition` and component-specific durations. Defaults work for most cases; customise via:

```scss
$transition-base: all 0.2s ease-in-out;
$transition-fade: opacity 0.15s linear;
$transition-collapse: height 0.35s ease;
```

Reduce-motion: respect `@media (prefers-reduced-motion: reduce)` in custom animations — Bootstrap already does this for built-ins.

## Component catalog

### Buttons (`Base::Component::Btn`)

Wraps Bootstrap `<button>` / `<a>` with a typed API. See [`ui-components.md`](ui-components.md#buttons-always-use-basecomponentbtn) for full props. Visual rules:

- One `.btn-primary` per page (primary action).
- Use `.btn-outline-secondary` for secondary actions.
- Reserve `.btn-danger` for destructive operations.
- Avoid pill-shaped buttons (`$border-radius-pill`) for primary CTAs.

Sizes via `$btn-padding-y-{sm,lg}` / `$btn-font-size-{sm,lg}`. Stick to the `XS` / `SM` / `M` / `L` mapping in `Base::Component::Btn`.

### Stat cards (dashboard tiles)

```scss
.stat-card {
  background: var(--bs-body-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: var(--bs-border-radius);
  padding: 1.5rem;
}

.stat-card--emphasis {
  background: var(--bs-primary);
  color: var(--bs-white);
  border-color: var(--bs-primary);
}

.stat-card-label {
  text-transform: uppercase;
  letter-spacing: 0.18em;
  font-size: 0.75rem;
  color: var(--bs-secondary-color);
}

.stat-card-figure {
  font-size: 3rem;
  font-weight: 600;
  display: block;
}

.stat-card-description {
  font-size: 0.875rem;
  color: var(--bs-secondary-color);
  margin: 0;
}
```

Use one `.stat-card--emphasis` per dashboard for the primary metric; `.stat-card` for everything else.

### Information card (`Base::Component::InformationCard`)

Detail card pattern used on user-show / property-show pages. Composition:

- Header strip — `padding: 1rem 1.5rem; background: var(--bs-light);`
- Monogram tile — square 48px hairline-bordered, no rounded avatar
- `.section-title` rendered as small uppercase label + hairline divider

### Cards (general)

Bootstrap's `.card` defaults are fine. Augment with `.card.shadow-sm` for elevated cards (e.g. the gem's Home example). Don't reach for `box-shadow: 0 4px 12px ...` per-component — use the shadow tokens.

```scss
$box-shadow-sm: 0 .125rem .25rem rgba($black, .075);
$box-shadow:    0 .5rem 1rem rgba($black, .15);
$box-shadow-lg: 0 1rem 3rem rgba($black, .175);
```

### Tables (`Base::Component::Table::Table`)

Hairline tables, no zebra striping by default. Action buttons inside cells use `.table-action-btn` (32px square hairline). Wrap inside `.table-responsive` for mobile collapse.

### Forms

Two visual variants:

- `.form-control` — Bootstrap default. Boxed input, hairline border, primary focus halo.
- `.form-control--underline` — auth-page variant: no box, just a bottom hairline that thickens on focus.

```scss
.form-control--underline {
  border: 0;
  border-bottom: 1px solid var(--bs-border-color);
  border-radius: 0;
  padding-left: 0;
  padding-right: 0;

  &:focus {
    box-shadow: none;
    border-bottom-width: 2px;
    border-bottom-color: var(--bs-primary);
  }
}
```

Apply the underline variant via a wrapping `.auth-form` selector — see `auth.scss`.

### Sidebar (`Shared::Sidebar::Component`)

Full-height left rail, hairline divider on the right edge. Nav links use `display: flex; width: 100%;` so the active/hover bar spans the full width — don't override.

### Navbar

Top bar, hairline divider on the bottom edge. The brand-lockup composition (logo + wordmark) lives in `Shared::Navbar::*`.

### Auth (sign-in / sign-up / edit profile)

Centred card, no sidebar/navbar. Uses `.form-control--underline` inputs and a single `.btn-primary` submit. Sign-up form fields belong in `app/views/devise/registrations/new.html.slim`.

## Utility classes

### Typography

- `.section-label` — small uppercase tracked label (use for stat-card labels, navigational micro-headers).
- `.caps` — looser uppercase tracking (0.12em).
- `.figure` / `.figure-lg` — large display numbers.
- `.display-1` through `.display-6` — Bootstrap's display headings.

### Color

Use Bootstrap's `.text-{primary,secondary,muted,success,warning,danger,info,light,dark}` and matching `.bg-*`. Don't introduce new colour utilities for one-offs — reach for a token override instead.

### Layout

- `.container` / `.container-fluid` — Bootstrap's responsive containers.
- `.row.g-{0..5}` — flex grid with gap.
- `.col-{xs,sm,md,lg,xl}-{1..12}` — column spans.
- `.d-flex` / `.gap-{1..5}` / `.justify-content-*` / `.align-items-*` — flex utilities.

## I18n integration

Brand-/UI-only strings live under a dedicated `ui:` namespace (see `i18n.md`):

```yaml
en:
  ui:
    sections:
      workspace: "Workspace"
      account: "Account"
      administration: "Administration"
    brand:
      tagline: "..."
      year: "2026"
```

Reference via `I18n.t('ui.sections.workspace')`. Keep typographic constants identical across locales (`year: "2026"` is the same in every locale).

## Antipatterns

### Color

- ❌ Hex literals scattered through component CSS → ✅ tokens (`var(--bs-primary)`, `$primary`).
- ❌ Coloured Bootstrap card backgrounds (`.card.bg-primary` for stats) → ✅ `.stat-card` / `.stat-card--emphasis`.
- ❌ Using `--bs-danger` for non-destructive UI just because it stands out → ✅ reserve danger for destructive/CTA only.

### Geometry

- ❌ `border-radius: 9999px` (pill shape) on primary action buttons → ✅ `$border-radius` (default).
- ❌ Custom `box-shadow: 0 4px 12px ...` per component → ✅ `$box-shadow-sm` / `$box-shadow`.

### Typography

- ❌ Inline `font-family` overrides on individual elements → ✅ set once in `$font-family-sans-serif` / `$headings-font-family`.
- ❌ Hardcoded `text-uppercase` + inline `letter-spacing` → ✅ `.section-label` / `.caps` utility class.
- ❌ Inline font-size literals (`font-size: 14px`) → ✅ `$font-size-sm` token.

### Components

- ❌ Hand-rolled buttons / cards / modals → ✅ use `Base::Component::*` or Bootstrap directly.
- ❌ Class soup (`class="bg-primary text-white text-center fw-bold p-3 rounded shadow"`) → ✅ extract a small SCSS utility class or component partial.
- ❌ `Base::Component::Btn` calls without leading `::` from inside another component → ✅ `::Base::Component::Btn.new(...)` (constant lookup).

### Layout / interaction

- ❌ Per-page custom margins → ✅ Bootstrap spacing utilities (`.mb-4`, `.gap-3`).
- ❌ Sidebar `.nav-link` without `display: flex; width: 100%` → ✅ active bar must span full sidebar width.
- ❌ `active_nav_class('/crm')` for a dashboard link (matches every CRM page) → ✅ `active_nav_class('/crm', '/crm/dashboard', exact: true)`.

## Adding new tokens or components

1. **Add the token to `application.bootstrap.scss`** above the `@import "bootstrap"` line.
2. **Document it in this file** under the appropriate section.
3. **If it's component-shaped**, create a sibling under `Base::Component::*` and document the API in [`ui-components.md`](ui-components.md).
4. **Run `bin/rails dartsass:build`** locally to verify the SCSS compiles without warnings.
5. **Update the antipatterns** if the new token replaces an existing pattern (so future contributors don't reach for the old one).

## File map

```
app/assets/stylesheets/
  application.bootstrap.scss   # entry point — your overrides + @import "bootstrap"
  components/                  # per-component SCSS partials (stat-card, info-card, ...)
  utilities/                   # custom utility classes (.section-label, .caps, ...)
  layouts/                     # per-layout SCSS (sidebar, navbar, auth, ...)

app/concepts/base/component/   # Ruby ViewComponents (Btn, Table, TitleRow, InformationCard, ...)
```
