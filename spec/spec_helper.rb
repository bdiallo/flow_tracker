# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "database_cleaner/active_record"
require "factory_bot"

# Establish database connection for testing
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Create tables for testing
ActiveRecord::Schema.define do
  enable_extension "pgcrypto" if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

  create_table :flow_tracker_processes, id: :string, force: true do |t|
    t.string :name, null: false
    t.string :category
    t.string :status, default: "running", null: false
    t.text :metadata
    t.datetime :started_at
    t.datetime :completed_at
    t.integer :duration_ms
    t.text :error_message
    t.text :error_backtrace
    t.timestamps
  end

  create_table :flow_tracker_flows, id: :string, force: true do |t|
    t.string :process_id, null: false
    t.string :parent_flow_id
    t.string :name, null: false
    t.string :status, default: "running", null: false
    t.text :metadata
    t.datetime :started_at
    t.datetime :completed_at
    t.integer :duration_ms
    t.timestamps
  end

  create_table :flow_tracker_log_entries, id: :string, force: true do |t|
    t.string :process_id, null: false
    t.string :flow_id
    t.string :level, default: "info", null: false
    t.text :message, null: false
    t.text :data
    t.datetime :logged_at
    t.timestamps
  end
end

require "flow_tracker"

# Handle JSONB serialization for SQLite
FlowTracker::Process.class_eval do
  serialize :metadata, coder: JSON
end

FlowTracker::Flow.class_eval do
  serialize :metadata, coder: JSON
end

FlowTracker::LogEntry.class_eval do
  serialize :data, coder: JSON
end

# Generate UUIDs for SQLite
[FlowTracker::Process, FlowTracker::Flow, FlowTracker::LogEntry].each do |model|
  model.class_eval do
    before_create :set_uuid
    def set_uuid
      self.id ||= SecureRandom.uuid
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.before(:each) do
    FlowTracker.reset_configuration!
  end
end
