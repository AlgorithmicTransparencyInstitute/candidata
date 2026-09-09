module Impersonatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user_is_impersonating?
    helper_method :true_current_user
  end

  # Override Devise's current_user to support impersonation.
  #
  # This path bypasses Warden, so Devise's active_for_authentication? check
  # never runs on it — an impersonated session would otherwise outlive the
  # user's deactivation. Drop back to the real admin if the impersonated
  # account is no longer active.
  def current_user
    if session[:impersonating_user_id].present?
      impersonated = User.find_by(id: session[:impersonating_user_id])
      return impersonated if impersonated&.active?

      session.delete(:impersonating_user_id)
      session.delete(:admin_user_id)
      super
    else
      super
    end
  end

  # Returns true if the current session is impersonating another user
  def current_user_is_impersonating?
    session[:impersonating_user_id].present? && session[:admin_user_id].present?
  end

  # Returns the actual logged-in admin user (not the impersonated one)
  def true_current_user
    if current_user_is_impersonating?
      User.find_by(id: session[:admin_user_id])
    else
      current_user
    end
  end
end
