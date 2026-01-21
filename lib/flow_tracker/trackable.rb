# frozen_string_literal: true

module FlowTracker
  # Trackable is a mixin for ActiveJob/Sidekiq jobs that automatically
  # tracks job execution. It creates a Process definition (once per job class)
  # and a Flow for each execution.
  #
  # @example
  #   class MyJob < ApplicationJob
  #     include FlowTracker::Trackable
  #
  #     def perform(user_id)
  #       flow_tracker.info("Starting job")
  #       user = User.find(user_id)
  #       flow_tracker.info("Processing user", context: { user_id: user.id })
  #     end
  #   end
  #
  module Trackable
    extend ActiveSupport::Concern

    included do
      # Use around_perform callback for ActiveJob
      if respond_to?(:around_perform)
        around_perform :track_execution
      end
    end

    # Access the flow tracker within the job
    # @return [Tracker, NullTracker] The tracker instance
    def flow_tracker
      @flow_tracker || FlowTracker::NullTracker.new
    end

    private

    # Build the business_logic identifier for this job
    # Override this method to customize the identifier
    def flow_tracker_business_logic
      "#{self.class.name}#perform"
    end

    # Build the display name for this job's process
    # Override this method to customize the name
    def flow_tracker_name
      self.class.name.demodulize.underscore.humanize
    end

    # In Rails 7.1+, around_perform doesn't pass the job as an argument
    # Use `self` to access the job instance
    def track_execution
      FlowTracker.track(
        flow_tracker_business_logic,
        name: flow_tracker_name,
        category: :jobs,
        metadata: build_job_metadata,
        triggered_by: "ActiveJob"
      ) do |tracker|
        @flow_tracker = tracker
        yield
      end
    end

    # Build metadata from the job
    # Override this method to customize metadata
    def build_job_metadata
      metadata = {
        job_id: job_id,
        queue_name: queue_name
      }

      # Include first few arguments (truncated for safety)
      args = arguments.first(3).map do |arg|
        truncate_argument(arg)
      end
      metadata[:arguments] = args if args.any?

      # Include scheduled time if present
      if scheduled_at
        metadata[:scheduled_at] = scheduled_at.iso8601
      end

      metadata
    end

    # Truncate/sanitize argument for safe storage
    def truncate_argument(arg)
      case arg
      when String
        arg.length > 100 ? "#{arg[0..97]}..." : arg
      when Integer, Float, TrueClass, FalseClass, NilClass
        arg
      when Hash
        arg.transform_values { |v| truncate_argument(v) }.slice(*arg.keys.first(5))
      when Array
        arg.first(3).map { |v| truncate_argument(v) }
      when ActiveRecord::Base
        { class: arg.class.name, id: arg.id }
      else
        arg.to_s[0..100]
      end
    rescue StandardError
      "[unserializable]"
    end
  end
end
