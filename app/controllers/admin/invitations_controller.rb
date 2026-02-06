module Admin
  class InvitationsController < Admin::BaseController
    def new
      @user = User.new(role: 'researcher')
    end

    def create
      emails = parse_emails(params[:emails])
      role = params[:role].presence || 'researcher'

      if emails.empty?
        flash.now[:alert] = "Please enter at least one valid email address."
        @user = User.new(role: role)
        render :new, status: :unprocessable_entity
        return
      end

      results = { sent: [], failed: [] }

      emails.each do |email|
        existing = User.find_by(email: email)
        if existing
          results[:failed] << { email: email, reason: "already registered" }
          next
        end

        user = User.invite!({ email: email, role: role }, current_user)
        if user.errors.any?
          results[:failed] << { email: email, reason: user.errors.full_messages.join(", ") }
        else
          results[:sent] << email
        end
      end

      if results[:sent].any?
        notice = "Invitations sent to #{results[:sent].count} #{'user'.pluralize(results[:sent].count)}."
        if results[:failed].any?
          notice += " #{results[:failed].count} failed."
        end
        redirect_to admin_users_path, notice: notice
      else
        flash.now[:alert] = "No invitations sent. #{results[:failed].map { |f| "#{f[:email]}: #{f[:reason]}" }.join('; ')}"
        @user = User.new(role: role)
        render :new, status: :unprocessable_entity
      end
    end

    private

    def parse_emails(raw)
      return [] if raw.blank?
      raw.split(/[\s,;]+/).map(&:strip).select { |e| e.match?(/\A[^@\s]+@[^@\s]+\z/) }.uniq
    end
  end
end
