# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowTracker do
  describe ".track" do
    it "creates a process and completes it" do
      result = described_class.track("TestProcess") do |tracker|
        "result"
      end

      expect(result[:success]).to be true
      expect(result[:process_id]).to be_present
      expect(result[:result]).to eq("result")

      process = FlowTracker::Process.find(result[:process_id])
      expect(process.name).to eq("TestProcess")
      expect(process.status).to eq("completed")
      expect(process.duration_ms).to be_a(Integer)
    end

    it "accepts category and metadata options" do
      result = described_class.track(
        "TestProcess",
        category: :services,
        metadata: { user_id: 123 }
      ) { }

      process = FlowTracker::Process.find(result[:process_id])
      expect(process.category).to eq("services")
      expect(process.metadata).to eq({ "user_id" => 123 })
    end

    it "marks process as failed when an error occurs" do
      expect {
        described_class.track("TestProcess") do
          raise StandardError, "Test error"
        end
      }.to raise_error(StandardError, "Test error")

      process = FlowTracker::Process.last
      expect(process.status).to eq("failed")
      expect(process.error_message).to eq("Test error")
      expect(process.error_backtrace).to be_present
    end

    it "does nothing when tracking is disabled" do
      FlowTracker.configuration.enabled = false

      result = described_class.track("TestProcess") do |tracker|
        tracker.log("This should be a no-op")
        "result"
      end

      expect(result[:success]).to be true
      expect(result[:process_id]).to be_nil
      expect(FlowTracker::Process.count).to eq(0)
    end

    it "uses default category from configuration" do
      FlowTracker.configuration.default_category = :api

      result = described_class.track("TestProcess") { }

      process = FlowTracker::Process.find(result[:process_id])
      expect(process.category).to eq("api")
    end
  end

  describe ".start" do
    it "returns a tracker for manual management" do
      tracker = described_class.start("ManualProcess")

      expect(tracker).to be_a(FlowTracker::Tracker)
      expect(tracker.process).to be_persisted
      expect(tracker.process.status).to eq("running")
    end

    it "returns a NullTracker when disabled" do
      FlowTracker.configuration.enabled = false

      tracker = described_class.start("ManualProcess")

      expect(tracker).to be_a(FlowTracker::NullTracker)
    end
  end

  describe ".cleanup" do
    it "deletes processes older than retention days" do
      # Create old process
      old_process = FlowTracker::Process.create!(
        name: "OldProcess",
        started_at: 10.days.ago,
        created_at: 10.days.ago
      )

      # Create recent process
      recent_process = FlowTracker::Process.create!(
        name: "RecentProcess",
        started_at: 1.day.ago,
        created_at: 1.day.ago
      )

      count = described_class.cleanup(days: 7)

      expect(count).to eq(1)
      expect(FlowTracker::Process.exists?(old_process.id)).to be false
      expect(FlowTracker::Process.exists?(recent_process.id)).to be true
    end

    it "uses retention_days from configuration by default" do
      FlowTracker.configuration.retention_days = 3

      old_process = FlowTracker::Process.create!(
        name: "OldProcess",
        started_at: 5.days.ago,
        created_at: 5.days.ago
      )

      described_class.cleanup

      expect(FlowTracker::Process.exists?(old_process.id)).to be false
    end

    it "defaults to 365 days retention" do
      expect(FlowTracker.configuration.retention_days).to eq(365)
    end
  end

  describe ".configure" do
    it "allows configuration via block" do
      described_class.configure do |config|
        config.enabled = false
        config.retention_days = 14
        config.default_category = :api
      end

      expect(described_class.configuration.enabled).to be false
      expect(described_class.configuration.retention_days).to eq(14)
      expect(described_class.configuration.default_category).to eq(:api)
    end
  end
end
