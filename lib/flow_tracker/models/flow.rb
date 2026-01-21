# frozen_string_literal: true

module FlowTracker
  # Flow represents a single execution of a Process.
  # Each time a job runs, a new Flow is created under the Process definition.
  #
  # @example Creating a flow for a process execution
  #   process = FlowTracker::Process.find_or_create_for("MyWorker#perform")
  #   flow = process.flows.create!(status: :running, started_at: Time.current)
  #
  class Flow < ActiveRecord::Base
    self.table_name = "flow_tracker_flows"

    belongs_to :process,
               class_name: "FlowTracker::Process",
               inverse_of: :flows

    has_many :log_entries,
             class_name: "FlowTracker::LogEntry",
             foreign_key: :flow_id,
             dependent: :destroy,
             inverse_of: :flow

    # Status enum
    enum :status, {
      running: 0,
      completed: 1,
      failed: 2,
      skipped: 3
    }, prefix: true

    validates :process, presence: true

    # Scopes
    scope :recent, -> { order(started_at: :desc) }
    scope :today, -> { where("started_at >= ?", Time.current.beginning_of_day) }
    scope :failed, -> { status_failed }
    scope :completed, -> { status_completed }
    scope :running, -> { status_running }
    scope :by_date, ->(date) { where(started_at: date.beginning_of_day..date.end_of_day) }

    # Start a new flow for a process
    # @param process [Process] The process definition
    # @param metadata [Hash] Execution-specific metadata
    # @param triggered_by [String] What triggered this execution
    # @param correlation_id [String] For tracing across services
    # @return [Flow] The created flow
    def self.start_for(process, metadata: {}, triggered_by: nil, correlation_id: nil)
      create!(
        process: process,
        status: :running,
        started_at: Time.current,
        metadata: metadata,
        triggered_by: triggered_by,
        correlation_id: correlation_id || SecureRandom.uuid
      )
    end

    # Complete the flow successfully
    def complete!
      update!(
        status: :completed,
        finished_at: Time.current,
        duration_ms: calculate_duration_ms
      )
    end

    # Fail the flow with an error
    # @param error [Exception] The error that caused the failure
    def fail!(error = nil)
      attrs = {
        status: :failed,
        finished_at: Time.current,
        duration_ms: calculate_duration_ms
      }

      if error
        attrs[:error_message] = error.message
        attrs[:error_backtrace] = format_backtrace(error)
      end

      update!(attrs)
    end

    # Skip the flow
    def skip!(reason: nil)
      update!(
        status: :skipped,
        finished_at: Time.current,
        duration_ms: calculate_duration_ms,
        error_message: reason
      )
    end

    # Update progress
    # @param current [Integer] Current item being processed
    # @param total [Integer] Total items to process
    def update_progress(current, total)
      update!(
        progress: total.positive? ? (current.to_f / total).round(4) : 0,
        total: total
      )
    end

    # Increment counters
    def increment_ok!
      increment!(:ok_count)
    end

    def increment_ko!
      increment!(:ko_count)
    end

    def increment_skip!
      increment!(:skip_count)
    end

    # Check if flow is still running
    def running?
      status_running?
    end

    # Check if flow failed
    def failed?
      status_failed?
    end

    # Check if flow completed successfully
    def completed?
      status_completed?
    end

    # Get duration in human-readable format
    def duration_human
      return nil unless duration_ms

      if duration_ms < 1000
        "#{duration_ms}ms"
      elsif duration_ms < 60_000
        "#{(duration_ms / 1000.0).round(1)}s"
      else
        minutes = duration_ms / 60_000
        seconds = (duration_ms % 60_000) / 1000
        "#{minutes}m #{seconds}s"
      end
    end

    # Get log entries in chronological order
    def logs
      log_entries.order(logged_at: :asc)
    end

    private

    def calculate_duration_ms
      return nil unless started_at

      ((Time.current - started_at) * 1000).to_i
    end

    def format_backtrace(error)
      return nil unless error.backtrace

      error.backtrace.first(20).join("\n")
    end
  end
end
