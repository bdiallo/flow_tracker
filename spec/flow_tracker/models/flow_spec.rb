# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowTracker::Flow do
  let(:process) { FlowTracker::Process.create!(name: "Test") }

  describe "validations" do
    it "requires name" do
      flow = described_class.new(process: process, name: nil)
      expect(flow).not_to be_valid
      expect(flow.errors[:name]).to include("can't be blank")
    end

    it "requires process" do
      flow = described_class.new(name: "test")
      flow.valid?
      expect(flow.errors[:process]).to be_present
    end
  end

  describe "associations" do
    it "belongs to process" do
      flow = described_class.create!(process: process, name: "test", started_at: Time.current)
      expect(flow.process).to eq(process)
    end

    it "can have a parent flow" do
      parent = described_class.create!(process: process, name: "parent", started_at: Time.current)
      child = described_class.create!(process: process, name: "child", parent_flow: parent, started_at: Time.current)

      expect(child.parent_flow).to eq(parent)
      expect(parent.child_flows).to contain_exactly(child)
    end
  end

  describe "#complete!" do
    let(:flow) { described_class.create!(process: process, name: "test", started_at: 1.second.ago) }

    it "marks flow as completed" do
      flow.complete!

      expect(flow.status).to eq("completed")
      expect(flow.completed_at).to be_present
      expect(flow.duration_ms).to be_present
    end

    it "marks flow as failed when error provided" do
      flow.complete!(error: StandardError.new("fail"))

      expect(flow.status).to eq("failed")
    end
  end

  describe "#skip!" do
    let(:flow) { described_class.create!(process: process, name: "test", started_at: 1.second.ago) }

    it "marks flow as skipped" do
      flow.skip!

      expect(flow.status).to eq("skipped")
      expect(flow.completed_at).to be_present
    end
  end

  describe "#depth" do
    it "returns 0 for root flows" do
      flow = described_class.new(process: process, name: "root")
      expect(flow.depth).to eq(0)
    end

    it "returns correct depth for nested flows" do
      root = described_class.create!(process: process, name: "root", started_at: Time.current)
      level1 = described_class.create!(process: process, name: "level1", parent_flow: root, started_at: Time.current)
      level2 = described_class.create!(process: process, name: "level2", parent_flow: level1, started_at: Time.current)

      expect(level1.depth).to eq(1)
      expect(level2.depth).to eq(2)
    end
  end

  describe "#root?" do
    it "returns true when no parent" do
      flow = described_class.new(process: process, name: "root")
      expect(flow.root?).to be true
    end

    it "returns false when has parent" do
      parent = described_class.create!(process: process, name: "parent", started_at: Time.current)
      child = described_class.new(process: process, name: "child", parent_flow: parent)
      expect(child.root?).to be false
    end
  end
end
