# frozen_string_literal: true

require "spec_helper"

# Mock ActiveJob for testing
module ActiveJob
  class Base
    def self.around_perform(*args)
      @around_perform_callbacks ||= []
      @around_perform_callbacks << args
    end

    def self.respond_to?(method, include_all = false)
      method == :around_perform || super
    end
  end
end

RSpec.describe FlowTracker::Trackable do
  # Create a test job class
  let(:test_job_class) do
    Class.new(ActiveJob::Base) do
      include FlowTracker::Trackable

      attr_accessor :job_id, :queue_name, :arguments, :scheduled_at

      def initialize
        @job_id = "test-job-123"
        @queue_name = "default"
        @arguments = [1, "test", { key: "value" }]
        @scheduled_at = nil
      end

      def perform
        flow_tracker.log("Starting job")
        flow_tracker.flow("step_1") { "step 1 result" }
        "job result"
      end
    end
  end

  describe "#flow_tracker" do
    it "returns NullTracker when not tracking" do
      job = test_job_class.new
      expect(job.flow_tracker).to be_a(FlowTracker::NullTracker)
    end
  end

  describe "#build_job_metadata" do
    let(:job) do
      j = test_job_class.new
      j.job_id = "job-456"
      j.queue_name = "critical"
      j.arguments = [123, "long string" * 20, { nested: "hash" }]
      j
    end

    it "extracts job metadata" do
      metadata = job.send(:build_job_metadata)

      expect(metadata[:job_id]).to eq("job-456")
      expect(metadata[:queue_name]).to eq("critical")
      expect(metadata[:arguments]).to be_an(Array)
      expect(metadata[:arguments].length).to eq(3)
    end

    it "truncates long string arguments" do
      job.arguments = ["a" * 200]
      metadata = job.send(:build_job_metadata)

      expect(metadata[:arguments].first.length).to be <= 103
    end

    it "includes scheduled_at when present" do
      scheduled_time = Time.current
      job.scheduled_at = scheduled_time
      metadata = job.send(:build_job_metadata)

      expect(metadata[:scheduled_at]).to eq(scheduled_time.iso8601)
    end
  end

  describe "#truncate_argument" do
    let(:job) { test_job_class.new }

    it "handles strings" do
      expect(job.send(:truncate_argument, "short")).to eq("short")
      expect(job.send(:truncate_argument, "a" * 200).length).to be <= 103
    end

    it "handles integers" do
      expect(job.send(:truncate_argument, 123)).to eq(123)
    end

    it "handles hashes" do
      result = job.send(:truncate_argument, { a: 1, b: 2 })
      expect(result).to be_a(Hash)
    end

    it "handles arrays" do
      result = job.send(:truncate_argument, [1, 2, 3, 4, 5])
      expect(result.length).to eq(3) # truncated to first 3
    end

    it "handles nil and booleans" do
      expect(job.send(:truncate_argument, nil)).to be_nil
      expect(job.send(:truncate_argument, true)).to be true
      expect(job.send(:truncate_argument, false)).to be false
    end
  end
end
