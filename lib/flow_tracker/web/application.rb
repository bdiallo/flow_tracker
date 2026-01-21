# frozen_string_literal: true

require "sinatra/base"
require_relative "helpers"

module FlowTracker
  module Web
    class Application < Sinatra::Base
      include Helpers

      set :views, File.expand_path("views", __dir__)
      set :public_folder, File.expand_path("public", __dir__)

      helpers do
        include FlowTracker::Web::Helpers
      end

      # Dashboard - stats and process definitions list
      get "/" do
        @stats = calculate_stats
        @processes = FlowTracker::Process.active.order(:name)
        @recent_flows = FlowTracker::Flow.includes(:process).recent.limit(20)
        erb :index
      end

      # List all process definitions
      get "/processes" do
        @processes = FlowTracker::Process.order(:name)

        if params[:name].present?
          @processes = @processes.by_name(params[:name])
        end

        if params[:category].present?
          @processes = @processes.where(category: params[:category])
        end

        erb :processes
      end

      # Show a process definition with its flows (executions)
      get "/processes/:id" do
        @process = FlowTracker::Process.find(params[:id])
        @flows = @process.flows.recent

        # Apply filters to flows
        if params[:status].present?
          @flows = @flows.where(status: params[:status])
        end

        if params[:date].present?
          date = Date.parse(params[:date]) rescue nil
          @flows = @flows.by_date(date) if date
        end

        @flows = @flows.limit(100)
        @stats = @process.stats
        erb :process_show
      rescue ActiveRecord::RecordNotFound
        halt 404, "Process not found"
      end

      # Show a specific flow (execution) with its logs
      get "/flows/:id" do
        @flow = FlowTracker::Flow.includes(:process, :log_entries).find(params[:id])
        @process = @flow.process
        @log_entries = @flow.logs
        erb :flow_show
      rescue ActiveRecord::RecordNotFound
        halt 404, "Flow not found"
      end

      # Delete a process (and all its flows)
      delete "/processes/:id" do
        process = FlowTracker::Process.find(params[:id])
        process.destroy
        redirect to("/processes")
      rescue ActiveRecord::RecordNotFound
        halt 404, "Process not found"
      end

      # Delete a specific flow
      delete "/flows/:id" do
        flow = FlowTracker::Flow.find(params[:id])
        process_id = flow.process_id
        flow.destroy
        redirect to("/processes/#{process_id}")
      rescue ActiveRecord::RecordNotFound
        halt 404, "Flow not found"
      end

      # Cleanup old flows
      post "/cleanup" do
        days = (params[:days] || FlowTracker.configuration.retention_days).to_i
        count = FlowTracker.cleanup(days: days)
        flash_message = "Deleted #{count} flows older than #{days} days"
        redirect to("/?flash=#{ERB::Util.url_encode(flash_message)}")
      end

      # API endpoint for stats (JSON)
      get "/api/stats" do
        content_type :json
        calculate_stats.to_json
      end

      # API endpoint for process stats (JSON)
      get "/api/processes/:id/stats" do
        process = FlowTracker::Process.find(params[:id])
        content_type :json
        process.stats.to_json
      rescue ActiveRecord::RecordNotFound
        halt 404, { error: "Process not found" }.to_json
      end

      private

      def calculate_stats
        {
          processes_count: FlowTracker::Process.count,
          active_processes: FlowTracker::Process.active.count,
          total_flows: FlowTracker::Flow.count,
          flows_today: FlowTracker::Flow.today.count,
          running: FlowTracker::Flow.status_running.count,
          completed: FlowTracker::Flow.status_completed.count,
          failed: FlowTracker::Flow.status_failed.count,
          failed_today: FlowTracker::Flow.today.status_failed.count,
          by_category: FlowTracker::Process.group(:category).count,
          avg_duration_ms: FlowTracker::Flow.status_completed.average(:duration_ms)&.round(0)
        }
      end
    end
  end
end
