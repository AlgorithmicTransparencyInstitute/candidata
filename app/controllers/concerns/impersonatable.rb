module Impersonatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user_is_impersonating?
    helper_method :true_current_user
  end

  # Override Devise's current_user to support impersonation
  def current_user
    if session[:impersonating_user_id].present?
      User.find_by(id: session[:impersonating_user_id])
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
