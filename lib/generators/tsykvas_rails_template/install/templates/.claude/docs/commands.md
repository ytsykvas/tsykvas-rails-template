# Commands

## Development

```bash
bin/setup                           # bundle install + db:prepare + start dev
bin/dev                             # foreman: rails server + dartsass:watch (Procfile.dev)
bin/rails db:prepare                # create + migrate (or load schema)
bin/rails zeitwerk:check            # autoloading sanity check
```

## Tests

```bash
bundle exec rspec                                       # full suite
bundle exec rspec spec/path/to/file_spec.rb             # single file
bundle exec rspec spec/path/to/file_spec.rb:42          # single example by line
bundle exec rspec --tag focus                           # by tag
```

## Linting & security

```bash
bin/rubocop                         # style check (rubocop-rails-omakase)
bin/rubocop -A                      # autocorrect all safe offenses
bin/brakeman --no-pager             # static security analysis
bin/importmap audit                 # JS dependency audit
```

CI (`.github/workflows/ci.yml`) runs **brakeman + importmap audit + rubocop + rspec** against PostgreSQL 16.

## Deploy

This app uses **Kamal** (`config/deploy.yml`). `bin/kamal deploy` for production deploys; managed by the project owner.
