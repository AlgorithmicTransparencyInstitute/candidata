module Verification
  class AssignmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_assignment, only: [:show, :start, :complete]

    def index
      @assignments = current_user.assignments.data_validation.active.includes(person: :social_media_accounts).order(created_at: :asc)
    end

    def show
      @person = @assignment.person
      @accounts = @person.social_media_accounts.campaign.core_platforms.needs_verification.order(:platform)
      @verified_accounts = @person.social_media_accounts.campaign.where(research_status: 'verified').order(:platform)
    end

    def start
      @assignment.start!
      redirect_to verification_assignment_path(@assignment), notice: "Verification started."
    end

    def complete
      incomplete = @assignment.person.social_media_accounts.campaign.core_platforms.needs_verification.count
      if incomplete > 0
        redirect_to verification_assignment_path(@assignment), alert: "#{incomplete} accounts still need verification."
        return
      end

      @assignment.complete!
      redirect_to verification_assignments_path, notice: "Verification completed!"
    end

    private

    def set_assignment
      @assignment = current_user.assignments.data_validation.find(params[:id])
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
