module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: [:show, :edit, :update, :destroy, :resend_invitation, :send_reset_password, :impersonate, :generate_invitation_link, :send_assignment_reminder, :deactivate, :reactivate]

    def index
      @users = User.order(:name)
      @users = @users.where(role: params[:role]) if params[:role].present?
      @users = @users.where(cohort: params[:cohort]) if params[:cohort].present?

      # Default to active only: the list exists to work with current people,
      # and 21 of 41 researchers are already dormant.
      @status = params[:status].presence || 'active'
      case @status
      when 'active'   then @users = @users.active
      when 'inactive' then @users = @users.inactive
      end

      @cohorts = User.where.not(cohort: [nil, '']).distinct.order(:cohort).pluck(:cohort)
      @counts = { active: User.active.count, inactive: User.inactive.count }
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
    rescue ActiveRecord::InvalidForeignKey
      # entered_by / verified_by on social_media_accounts are NO ACTION with no
      # `dependent:` option, so deleting anyone who has done real work raises.
      # Deactivation is the answer, and now it says so instead of 500ing.
      redirect_to admin_user_path(@user),
                  alert: "#{@user.name.presence || @user.email} can't be deleted — they entered or verified records that are attributed to them. Deactivate them instead: they keep their history but lose access."
    end

    # Deactivation, not deletion: their work stays attributed to them, they
    # just stop appearing in pickers and can no longer sign in (Devise checks
    # active_for_authentication? on every request, so this ends any live
    # session too).
    def deactivate
      if @user == current_user
        redirect_to admin_user_path(@user), alert: "You can't deactivate your own account."
        return
      end

      open_count = @user.open_assignments_count
      @user.deactivate!(by: current_user)

      notice = "#{@user.name.presence || @user.email} deactivated. Their past work stays attributed to them."
      if open_count.positive?
        notice += " They still hold #{open_count} open #{'assignment'.pluralize(open_count)} — reassign those to someone active."
      end
      redirect_to admin_user_path(@user), notice: notice
    end

    def reactivate
      @user.reactivate!
      redirect_to admin_user_path(@user), notice: "#{@user.name.presence || @user.email} reactivated and can sign in again."
    end

    # Cohort rollover in one action.
    def bulk_deactivate
      ids = Array(params[:user_ids]).map(&:to_s)
      # Never let an admin lock themselves out mid-rollover.
      users = User.where(id: ids).where.not(id: current_user.id).active

      if users.empty?
        redirect_to admin_users_path, alert: "No active users selected."
        return
      end

      stranded = users.sum(&:open_assignments_count)
      names = users.map { |u| u.name.presence || u.email }
      users.each { |u| u.deactivate!(by: current_user) }

      notice = "Deactivated #{names.size} #{'user'.pluralize(names.size)}: #{names.to_sentence}."
      if stranded.positive?
        notice += " They held #{stranded} open #{'assignment'.pluralize(stranded)} between them — reassign those to someone active."
      end
      if ids.include?(current_user.id.to_s)
        notice += " (Your own account was left active.)"
      end
      redirect_to admin_users_path, notice: notice
    end

    def resend_invitation
      if @user.invitation_token.present? && !@user.invitation_accepted?
        custom_subject = params[:subject].presence

        # Regenerate invitation token to get the raw token for the email
        @user.invite!(current_user, skip_invitation: true)

        if custom_subject
          # Send with custom subject and raw token
          CustomDeviseMailer.invitation_instructions(@user, @user.raw_invitation_token, subject: custom_subject).deliver_now
        else
          # Send with default subject and raw token
          CustomDeviseMailer.invitation_instructions(@user, @user.raw_invitation_token).deliver_now
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

    def impersonate
      unless current_user.admin?
        redirect_to root_path, alert: "Not authorized."
        return
      end

      if @user.admin?
        redirect_to admin_user_path(@user), alert: "Cannot impersonate other admins."
        return
      end

      if @user.deactivated?
        redirect_to admin_user_path(@user), alert: "#{@user.name.presence || @user.email} is deactivated. Reactivate them first if you need to view the app as them."
        return
      end

      session[:impersonating_user_id] = @user.id
      session[:admin_user_id] = current_user.id
      redirect_to root_path, notice: "Now viewing as #{@user.name || @user.email}"
    end

    def stop_impersonating
      session.delete(:impersonating_user_id)
      admin_id = session.delete(:admin_user_id)
      redirect_to admin_users_path, notice: "Stopped impersonating. Back to admin view."
    end

    def generate_invitation_link
      unless current_user.admin?
        render json: { error: "Not authorized" }, status: :forbidden
        return
      end

      # Regenerate the invitation token to get a fresh raw token
      @user.invite!(current_user, skip_invitation: true)

      # Determine the proper host
      host = request.host_with_port
      if Rails.env.production? && host.include?('herokuapp.com')
        host = 'candidata.space'
      end

      # Generate the invitation URL with the raw token
      invitation_url = accept_user_invitation_url(
        invitation_token: @user.raw_invitation_token,
        host: host,
        protocol: request.ssl? || Rails.env.production? ? 'https' : 'http'
      )

      render json: { invitation_url: invitation_url }
    end

    def send_assignment_reminder
      incomplete_count = @user.assignments.where(status: [ 'pending', 'in_progress' ]).count

      if incomplete_count.zero?
        redirect_to admin_user_path(@user), alert: "This user has no incomplete assignments to remind them about."
        return
      end

      UserMailer.assignment_reminder(@user).deliver_now
      redirect_to admin_user_path(@user), notice: "Assignment reminder sent to #{@user.email} (#{incomplete_count} #{'assignment'.pluralize(incomplete_count)})."
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
        csv << ["Email", "Name", "Role", "Invitation Status", "Invited At", "Days Pending"]
        csv << ["", "", "", "IMPORTANT: Invitation links must be generated from each user's admin page", "", ""]
        csv << ["", "", "", "The encrypted tokens in the database cannot be used directly in URLs", "", ""]
        csv << ["", "", "", "", "", ""]

        pending_users.each do |user|
          # Note: We can't generate working invitation URLs from encrypted tokens
          # The admin must use the "Generate Invitation Link" button on each user's page
          invitation_status = "Pending - Generate link from user page"

          days_pending = if user.invitation_created_at
                          ((Time.current - user.invitation_created_at) / 1.day).round(1)
                        else
                          "N/A"
                        end

          csv << [
            user.email,
            user.name || "",
            user.role,
            invitation_status,
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
      params.require(:user).permit(:name, :email, :role, :cohort, :password, :password_confirmation)
    end

    def user_edit_params
      params.require(:user).permit(:name, :email, :role, :cohort)
    end
  end
end
