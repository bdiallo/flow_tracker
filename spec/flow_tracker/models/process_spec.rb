# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowTracker::Process do
  describe "validations" do
    it "requires name" do
      process = described_class.new(name: nil)
      expect(process).not_to be_valid
      expect(process.errors[:name]).to include("can't be blank")
    end
  end

  describe "scopes" do
    let!(:running_process) { described_class.create!(name: "Running", status: "running", started_at: 1.hour.ago) }
    let!(:completed_process) { described_class.create!(name: "Completed", status: "completed", started_at: 2.hours.ago) }
    let!(:failed_process) { described_class.create!(name: "Failed", status: "failed", started_at: 3.hours.ago) }
    let!(:old_process) { described_class.create!(name: "Old", started_at: 2.days.ago) }

    describe ".recent" do
      it "orders by started_at descending" do
        expect(described_class.recent.first).to eq(running_process)
      end
    end

    describe ".failed" do
      it "returns only failed processes" do
        expect(described_class.failed).to contain_exactly(failed_process)
      end
    end

    describe ".today" do
      it "returns processes started today" do
        today_processes = described_class.today
        expect(today_processes).to include(running_process, completed_process, failed_process)
        expect(today_processes).not_to include(old_process)
      end
    end

    describe ".by_name" do
      it "searches by name" do
        expect(described_class.by_name("Run")).to contain_exactly(running_process)
      end
    end
  end

  describe "#complete!" do
    let(:process) { described_class.create!(name: "Test", started_at: 1.second.ago) }

    it "marks process as completed" do
      process.complete!

      expect(process.status).to eq("completed")
      expect(process.completed_at).to be_present
      expect(process.duration_ms).to be_present
    end

    it "marks process as failed when error provided" do
      error = StandardError.new("Test error")
      error.set_backtrace(["line1", "line2"])

      process.complete!(error: error)

      expect(process.status).to eq("failed")
      expect(process.error_message).to eq("Test error")
      expect(process.error_backtrace).to include("line1")
    end
  end

  describe "#root_flows" do
    let(:process) { described_class.create!(name: "Test") }

    it "returns only flows without parent" do
      root = FlowTracker::Flow.create!(process: process, name: "root", started_at: Time.current)
      child = FlowTracker::Flow.create!(process: process, name: "child", parent_flow: root, started_at: Time.current)

      expect(process.root_flows).to contain_exactly(root)
    end
  end

  describe "#running?" do
    it "returns true when status is running" do
      process = described_class.new(status: "running")
      expect(process.running?).to be true
    end

    it "returns false when status is not running" do
      process = described_class.new(status: "completed")
      expect(process.running?).to be false
    end
  end

  describe "#failed?" do
    it "returns true when status is failed" do
      process = described_class.new(status: "failed")
      expect(process.failed?).to be true
    end
  end
end
