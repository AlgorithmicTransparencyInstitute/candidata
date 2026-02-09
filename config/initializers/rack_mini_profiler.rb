# frozen_string_literal: true

# Configuration for rack-mini-profiler
# Shows performance metrics in development and for admins in production
if defined?(Rack::MiniProfiler)
  # Enable in development by default
  if Rails.env.development?
    Rack::MiniProfiler.config.tap do |config|
      # Show badge on all pages
      config.position = "bottom-right"

      # Store profiling results in memory
      config.storage = Rack::MiniProfiler::MemoryStore

      # Skip profiling for certain paths if needed
      # config.skip_paths = ['/admin/sidekiq']
    end
  end

  # Enable in production only for admin users
  if Rails.env.production?
    Rack::MiniProfiler.config.tap do |config|
      config.position = "bottom-right"
      config.storage = Rack::MiniProfiler::MemoryStore

      # Only show profiler for admin users
      config.authorization_mode = :allow_authorized

      # This method is called before each request to determine if profiling should be enabled
      # It must return true/false
      config.pre_authorize_cb = lambda { |env|
        # Get the current user from the request
        request = Rack::Request.new(env)

        # Check if user is logged in via Warden (Devise)
        if defined?(Warden) && env['warden']
          user = env['warden'].user
          user&.admin? == true
        else
          false
        end
      }
    end
  end
end
