# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Start an IRB console with FlowTracker loaded"
task :console do
  require "irb"
  require_relative "lib/flow_tracker"
  IRB.start
end
