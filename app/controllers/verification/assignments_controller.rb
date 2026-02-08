module Verification
  class AssignmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_assignment, only: [:show, :start, :complete, :reopen]

    def index
      @assignments = current_user.assignments.data_validation.active.includes(person: :social_media_accounts).order(created_at: :asc)
    end

    def show
      @person = @assignment.person
      # Show all core platform accounts - verifiers can handle entered, empty, or incorrect data
      @accounts = @person.social_media_accounts.campaign.core_platforms.where.not(research_status: 'verified').order(:platform)
      @verified_accounts = @person.social_media_accounts.campaign.core_platforms.where(research_status: 'verified').order(:platform)
      @current_offices = @person.officeholders.current.includes(office: [:body, :district])
      @candidacies = @person.candidates.includes(contest: [:ballot, :office]).order('contests.date DESC')
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
      redirect_to verification_queue_path, notice: "Verification completed!"
    end

    def reopen
      @assignment.reopen!
      redirect_to verification_assignment_path(@assignment), notice: "Verification reopened."
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
