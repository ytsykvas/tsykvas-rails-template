# Stimulus Controllers

All JavaScript interactivity uses **Hotwire Stimulus**. Controllers live in `app/javascript/controllers/`.

## File naming & registration

Controllers are auto-loaded via `eagerLoadControllersFrom` (`app/javascript/controllers/index.js`) — **no manual registration needed**.

- `controllers/dropdown_controller.js` → identifier `dropdown`
- `controllers/navbar_controller.js` → identifier `navbar`
- `controllers/some_feature/loader_controller.js` → identifier `some-feature--loader`

Rules:

- Filename: `snake_case_controller.js`
- Underscores → hyphens in the identifier
- Subdirectory separator → `--` in the identifier
- Group related controllers in a subdirectory

## Controller structure

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "result"]
  static values  = { delay: { type: Number, default: 300 } }

  connect() {
    // called when element is added to DOM
  }

  disconnect() {
    // clean up any external event listeners here
  }
}
```

Always `export default class extends Controller` — never name the class.

## Targets, values, outlets

- **targets** — DOM references; auto-generates `this.inputTarget`, `this.inputTargets`, `this.hasInputTarget`
- **values** — reactive typed properties; use typed defaults: `{ type: String, default: 'all' }`
- **outlets** — cross-controller communication (rare; prefer Turbo events)

Use `this.has*Target` guard before accessing optional targets:

```js
if (this.hasLoaderTarget) {
  this.loaderTarget.style.display = 'none'
}
```

## Event listeners on `document` / outside the element

Use **arrow-function class fields** so `this` is preserved, and **always remove them in `disconnect()`**:

```js
connect() {
  document.addEventListener("turbo:submit-start", this.handleSubmitStart)
}

disconnect() {
  document.removeEventListener("turbo:submit-start", this.handleSubmitStart)
}

handleSubmitStart = (event) => {
  if (this.element.contains(event.target)) { ... }
}
```

Never add document-level listeners with `.bind(this)` in `connect()` — the bound function is a new reference each call, so you can't `removeEventListener` it. (Existing controllers like `dropdown_controller.js` use `this.boundXxx = handler.bind(this)` and store the reference; that works too — but arrow-function class fields are simpler.)

Always scope handlers to `this.element.contains(event.target)` to avoid reacting to other frames/forms.

## Turbo integration

Useful Turbo lifecycle events:

- `turbo:load` / `turbo:render` — page navigated
- `turbo:submit-start` / `turbo:submit-end` — form submission
- `turbo:before-fetch-request` — any Turbo fetch starts
- `turbo:frame-load` — Turbo Frame finished loading

## Bootstrap integration

Bootstrap is loaded globally and exposed as `window.bootstrap`:

```js
new window.bootstrap.Modal(this.element).show()
new window.bootstrap.Tooltip(this.element)
window.bootstrap.Dropdown.getInstance(this.element)
```

No import needed.

## Passing data from Rails to Stimulus

Use `data-*-value` attributes for scalar values and `data-*-param` on action elements:

```slim
div data-controller="users-search"
    input data-action="input->users-search#search" data-users-search-target="input"
    button data-action="click->users-search#clear" data-users-search-default-param="all"
```

```js
search() { this.fetchResults(this.inputTarget.value) }

clear({ params: { default: defaultValue } }) {
  this.inputTarget.value = defaultValue || ''
}
```

## Debouncing

```js
connect() { this.timeout = null }

search() {
  clearTimeout(this.timeout)
  this.timeout = setTimeout(() => this.performSearch(), this.delayValue)
}

disconnect() { clearTimeout(this.timeout) }
```

## What belongs in a Stimulus controller vs. elsewhere

- UI interactivity (show/hide, toggle, debounce, modals) — Stimulus
- Fetching data / form submissions — Turbo (frames, streams); controllers only trigger or react
- Application-wide state / complex logic — keep minimal; split into focused controllers
- Third-party widget init (Bootstrap, etc.) — `connect()` / `disconnect()` lifecycle

Keep controllers small and single-purpose.

## Existing controllers (reference)

| File | Identifier | Purpose |
|---|---|---|
| `application.js` | — | Stimulus app bootstrap |
| `index.js` | — | `eagerLoadControllersFrom` registration |
| `dropdown_controller.js` | `dropdown` | Bootstrap dropdown lifecycle + click-outside-to-close. Uses `boundXxx = handler.bind(this)` pattern (legacy) — new controllers should prefer arrow-function class fields. |
| `navbar_controller.js` | `navbar` | Top navbar interactions (mobile collapse, active link highlighting). |
| `theme_controller.js` | `theme` | Light/dark theme toggle. Persists choice in `localStorage`, sets `data-theme` and `data-bs-theme` on `<html>` and `<body>` (Bootstrap reads `data-bs-theme`). |
| `hello_controller.js` | `hello` | Stimulus boilerplate — safe to delete once replaced by real controllers. |

### Theme controller pattern

`theme_controller.js` is the reference for "persisted UI state" controllers:

```js
connect() {
  const savedTheme = localStorage.getItem('theme') || 'light'
  this.setTheme(savedTheme)
}
```

Notes:
- Reads `localStorage` in `connect()` so theme survives Turbo navigation.
- Mirrors state to BOTH `data-theme` (for app CSS) and `data-bs-theme` (for Bootstrap 5).
- Optional `toggle` target — guarded with `this.hasToggleTarget`.
- The toggle button can be either an `<i>` icon or a wrapper containing `<i>` — the controller handles both.

When you add similar persisted UI controllers (sidebar collapse, font-size, density), follow the same shape: read in `connect`, write in `setX`, no listeners on `document`.
