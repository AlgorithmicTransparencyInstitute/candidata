# frozen_string_literal: true

# Configuration for rack-mini-profiler
# Shows performance metrics in development and for admins in production
if defined?(Rack::MiniProfiler)
  # Configure for Turbo compatibility
  # The profiler needs to be re-rendered after Turbo navigations
  Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true
  # Enable in development by default
  if Rails.env.development?
    Rack::MiniProfiler.config.tap do |config|
      # Show badge on all pages in upper right
      config.position = "top-right"

      # Store profiling results in memory
      config.storage = Rack::MiniProfiler::MemoryStore

      # Skip profiling for certain paths if needed
      # config.skip_paths = ['/admin/sidekiq']
    end
  end

  # Enable in production only for admin users
  if Rails.env.production?
    Rack::MiniProfiler.config.tap do |config|
      config.position = "top-right"
      config.storage = Rack::MiniProfiler::MemoryStore

      # Only show profiler for admin users
      config.authorization_mode = :allow_authorized

      # This method is called before each request to determine if profiling should be enabled
      # It must return true/false
      config.pre_authorize_cb = lambda { |env|
        begin
          # Check if user is logged in via Warden (Devise)
          if env['warden']
            # Try to get user from default scope
            user = env['warden'].user(:user)
            user ||= env['warden'].user # fallback to default

            # Log for debugging
            Rails.logger.info("Rack::MiniProfiler: Checking authorization for user: #{user.inspect}")

            # Check if user is admin
            if user && user.respond_to?(:admin?)
              is_admin = user.admin? == true
              Rails.logger.info("Rack::MiniProfiler: User is admin: #{is_admin}")
              is_admin
            else
              Rails.logger.info("Rack::MiniProfiler: User doesn't respond to admin? or is nil")
              false
            end
          else
            Rails.logger.info("Rack::MiniProfiler: No warden in env")
            false
          end
        rescue => e
          # Log error but don't break the request
          Rails.logger.error("Rack::MiniProfiler authorization error: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          false
        end
      }
    end
  end
end
