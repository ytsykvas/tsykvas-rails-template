# Database & Migrations

PostgreSQL 16, Rails 8.1, multi-database setup.

## Multi-database layout

Rails 8.1 ships with three solid_* gems, each with its own database:

| Database | Purpose | Schema file |
|---|---|---|
| `<app_name>_<env>` (primary) | Application data — `users`, `properties`, ... | `db/schema.rb` |
| `cache` | `Rails.cache` backing (SolidCache) | `db/cache_schema.rb` |
| `queue` | Active Job backing (SolidQueue) | `db/queue_schema.rb` |
| `cable` | Action Cable backing (SolidCable) | `db/cable_schema.rb` |

`config/database.yml` only defines the primary; `cache`, `queue`, `cable` are configured per-env via the corresponding YAML files (`config/cache.yml`, `config/queue.yml`, `config/cable.yml`). In **development** and **test**, cache/queue/cable run in the primary database for simplicity. In **production** they're separate Postgres databases on the same instance.

Practical impact: `bin/rails db:prepare` handles them all. You generally don't write migrations against the cache/queue/cable schemas — those are managed by their respective gems.

## Migration conventions

- File name: `db/migrate/YYYYMMDDHHMMSS_describe_change.rb`
- Class name in PascalCase matching the file.
- Schema version is in `db/schema.rb` — keep it in version control.
- Always include `null: false` for required columns.
- Always add an index for foreign keys: `t.references :property, foreign_key: true, null: false` (creates the index automatically).
- Use `add_foreign_key` if you create the column without `t.references`.
- Default values: only at the DB layer for safety-critical defaults (NOT NULL with sensible default). Application-level defaults live in the model.
- For long-running migrations on large tables, use `disable_ddl_transaction!` and `add_index ..., algorithm: :concurrently`.

```ruby
class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :property, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :reports, [:property_id, :status]
  end
end
```

## Enums

Use **integer enums** at the DB layer, declared in the model:

```ruby
# db migration
t.integer :role, null: false, default: 1

# model
enum :role, { admin: 0, owner: 1, customer: 2 }
```

Rules:
- Always pin integer values explicitly (don't rely on positional ordering).
- Adding a new value: append to the end with the next integer. Never reorder or reuse values — existing rows reference them.
- The default integer in the migration should map to the most common value (here `1` = `:customer`).

## Current schema (snapshot)

```
users
  id (bigint, PK)
  email (string, NOT NULL, default '', unique index)
  encrypted_password (string, NOT NULL, default '')
  name (string, NOT NULL)
  role (integer, NOT NULL, default 1)         # User#role enum
  reset_password_token (string, unique index)
  reset_password_sent_at (datetime)
  remember_created_at (datetime)
  created_at, updated_at

properties
  id (bigint, PK)
  name (string, NOT NULL)
  owner_id (bigint, FK → users.id, NOT NULL, indexed)
  created_at, updated_at
```

`properties.owner_id` → `users.id` is the property/owner relationship. `User#owned_properties` returns properties where this user is the owner. Substitute your own associations to fit your domain.

## Models

`app/models/` — keep them small:

- Validations + associations + enums + scopes only.
- No business logic — that lives in operations.
- No callbacks for cross-model side effects (use operations or jobs).
- Custom validators (e.g. `User#owner_can_have_only_one_property`) are fine when they enforce a true invariant.

`select2_search_result` is a model-level convention: any model used as a select2 source must implement it (called by `endpoint`'s `format.json` branch). Returns a hash like `{ id:, text: }`.

## Seeds & dev data

`db/seeds.rb` is currently empty. When you add seeds:

- Make them **idempotent** (`find_or_create_by!`).
- Use `Rails.env.development?` guards if a seed shouldn't run in production.
- Document the dev login (admin email + password) in `README.md` so a fresh checkout works.

```ruby
# db/seeds.rb
if Rails.env.development?
  User.find_or_create_by!(email: 'admin@example.com') do |u|
    u.name = 'Admin'
    u.password = 'password'
    u.role = :admin
  end
end
```

## Common commands

```bash
bin/rails db:prepare          # create + migrate (or load schema) — run on bootstrap
bin/rails db:migrate          # apply pending migrations
bin/rails db:rollback         # roll back last migration
bin/rails db:seed             # run db/seeds.rb
bin/rails db:reset            # drop + create + load schema + seed (development only)
bin/rails db:schema:load      # load schema.rb (faster than running all migrations)
```

## Anti-patterns

- ❌ `belongs_to :foo` without `foreign_key: true` constraint at the DB level.
- ❌ String-typed enums — use integer enums with explicit values.
- ❌ Renaming an enum value without a data migration.
- ❌ Reusing an integer for a different enum value (silently corrupts old rows).
- ❌ Long-running `add_column` on large tables without `algorithm: :concurrently` for the matching index.
- ❌ Business logic in `before_save` — the operation layer is the right place.
