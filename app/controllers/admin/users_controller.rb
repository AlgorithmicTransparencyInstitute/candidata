module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: [:show, :edit, :update, :destroy, :resend_invitation, :send_reset_password]

    def index
      @users = User.order(:name)
      @users = @users.where(role: params[:role]) if params[:role].present?
      @users = @users.page(params[:page]).per(50)
    end

    def show
      @assignments = @user.assignments.includes(:person).order(created_at: :desc).limit(20)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      if @user.save
        redirect_to admin_users_path, notice: "User created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @user.update(user_edit_params)
        redirect_to admin_user_path(@user), notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: "User deleted."
    end

    def resend_invitation
      if @user.invitation_token.present? && !@user.invitation_accepted?
        @user.invite!(current_user)
        redirect_to admin_user_path(@user), notice: "Invitation resent to #{@user.email}."
      else
        redirect_to admin_user_path(@user), alert: "This user has already accepted their invitation."
      end
    end

    def send_reset_password
      @user.send_reset_password_instructions
      redirect_to admin_user_path(@user), notice: "Password reset email sent to #{@user.email}."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email, :role, :password, :password_confirmation)
    end

    def user_edit_params
      params.require(:user).permit(:name, :email, :role)
    end
  end
end
