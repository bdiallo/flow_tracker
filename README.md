# FlowTracker

A Ruby gem that tracks job and process execution flows with a Sinatra-based web dashboard. Similar to Sidekiq's Web UI, but focused on tracking the internal execution flow of your jobs and services.

## Features

- Track process execution with nested flows and log entries
- Automatic tracking for ActiveJob/Sidekiq jobs via `Trackable` module
- Sinatra-based web dashboard for monitoring
- UUID primary keys and JSONB metadata support
- Configurable retention and cleanup
- Rails generator for easy installation

## Installation

Add to your Gemfile:

```ruby
gem 'flow_tracker', git: 'https://github.com/bdiallo/flow_tracker'
```

Run the installer:

```bash
bundle install
rails g flow_tracker:install
rails db:migrate
```

## Configuration

```ruby
# config/initializers/flow_tracker.rb
FlowTracker.configure do |config|
  config.enabled = !Rails.env.test?
  config.retention_days = 365  # 1 year default
  config.default_category = :jobs
  config.rails_logger = true
end
```

## Usage

### Basic Tracking

```ruby
FlowTracker.track("MyProcess", category: :services, metadata: { user_id: 123 }) do |tracker|
  tracker.log("Starting process", level: :info)

  result = tracker.flow("validate_input") do |flow|
    flow.log("Validating...")
    validate_input!
  end

  tracker.flow("process_data", metadata: { count: items.count }) do |flow|
    flow.log("Processing #{items.count} items")
    items.each { |item| process(item) }
  end
end
```

### With ActiveJob

```ruby
class MyJob < ApplicationJob
  include FlowTracker::Trackable

  def perform(user_id)
    user = flow_tracker.flow("load_user") do
      User.find(user_id)
    end

    flow_tracker.flow("send_email") do |flow|
      flow.log("Sending email to #{user.email}")
      UserMailer.welcome(user).deliver_now
    end

    flow_tracker.flow("update_stats") do
      user.update!(last_emailed_at: Time.current)
    end
  end
end
```

### Manual Tracking

```ruby
tracker = FlowTracker.start("ManualProcess", category: :api)

begin
  tracker.log("Starting...")
  tracker.flow("step_1") { do_something }
  tracker.complete!
rescue => e
  tracker.complete!(error: e)
  raise
end
```

## Web Dashboard

Mount the dashboard in your routes:

```ruby
# config/routes.rb
authenticate :user, ->(user) { user.admin? } do
  mount Sidekiq::Web => '/sidekiq'
  mount FlowTracker::Web::Application, at: '/flow_tracker'
end
```

Then visit `/flow_tracker` to see:
- Dashboard with process statistics
- List of all processes with filters
- Process detail view with flows and logs
- Cleanup functionality

## Database Schema

The gem creates three tables:

- `flow_tracker_processes` - Top-level execution contexts
- `flow_tracker_flows` - Sub-steps within processes (supports nesting)
- `flow_tracker_log_entries` - Individual log messages

All tables use UUID primary keys and JSONB for metadata storage.

## API Reference

### FlowTracker Module

```ruby
# Track a process with a block
FlowTracker.track(name, category: :jobs, metadata: {}) { |tracker| ... }

# Start tracking without a block (manual completion)
tracker = FlowTracker.start(name, category: :jobs, metadata: {})

# Cleanup old processes
FlowTracker.cleanup(days: 7)

# Configuration
FlowTracker.configure { |config| ... }
```

### Tracker Instance

```ruby
tracker.flow("name", metadata: {}) { |flow| ... }  # Create a sub-flow
tracker.log("message", level: :info, data: {})     # Log a message
tracker.debug/info/warn/error("message")           # Convenience log methods
tracker.complete!(error: nil)                       # Mark complete
tracker.update_metadata(key: "value")              # Update process metadata
tracker.process_id                                  # Get process UUID
```

### Log Levels

- `:debug` - Debug information
- `:info` - General information (default)
- `:warn` - Warnings
- `:error` - Errors

### Categories

- `:jobs` - Background jobs (default)
- `:services` - Service objects
- `:api` - API requests
- `:other` - Other processes

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT License - see LICENSE file.
