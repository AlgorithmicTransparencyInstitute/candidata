module Verification
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
        redirect_to verification_assignment_path(@assignment), notice: "Account updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def verify
      notes = params[:notes]&.strip
      @account.verify!(current_user, notes: notes)
      redirect_to verification_assignment_path(@assignment), notice: "Account verified."
    end

    def reject
      notes = params[:notes]&.strip
      if notes.blank?
        redirect_to verification_account_path(@account), alert: "Please provide a reason for rejection."
        return
      end

      @account.reject!(current_user, notes: notes)
      redirect_to verification_assignment_path(@assignment), notice: "Account rejected."
    end

    private

    def set_account
      @account = SocialMediaAccount.find(params[:id])
    end

    def verify_assignment
      @assignment = current_user.assignments.data_validation.active.find_by(person_id: @account.person_id)
      unless @assignment
        redirect_to verification_assignments_path, alert: "You don't have an active verification assignment for this person."
      end
    end

    def account_params
      params.require(:social_media_account).permit(:url, :handle, :verification_notes)
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
