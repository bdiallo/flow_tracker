# frozen_string_literal: true

module FlowTracker
  # Tracker provides the main interface for logging within a flow execution.
  # It wraps a Flow instance and provides convenient logging methods.
  #
  # @example
  #   FlowTracker.track("MyJob#perform") do |tracker|
  #     tracker.log("Starting process")
  #     tracker.info("Processing item", context: { item_id: 123 })
  #     tracker.update_progress(5, 10)
  #   end
  #
  class Tracker
    attr_reader :process, :step_prefix

    def initialize(flow_record, step_prefix: nil)
      @flow_record = flow_record
      @process = flow_record.process
      @step_prefix = step_prefix
    end

    # Access the underlying flow record
    def flow_record
      @flow_record
    end

    # Backward compatibility: flow() now creates a logical step (logs only, no DB record)
    # In the old architecture, this created nested Flow records.
    # Now it just logs the step and yields a sub-tracker with a prefix.
    #
    # @param name [String] Name of the step
    # @param metadata [Hash] Step metadata (logged)
    # @yield [Tracker] Yields a tracker scoped to this step
    # @return [Object] The return value of the block
    #
    # @example
    #   tracker.flow("validate_input") do |f|
    #     f.log("Validating...")  # Logs: "[validate_input] Validating..."
    #   end
    #
    def flow(name, metadata: {})
      step_name = step_prefix ? "#{step_prefix}.#{name}" : name

      # Log step start
      log("[#{step_name}] Started", context: metadata)

      if block_given?
        begin
          # Create a sub-tracker with this step as prefix
          sub_tracker = Tracker.new(@flow_record, step_prefix: step_name)
          result = yield(sub_tracker)
          log("[#{step_name}] Completed")
          result
        rescue StandardError => e
          log("[#{step_name}] Failed: #{e.message}", level: :error)
          raise
        end
      else
        # Return a sub-tracker for manual management
        Tracker.new(@flow_record, step_prefix: step_name)
      end
    end

    # Log a message at the specified level
    # @param message [String] The log message
    # @param level [Symbol] Log level (:debug, :info, :warn, :error)
    # @param context [Hash] Additional structured data
    # @return [LogEntry] The created log entry
    def log(message, level: :info, context: {})
      # Prepend step prefix if present
      full_message = step_prefix ? "[#{step_prefix}] #{message}" : message
      entry = LogEntry.log(@flow_record, full_message, level: level, context: context)

      # Also log to Rails.logger if configured
      if FlowTracker.configuration.rails_logger && defined?(Rails)
        rails_log(full_message, level)
      end

      entry
    end

    # Convenience methods for different log levels
    def debug(message, context: {})
      log(message, level: :debug, context: context)
    end

    def info(message, context: {})
      log(message, level: :info, context: context)
    end

    def warn(message, context: {})
      log(message, level: :warn, context: context)
    end

    def error(message, context: {})
      log(message, level: :error, context: context)
    end

    # Update progress
    # @param current [Integer] Current item being processed
    # @param total [Integer] Total items to process
    def update_progress(current, total)
      @flow_record.update_progress(current, total)
    end

    # Increment success counter
    def ok!
      @flow_record.increment_ok!
    end

    # Increment failure counter
    def ko!
      @flow_record.increment_ko!
    end

    # Increment skip counter
    def skip!
      @flow_record.increment_skip!
    end

    # Update the flow metadata
    # @param new_metadata [Hash] Metadata to merge
    def update_metadata(new_metadata)
      @flow_record.update!(metadata: @flow_record.metadata.merge(new_metadata))
    end

    # Get the flow ID for reference
    def flow_id
      @flow_record.id
    end

    # Get the process ID for reference
    def process_id
      process.id
    end

    # Get the correlation ID for tracing
    def correlation_id
      @flow_record.correlation_id
    end

    # Manually complete the flow
    def complete!
      @flow_record.complete!
    end

    # Manually fail the flow
    # @param error [Exception, nil] The error that caused the failure
    def fail!(error = nil)
      @flow_record.fail!(error)
    end

    private

    def rails_log(message, level)
      prefix = "[FlowTracker] [#{process.name}]"

      case level.to_sym
      when :debug then Rails.logger.debug("#{prefix} #{message}")
      when :info then Rails.logger.info("#{prefix} #{message}")
      when :warn then Rails.logger.warn("#{prefix} #{message}")
      when :error then Rails.logger.error("#{prefix} #{message}")
      else Rails.logger.info("#{prefix} #{message}")
      end
    end
  end
end
