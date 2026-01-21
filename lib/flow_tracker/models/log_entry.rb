# frozen_string_literal: true

module FlowTracker
  # LogEntry represents a single log message within a Flow execution.
  # Logs are attached to flows (executions), not processes (definitions).
  #
  # @example Creating a log entry
  #   flow.log_entries.create!(level: :info, content: "Processing started", logged_at: Time.current)
  #
  class LogEntry < ActiveRecord::Base
    self.table_name = "flow_tracker_log_entries"

    belongs_to :flow,
               class_name: "FlowTracker::Flow",
               inverse_of: :log_entries

    # Level enum
    enum :level, {
      debug: 0,
      info: 1,
      warn: 2,
      error: 3
    }, prefix: true

    validates :content, presence: true
    validates :flow, presence: true
    validates :logged_at, presence: true

    # Scopes
    scope :recent, -> { order(logged_at: :desc) }
    scope :chronological, -> { order(logged_at: :asc) }
    scope :errors, -> { level_error }
    scope :warnings, -> { level_warn.or(level_error) }

    # Create a log entry for a flow
    # @param flow [Flow] The flow execution
    # @param message [String] The log message
    # @param level [Symbol] Log level (:debug, :info, :warn, :error)
    # @param context [Hash] Additional structured data
    # @return [LogEntry] The created log entry
    def self.log(flow, message, level: :info, context: {})
      create!(
        flow: flow,
        level: level,
        content: message,
        context: context,
        logged_at: Time.current
      )
    end

    # Format the log entry for display
    def formatted_message
      prefix = "[#{level.upcase}]"
      timestamp = logged_at&.strftime("%H:%M:%S.%L") || ""
      "#{timestamp} #{prefix} #{content}"
    end

    # Check if this is an error-level log
    def error?
      level_error?
    end

    # Check if this is a warning or error
    def warning_or_above?
      level_warn? || level_error?
    end

    # Get the process this log belongs to (through flow)
    def process
      flow&.process
    end
  end
end
