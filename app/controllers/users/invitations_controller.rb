class Users::InvitationsController < Devise::InvitationsController
  protected

  def update_resource_params
    params.require(:user).permit(:name, :password, :password_confirmation, :invitation_token)
  end
end
