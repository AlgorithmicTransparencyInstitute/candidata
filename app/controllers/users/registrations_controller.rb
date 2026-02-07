class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters

  # DELETE /users/avatar
  def destroy_avatar
    current_user.avatar.purge if current_user.avatar.attached?
    redirect_to edit_user_registration_path, notice: 'Profile picture removed successfully.'
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :avatar])
  end

  def update_resource(resource, params)
    # Allow users to update their account without providing a password
    # if they signed up via OAuth
    if resource.provider.present?
      params.delete(:current_password)
      resource.update_without_password(params.except(:password, :password_confirmation))
    else
      super
    end
  end
end
