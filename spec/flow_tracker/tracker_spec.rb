# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowTracker::Tracker do
  let(:process) do
    FlowTracker::Process.create!(
      name: "TestProcess",
      started_at: Time.current
    )
  end

  let(:tracker) { described_class.new(process) }

  describe "#flow" do
    it "creates a flow record" do
      tracker.flow("step_1") { }

      expect(process.flows.count).to eq(1)
      flow = process.flows.first
      expect(flow.name).to eq("step_1")
      expect(flow.status).to eq("completed")
    end

    it "marks flow as failed when error occurs" do
      expect {
        tracker.flow("step_1") { raise "Test error" }
      }.to raise_error("Test error")

      flow = process.flows.first
      expect(flow.status).to eq("failed")
    end

    it "supports nested flows" do
      tracker.flow("outer") do |outer_tracker|
        outer_tracker.flow("inner") { }
      end

      outer = process.flows.find_by(name: "outer")
      inner = process.flows.find_by(name: "inner")

      expect(inner.parent_flow_id).to eq(outer.id)
    end

    it "accepts metadata option" do
      tracker.flow("step_1", metadata: { count: 5 }) { }

      flow = process.flows.first
      expect(flow.metadata).to eq({ "count" => 5 })
    end

    it "returns the block result" do
      result = tracker.flow("step_1") { "hello" }

      expect(result).to eq("hello")
    end

    it "returns a tracker when no block given" do
      flow_tracker = tracker.flow("step_1")

      expect(flow_tracker).to be_a(FlowTracker::Tracker)
      expect(flow_tracker.current_flow).to be_present
      expect(flow_tracker.current_flow.name).to eq("step_1")
    end
  end

  describe "#log" do
    it "creates a log entry" do
      tracker.log("Test message")

      expect(process.log_entries.count).to eq(1)
      entry = process.log_entries.first
      expect(entry.message).to eq("Test message")
      expect(entry.level).to eq("info")
    end

    it "accepts level option" do
      tracker.log("Error message", level: :error)

      entry = process.log_entries.first
      expect(entry.level).to eq("error")
    end

    it "accepts data option" do
      tracker.log("Message", data: { key: "value" })

      entry = process.log_entries.first
      expect(entry.data).to eq({ "key" => "value" })
    end

    it "associates log with current flow" do
      tracker.flow("step_1") do |flow_tracker|
        flow_tracker.log("Inside flow")
      end

      entry = process.log_entries.first
      expect(entry.flow_id).to eq(process.flows.first.id)
    end
  end

  describe "convenience log methods" do
    it "#debug creates debug level entry" do
      tracker.debug("Debug message")
      expect(process.log_entries.first.level).to eq("debug")
    end

    it "#info creates info level entry" do
      tracker.info("Info message")
      expect(process.log_entries.first.level).to eq("info")
    end

    it "#warn creates warn level entry" do
      tracker.warn("Warn message")
      expect(process.log_entries.first.level).to eq("warn")
    end

    it "#error creates error level entry" do
      tracker.error("Error message")
      expect(process.log_entries.first.level).to eq("error")
    end
  end

  describe "#complete!" do
    it "completes the process when no current flow" do
      tracker.complete!

      expect(process.reload.status).to eq("completed")
    end

    it "completes the current flow when present" do
      flow = FlowTracker::Flow.create!(
        process: process,
        name: "step_1",
        started_at: Time.current
      )

      flow_tracker = described_class.new(process, current_flow: flow)
      flow_tracker.complete!

      expect(flow.reload.status).to eq("completed")
    end

    it "marks as failed when error provided" do
      error = StandardError.new("Test error")
      tracker.complete!(error: error)

      expect(process.reload.status).to eq("failed")
      expect(process.error_message).to eq("Test error")
    end
  end

  describe "#update_metadata" do
    it "merges new metadata into process" do
      process.update!(metadata: { existing: "value" })

      tracker.update_metadata(new: "data")

      expect(process.reload.metadata).to eq({
        "existing" => "value",
        "new" => "data"
      })
    end
  end

  describe "#process_id" do
    it "returns the process id" do
      expect(tracker.process_id).to eq(process.id)
    end
  end
end
