# Background Jobs (SolidQueue)

The app uses **SolidQueue** (database-backed Active Job adapter) with a dedicated queue database. There are no jobs yet — `app/jobs/` only contains `application_job.rb`. This doc fixes conventions before the first real job lands.

## Configuration

```
config/queue.yml         # Worker / dispatcher config
config/recurring.yml     # Cron-style recurring tasks
db/queue_schema.rb       # Schema for the queue database
```

`config/queue.yml` (default workers):

- 1 dispatcher, polling every 1s, batch size 500.
- Workers process all queues (`*`), 3 threads each, polling every 0.1s.
- Process count via `JOB_CONCURRENCY` env var (default 1).

`config/recurring.yml` already schedules:

```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12
```

In production deploys (Kamal), SolidQueue runs **inside Puma** via `SOLID_QUEUE_IN_PUMA=true` (set in `config/deploy.yml`). When traffic grows, split it onto a dedicated job server.

## Where jobs live

```
app/jobs/
  application_job.rb              # Base class (queue_as :default by default)
  <namespace>/<feature>_job.rb    # Feature-specific jobs, mirroring app/concepts naming
```

For feature-scoped jobs prefer `app/jobs/<namespace>/<job>.rb` (e.g. `app/jobs/crm/property/cleanup_job.rb`). Don't put them inside `app/concepts/` — jobs are infrastructure, not part of the request/operation cycle.

## Naming & class layout

```ruby
# app/jobs/crm/property/cleanup_job.rb
# frozen_string_literal: true

class Crm::Property::CleanupJob < ApplicationJob
  queue_as :default

  def perform(property_id)
    property = Crm::Property.find_by(id: property_id)
    return if property.nil?

    Crm::Property::Operation::Cleanup.call(
      params: { property_id: property.id },
      current_user: nil
    )
  end
end
```

Rules:

- Always `# frozen_string_literal: true`.
- `queue_as :default` unless you have a specific reason (e.g. `:background` for non-time-sensitive bulk work).
- **Pass IDs, not AR objects** — by the time the job runs, the record may be gone.
- **Idempotent perform** — workers retry on failure, and recurring tasks may overlap.
- Delegate real logic to an Operation (`<Feature>::Operation::<Action>`). The job is a thin wrapper that pulls IDs and calls the operation, NOT a place for business logic.
- Set `retry_on` / `discard_on` for known failures (e.g. `discard_on ActiveJob::DeserializationError` for missing records).

## Calling from an operation

```ruby
# Inside Operation#perform!
Crm::Property::CleanupJob.perform_later(model.id)
```

For tests, prefer `perform_later` + assert enqueued (see below); use `perform_now` only if you want sync execution.

## Recurring tasks

Add new entries to `config/recurring.yml` under the `production:` key (or `default:` if you want them to run in dev too):

```yaml
production:
  daily_archive:
    class: Crm::Archive::DailyJob
    queue: background
    schedule: every day at 3am

  cleanup:
    command: "Crm::Stale.delete_all"
    schedule: every hour at minute 12
```

Use `class:` for jobs that take no arguments; use `command:` for one-off Ruby snippets. Provide a unique top-level key for each task.

## Testing

```ruby
# rails_helper.rb already loads ActiveJob test helpers.
RSpec.describe Crm::Property::CleanupJob do
  let(:property) { create(:property) }

  it 'enqueues with the property id' do
    expect {
      described_class.perform_later(property.id)
    }.to have_enqueued_job.with(property.id).on_queue('default')
  end

  it 'calls the cleanup operation' do
    op_double = class_double(Crm::Property::Operation::Cleanup, call: nil)
    stub_const('Crm::Property::Operation::Cleanup', op_double)

    described_class.perform_now(property.id)

    expect(op_double).to have_received(:call).with(
      params: { property_id: property.id }, current_user: nil
    )
  end
end
```

When testing operations that enqueue jobs:

```ruby
expect { result }.to have_enqueued_job(Crm::Property::CleanupJob).with(property.id)
```

## Anti-patterns

- ❌ Passing AR objects: `MyJob.perform_later(user)` → fragile across deserialization. Use `user.id`.
- ❌ Business logic in `perform` — keep it in an Operation.
- ❌ Long-running synchronous calls inside `Operation#perform!` — push them to a job.
- ❌ Skipping `retry_on`/`discard_on` — defaults will retry forever.
- ❌ Using `:default` queue for everything when some work is genuinely lower-priority — split queues so a backlog of slow tasks doesn't starve fast ones.
