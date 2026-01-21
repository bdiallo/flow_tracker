# frozen_string_literal: true

require "active_record"
require "active_support"
require "active_support/core_ext"

require_relative "flow_tracker/version"
require_relative "flow_tracker/configuration"
require_relative "flow_tracker/models/process"
require_relative "flow_tracker/models/flow"
require_relative "flow_tracker/models/log_entry"
require_relative "flow_tracker/tracker"
require_relative "flow_tracker/trackable"

module FlowTracker
  class Error < StandardError; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Main tracking API
    # Finds or creates a Process definition, then creates a Flow for this execution.
    #
    # @param business_logic [String] Unique identifier (e.g., "MyWorker#perform")
    # @param name [String] Display name (defaults to class name from business_logic)
    # @param category [Symbol] Category (:jobs, :services, :api, :other)
    # @param metadata [Hash] Execution-specific metadata
    # @param triggered_by [String] What triggered this execution
    # @param correlation_id [String] For tracing across services
    # @yield [Tracker] Yields a tracker instance for logging
    # @return [Hash] Result with success status, flow_id, and duration_ms
    #
    # @example
    #   FlowTracker.track("MyJob#perform", category: :jobs, metadata: { user_id: 123 }) do |tracker|
    #     tracker.log("Starting process")
    #     tracker.info("Processing user", context: { user_id: 123 })
    #     tracker.update_progress(5, 10)
    #   end
    #
    def track(business_logic, name: nil, category: nil, metadata: {}, triggered_by: nil, correlation_id: nil)
      return yield_without_tracking { yield(NullTracker.new) } unless configuration.enabled?

      category ||= configuration.default_category
      flow = nil

      begin
        # Find or create the process definition
        process = Process.find_or_create_for(
          business_logic,
          name: name,
          category: category
        )

        # Create a new flow (execution) for this process
        flow = Flow.start_for(
          process,
          metadata: metadata,
          triggered_by: triggered_by,
          correlation_id: correlation_id
        )

        tracker = Tracker.new(flow)
        result = yield(tracker)

        flow.complete!
        {
          success: true,
          flow_id: flow.id,
          process_id: process.id,
          duration_ms: flow.duration_ms,
          result: result
        }
      rescue StandardError => e
        flow&.fail!(e)
        Rails.logger.error("[FlowTracker] Error tracking #{business_logic}: #{e.message}") if defined?(Rails)
        raise
      end
    end

    # Track without a block - returns a tracker that must be manually completed
    # @param business_logic [String] Unique identifier
    # @param name [String] Display name
    # @param category [Symbol] Category
    # @param metadata [Hash] Additional metadata
    # @param triggered_by [String] What triggered this execution
    # @param correlation_id [String] For tracing
    # @return [Tracker] Tracker instance
    def start(business_logic, name: nil, category: nil, metadata: {}, triggered_by: nil, correlation_id: nil)
      return NullTracker.new unless configuration.enabled?

      category ||= configuration.default_category

      process = Process.find_or_create_for(
        business_logic,
        name: name,
        category: category
      )

      flow = Flow.start_for(
        process,
        metadata: metadata,
        triggered_by: triggered_by,
        correlation_id: correlation_id
      )

      Tracker.new(flow)
    end

    # Clean up old flows based on retention policy
    # @param days [Integer] Delete flows older than this many days
    # @return [Integer] Number of deleted flows
    def cleanup(days: nil)
      days ||= configuration.retention_days
      cutoff = days.days.ago
      Flow.where("created_at < ?", cutoff).destroy_all.count
    end

    # Get all process definitions
    # @return [ActiveRecord::Relation] All processes
    def processes
      Process.all
    end

    # Get recent flows across all processes
    # @param limit [Integer] Maximum number of flows to return
    # @return [ActiveRecord::Relation] Recent flows
    def recent_flows(limit: 50)
      Flow.includes(:process).recent.limit(limit)
    end

    # Get stats across all processes
    # @return [Hash] Statistics
    def stats
      {
        processes_count: Process.count,
        active_processes: Process.active.count,
        total_flows: Flow.count,
        flows_today: Flow.today.count,
        running: Flow.status_running.count,
        completed: Flow.status_completed.count,
        failed: Flow.status_failed.count,
        failed_today: Flow.today.status_failed.count,
        avg_duration_ms: Flow.status_completed.average(:duration_ms)&.round(0)
      }
    end

    private

    def yield_without_tracking
      yield
      { success: true, flow_id: nil, process_id: nil, duration_ms: nil, result: nil }
    end
  end

  # Null object pattern for when tracking is disabled
  class NullTracker
    def log(_message, **_options)
      nil
    end

    def debug(_message, **_options)
      nil
    end

    def info(_message, **_options)
      nil
    end

    def warn(_message, **_options)
      nil
    end

    def error(_message, **_options)
      nil
    end

    def update_progress(_current, _total)
      nil
    end

    def ok!
      nil
    end

    def ko!
      nil
    end

    def skip!
      nil
    end

    def update_metadata(_new_metadata)
      nil
    end

    def complete!
      nil
    end

    def fail!(_error = nil)
      nil
    end

    def flow(_name = nil, **_options)
      yield(self) if block_given?
      nil
    end

    def process
      nil
    end

    def flow_id
      nil
    end

    def process_id
      nil
    end

    def correlation_id
      nil
    end
  end
end

# Load Rails engine if Rails is available
require_relative "flow_tracker/engine" if defined?(Rails::Engine)
