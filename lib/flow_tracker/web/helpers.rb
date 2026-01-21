# frozen_string_literal: true

module FlowTracker
  module Web
    module Helpers
      # Format duration in milliseconds to human readable
      def format_duration(ms)
        return "-" unless ms

        if ms < 1000
          "#{ms}ms"
        elsif ms < 60_000
          "#{(ms / 1000.0).round(1)}s"
        elsif ms < 3_600_000
          minutes = ms / 60_000
          seconds = (ms % 60_000) / 1000
          "#{minutes}m #{seconds}s"
        else
          hours = ms / 3_600_000
          minutes = (ms % 3_600_000) / 60_000
          "#{hours}h #{minutes}m"
        end
      end

      # Format timestamp for display
      def format_time(time)
        return "-" unless time

        time.strftime("%Y-%m-%d %H:%M:%S")
      end

      # Format timestamp as relative time
      def time_ago(time)
        return "-" unless time

        seconds = (Time.current - time).to_i

        case seconds
        when 0..59 then "#{seconds}s ago"
        when 60..3599 then "#{seconds / 60}m ago"
        when 3600..86_399 then "#{seconds / 3600}h ago"
        else "#{seconds / 86_400}d ago"
        end
      end

      # CSS class for status badge
      def status_class(status)
        status_int = status.is_a?(Integer) ? status : nil
        status_str = status.to_s

        # Handle integer enum values
        if status_int
          case status_int
          when 0 then "status-running"
          when 1 then "status-completed"
          when 2 then "status-failed"
          when 3 then "status-skipped"
          else "status-unknown"
          end
        else
          case status_str
          when "running" then "status-running"
          when "completed" then "status-completed"
          when "failed" then "status-failed"
          when "skipped" then "status-skipped"
          else "status-unknown"
          end
        end
      end

      # Get status name from integer or string
      def status_name(status)
        status_int = status.is_a?(Integer) ? status : nil

        if status_int
          %w[running completed failed skipped][status_int] || "unknown"
        else
          status.to_s
        end
      end

      # CSS class for log level
      def level_class(level)
        level_int = level.is_a?(Integer) ? level : nil
        level_str = level.to_s

        if level_int
          case level_int
          when 0 then "level-debug"
          when 1 then "level-info"
          when 2 then "level-warn"
          when 3 then "level-error"
          else "level-info"
          end
        else
          case level_str
          when "debug" then "level-debug"
          when "info" then "level-info"
          when "warn" then "level-warn"
          when "error" then "level-error"
          else "level-info"
          end
        end
      end

      # Get level name from integer or string
      def level_name(level)
        level_int = level.is_a?(Integer) ? level : nil

        if level_int
          %w[debug info warn error][level_int] || "info"
        else
          level.to_s
        end
      end

      # CSS class for category
      def category_class(category)
        category_int = category.is_a?(Integer) ? category : nil
        category_str = category.to_s

        if category_int
          %w[jobs services api other][category_int] || "other"
        else
          category_str
        end
      end

      # Get category name from integer or string
      def category_name(category)
        category_int = category.is_a?(Integer) ? category : nil

        if category_int
          %w[jobs services api other][category_int] || "other"
        else
          category.to_s
        end
      end

      # Format metadata hash for display
      def format_metadata(metadata)
        return "" if metadata.blank?

        metadata.map { |k, v| "#{k}: #{truncate_value(v)}" }.join(", ")
      end

      # Truncate long values
      def truncate_value(value, max_length: 50)
        str = value.to_s
        str.length > max_length ? "#{str[0..max_length - 3]}..." : str
      end

      # Check if string is present (non-blank)
      def present?(value)
        value.respond_to?(:present?) ? value.present? : !value.nil? && !value.to_s.strip.empty?
      end

      # Format percentage
      def format_percentage(value)
        return "-" unless value

        "#{(value * 100).round(1)}%"
      end

      # URL helper for root path
      def root_path
        request.script_name
      end

      # URL helper for process path
      def process_path(process)
        "#{root_path}/processes/#{process.id}"
      end

      # URL helper for processes list
      def processes_path
        "#{root_path}/processes"
      end

      # URL helper for flow path
      def flow_path(flow)
        "#{root_path}/flows/#{flow.id}"
      end
    end
  end
end
