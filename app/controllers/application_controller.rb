class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # HTTP Basic Authentication for production
  http_basic_authenticate_with name: ENV.fetch("HTTP_AUTH_USERNAME", "admin"),
                                password: ENV.fetch("HTTP_AUTH_PASSWORD", ""),
                                if: -> { ENV["HTTP_AUTH_PASSWORD"].present? }

  # Include Mixpanel tracking helper
  include MixpanelHelper

  # Track user sign-ins
  after_action :track_sign_in, if: -> { user_signed_in? && session[:just_signed_in] }

  private

  def track_sign_in
    track_event('User Sign In', {
      method: session[:sign_in_method] || 'password'
    })
    update_mixpanel_user(current_user)
    session.delete(:just_signed_in)
    session.delete(:sign_in_method)
  end
end
