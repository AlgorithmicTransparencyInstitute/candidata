module Researcher
  class AssignmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_assignment, only: [:show, :start, :complete]

    def index
      @assignments = current_user.assignments.active.includes(person: :social_media_accounts).order(created_at: :asc)
      @filter = params[:filter] || 'all'

      case @filter
      when 'research'
        @assignments = @assignments.research
      when 'verification'
        @assignments = @assignments.verification
      when 'pending'
        @assignments = @assignments.pending
      when 'in_progress'
        @assignments = @assignments.in_progress
      end
    end

    def show
      @person = @assignment.person
      @accounts = @person.social_media_accounts.campaign.core_platforms.order(:platform)
      @official_accounts = @person.social_media_accounts.official.order(:platform)
    end

    def start
      @assignment.start!
      redirect_to researcher_assignment_path(@assignment), notice: "Assignment started."
    end

    def complete
      if @assignment.task_type == 'research'
        incomplete = @assignment.person.social_media_accounts.campaign.core_platforms.needs_research.count
        if incomplete > 0
          redirect_to researcher_assignment_path(@assignment), alert: "#{incomplete} accounts still need research."
          return
        end
      end

      @assignment.complete!
      redirect_to researcher_assignments_path, notice: "Assignment completed!"
    end

    private

    def set_assignment
      @assignment = current_user.assignments.find(params[:id])
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
