module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: [:show, :edit, :update, :destroy, :resend_invitation, :send_reset_password]

    def index
      @users = User.order(:name)
      @users = @users.where(role: params[:role]) if params[:role].present?
      @users = @users.page(params[:page]).per(50)
    end

    def show
      @assignments = @user.assignments.includes(person: [
        :party_affiliation,
        { person_parties: :party },
        :social_media_accounts,
        { officeholders: :office },
        { candidates: { contest: [:office, :ballot] } }
      ]).order(created_at: :desc).limit(20)
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
        custom_subject = params[:subject].presence

        # Send invitation email (token already exists, just resend the email)
        if custom_subject
          # Send with custom subject
          CustomDeviseMailer.invitation_instructions(@user, @user.invitation_token, subject: custom_subject).deliver_now
        else
          # Send with default subject
          @user.deliver_invitation
        end

        redirect_to admin_user_path(@user), notice: "Invitation resent to #{@user.email}."
      else
        redirect_to admin_user_path(@user), alert: "This user has already accepted their invitation."
      end
    end

    def send_reset_password
      @user.send_reset_password_instructions
      redirect_to admin_user_path(@user), notice: "Password reset email sent to #{@user.email}."
    end

    def export_invitations
      require 'csv'

      # Find all users with pending invitations
      pending_users = User.where.not(invitation_token: nil)
                         .where(invitation_accepted_at: nil)
                         .order(:created_at)

      # Determine the proper host to use
      host = request.host_with_port
      # In production, use candidata.space instead of herokuapp.com
      if Rails.env.production? && host.include?('herokuapp.com')
        host = 'candidata.space'
      end

      # Generate CSV
      csv_data = CSV.generate(headers: true) do |csv|
        csv << ["Email", "Name", "Role", "Invitation URL", "Invited At", "Days Pending"]

        pending_users.each do |user|
          # Generate the invitation acceptance URL
          invitation_url = accept_user_invitation_url(
            invitation_token: user.invitation_token,
            host: host,
            protocol: request.ssl? ? 'https' : 'http'
          )

          days_pending = if user.invitation_created_at
                          ((Time.current - user.invitation_created_at) / 1.day).round(1)
                        else
                          "N/A"
                        end

          csv << [
            user.email,
            user.name || "",
            user.role,
            invitation_url,
            user.invitation_created_at&.strftime("%Y-%m-%d %H:%M"),
            days_pending
          ]
        end
      end

      # Send CSV file
      send_data csv_data,
                filename: "pending_invitations_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                type: 'text/csv',
                disposition: 'attachment'
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
