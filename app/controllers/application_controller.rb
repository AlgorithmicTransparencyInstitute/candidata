class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # HTTP Basic Authentication for production
  http_basic_authenticate_with name: ENV.fetch("HTTP_AUTH_USERNAME", "admin"),
                                password: ENV.fetch("HTTP_AUTH_PASSWORD", ""),
                                if: -> { ENV["HTTP_AUTH_PASSWORD"].present? }
end
