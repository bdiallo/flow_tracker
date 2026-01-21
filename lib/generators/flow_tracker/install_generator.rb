# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module FlowTracker
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates a FlowTracker initializer and migration for your application"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_initializer
        template "initializer.rb", "config/initializers/flow_tracker.rb"
      end

      def copy_migration
        migration_template "migration.rb.erb", "db/migrate/create_flow_tracker_tables.rb"
      end

      def show_readme
        say ""
        say "FlowTracker installed successfully!", :green
        say ""
        say "Next steps:"
        say "  1. Run migrations: rails db:migrate"
        say "  2. Mount the dashboard in config/routes.rb:"
        say ""
        say "     authenticate :user, ->(user) { user.admin? } do"
        say "       mount FlowTracker::Web::Application, at: '/flow_tracker'"
        say "     end"
        say ""
        say "  3. Add tracking to your jobs:"
        say ""
        say "     class MyJob < ApplicationJob"
        say "       include FlowTracker::Trackable"
        say ""
        say "       def perform(...)"
        say "         flow_tracker.flow('step_1') { ... }"
        say "       end"
        say "     end"
        say ""
      end
    end
  end
end
