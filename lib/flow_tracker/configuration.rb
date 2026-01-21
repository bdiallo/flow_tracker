# frozen_string_literal: true

module FlowTracker
  class Configuration
    # Whether tracking is enabled
    attr_accessor :enabled

    # Number of days to retain process data (for cleanup)
    attr_accessor :retention_days

    # Default category for processes when not specified
    attr_accessor :default_category

    # Whether to log to Rails.logger as well
    attr_accessor :rails_logger

    def initialize
      @enabled = true
      @retention_days = 365
      @default_category = :jobs
      @rails_logger = true
    end

    def enabled?
      @enabled
    end
  end
end
