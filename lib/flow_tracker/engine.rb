# frozen_string_literal: true

module FlowTracker
  class Engine < ::Rails::Engine
    isolate_namespace FlowTracker

    # Load the web application when needed
    initializer "flow_tracker.load_web" do
      require_relative "web/application"
    end

    # Make generators available
    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
