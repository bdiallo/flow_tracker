# frozen_string_literal: true

FlowTracker.configure do |config|
  # Enable or disable tracking
  # Set to false in test environment to reduce noise
  config.enabled = !Rails.env.test?

  # Number of days to retain process data (default: 365 = 1 year)
  # Use FlowTracker.cleanup to remove old records
  config.retention_days = 365

  # Default category for processes when not specified
  # Options: :jobs, :services, :api, :other
  config.default_category = :jobs

  # Whether to also log to Rails.logger
  config.rails_logger = true
end
