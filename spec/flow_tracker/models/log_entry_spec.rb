# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowTracker::LogEntry do
  let(:process) { FlowTracker::Process.create!(name: "Test") }

  describe "validations" do
    it "requires message" do
      entry = described_class.new(process: process, message: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:message]).to include("can't be blank")
    end
  end

  describe "scopes" do
    before do
      @entry1 = described_class.create!(process: process, message: "First", logged_at: 3.minutes.ago)
      @entry2 = described_class.create!(process: process, message: "Second", logged_at: 2.minutes.ago)
      @entry3 = described_class.create!(process: process, message: "Third", logged_at: 1.minute.ago)
    end

    describe ".recent" do
      it "orders by logged_at descending" do
        expect(described_class.recent.first).to eq(@entry3)
      end
    end

    describe ".chronological" do
      it "orders by logged_at ascending" do
        expect(described_class.chronological.first).to eq(@entry1)
      end
    end
  end

  describe "level enum" do
    it "supports debug level" do
      entry = described_class.create!(process: process, message: "test", level: "debug")
      expect(entry.level_debug?).to be true
    end

    it "supports info level" do
      entry = described_class.create!(process: process, message: "test", level: "info")
      expect(entry.level_info?).to be true
    end

    it "supports warn level" do
      entry = described_class.create!(process: process, message: "test", level: "warn")
      expect(entry.level_warn?).to be true
    end

    it "supports error level" do
      entry = described_class.create!(process: process, message: "test", level: "error")
      expect(entry.level_error?).to be true
    end
  end

  describe "#formatted_message" do
    it "formats the message with level and timestamp" do
      entry = described_class.new(
        process: process,
        message: "Test message",
        level: "info",
        logged_at: Time.new(2024, 1, 15, 10, 30, 45)
      )

      expect(entry.formatted_message).to include("[INFO]")
      expect(entry.formatted_message).to include("Test message")
    end
  end

  describe "#error?" do
    it "returns true for error level" do
      entry = described_class.new(level: "error")
      expect(entry.error?).to be true
    end

    it "returns false for other levels" do
      entry = described_class.new(level: "info")
      expect(entry.error?).to be false
    end
  end

  describe "#warning_or_above?" do
    it "returns true for warn level" do
      entry = described_class.new(level: "warn")
      expect(entry.warning_or_above?).to be true
    end

    it "returns true for error level" do
      entry = described_class.new(level: "error")
      expect(entry.warning_or_above?).to be true
    end

    it "returns false for info level" do
      entry = described_class.new(level: "info")
      expect(entry.warning_or_above?).to be false
    end
  end
end
