# frozen_string_literal: true

module FlowTracker
  # Process represents a definition/template of a trackable job or service.
  # One Process record exists per unique business_logic (e.g., "MyWorker#perform").
  # Each execution of that process creates a Flow record.
  #
  # @example Finding or creating a process
  #   process = FlowTracker::Process.find_or_create_for("MyWorker#perform", name: "My Worker")
  #
  class Process < ActiveRecord::Base
    self.table_name = "flow_tracker_processes"

    has_many :flows,
             class_name: "FlowTracker::Flow",
             foreign_key: :process_id,
             dependent: :destroy,
             inverse_of: :process

    # Category enum
    enum :category, {
      jobs: 0,
      services: 1,
      api: 2,
      other: 3
    }, prefix: true

    validates :name, presence: true
    validates :business_logic, presence: true, uniqueness: true

    # Scopes
    scope :active, -> { where(active: true) }
    scope :by_category, ->(cat) { where(category: cat) }
    scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
    scope :with_recent_flows, -> { joins(:flows).where("flow_tracker_flows.started_at > ?", 24.hours.ago).distinct }

    # Find or create a process for a given business_logic identifier
    # @param business_logic [String] Unique identifier (e.g., "MyWorker#perform")
    # @param name [String] Display name (defaults to class name from business_logic)
    # @param category [Symbol] Category (:jobs, :services, :api, :other)
    # @param description [String] Optional description
    # @return [Process] The found or created process
    def self.find_or_create_for(business_logic, name: nil, category: :jobs, description: nil)
      find_or_create_by!(business_logic: business_logic) do |process|
        process.name = name || business_logic.split("#").first.split("::").last
        process.category = category
        process.description = description
      end
    end

    # Get statistics for this process
    def stats
      {
        total_flows: flows.count,
        completed: flows.status_completed.count,
        failed: flows.status_failed.count,
        running: flows.status_running.count,
        avg_duration_ms: flows.status_completed.average(:duration_ms)&.round(0),
        last_execution: flows.order(started_at: :desc).first&.started_at
      }
    end

    # Get recent flows for this process
    def recent_flows(limit: 20)
      flows.order(started_at: :desc).limit(limit)
    end

    # Get failed flows for this process
    def failed_flows(limit: 20)
      flows.status_failed.order(started_at: :desc).limit(limit)
    end

    # Check if this process has any running flows
    def has_running_flows?
      flows.status_running.exists?
    end

    # Get success rate (percentage)
    def success_rate
      total = flows.where.not(status: :running).count
      return nil if total.zero?

      completed = flows.status_completed.count
      ((completed.to_f / total) * 100).round(1)
    end
  end
end
