# frozen_string_literal: true

if defined?(Rack::MiniProfiler)
  # Enable in production for admin users only
  Rack::MiniProfiler.config.authorization_mode = :allow_authorized

  # Determine who is authorized to see the profiler
  Rack::MiniProfiler.config.pre_authorize_cb = lambda { |env|
    request = Rack::Request.new(env)

    # Check if user is signed in and is an admin
    if defined?(Warden) && env['warden']
      user = env['warden'].user
      user&.admin?
    else
      false
    end
  }

  # Position on page (default is top-left, can be top-right, bottom-left, bottom-right)
  Rack::MiniProfiler.config.position = 'bottom-right'

  # Skip paths that don't need profiling
  Rack::MiniProfiler.config.skip_paths = [
    '/assets/',
    '/packs/',
    '/health_check'
  ]
end
