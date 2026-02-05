module Researcher
  class AccountsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_account
    before_action :verify_assignment

    def show
      @person = @account.person
    end

    def update
      if @account.update(account_params)
        redirect_to researcher_assignment_path(@assignment), notice: "Account updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def mark_entered
      url = params[:url]&.strip
      handle = params[:handle]&.strip

      if url.blank? && handle.blank?
        redirect_to researcher_account_path(@account), alert: "Please provide a URL or handle."
        return
      end

      @account.mark_entered!(current_user, url: url, handle: handle)
      redirect_to researcher_assignment_path(@assignment), notice: "Account marked as entered."
    end

    def mark_not_found
      @account.mark_not_found!(current_user)
      redirect_to researcher_assignment_path(@assignment), notice: "Account marked as not found."
    end

    private

    def set_account
      @account = SocialMediaAccount.find(params[:id])
    end

    def verify_assignment
      @assignment = current_user.assignments.research.active.find_by(person_id: @account.person_id)
      unless @assignment
        redirect_to researcher_assignments_path, alert: "You don't have an active assignment for this person."
      end
    end

    def account_params
      params.require(:social_media_account).permit(:url, :handle)
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
