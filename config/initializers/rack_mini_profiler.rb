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

  # Disable in production (MemoryStore doesn't work reliably on Heroku)
  # To enable in production, you need Redis or Memcache storage
  if Rails.env.production?
    Rack::MiniProfiler.config.tap do |config|
      config.enabled = false
    end
  end
end
