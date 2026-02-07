module Researcher
  class AssignmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_assignment, only: [:show, :start, :complete, :reopen]

    def index
      @filter = params[:filter] || 'all'

      if @filter == 'completed'
        @assignments = current_user.assignments.completed.includes(person: :social_media_accounts).order(completed_at: :desc)
      else
        @assignments = current_user.assignments.active.includes(person: :social_media_accounts).order(created_at: :asc)
        case @filter
        when 'data_collection'
          @assignments = @assignments.data_collection
        when 'data_validation'
          @assignments = @assignments.data_validation
        when 'pending'
          @assignments = @assignments.pending
        when 'in_progress'
          @assignments = @assignments.in_progress
        end
      end

      @completed_count = current_user.assignments.completed.count
    end

    def show
      @person = @assignment.person
      @accounts = @person.social_media_accounts.campaign.core_platforms.order(:platform)
      @official_accounts = @person.social_media_accounts.official.order(:platform)
      @current_offices = @person.officeholders.current.includes(office: [:body, :district])
      @past_offices = @person.officeholders.former.includes(office: [:body, :district]).order(end_date: :desc)
      @candidacies = @person.candidates.includes(contest: [:ballot, :office]).order('contests.date DESC')
    end

    def start
      @assignment.start!
      redirect_to researcher_assignment_path(@assignment), notice: "Assignment started."
    end

    def complete
      if @assignment.task_type == 'data_collection'
        accounts = @assignment.person.social_media_accounts.campaign.core_platforms
        incomplete = accounts.needs_research.count
        if incomplete > 0
          redirect_to researcher_assignment_path(@assignment), alert: "#{incomplete} accounts still need research."
          return
        end

        unverified = accounts.where(researcher_verified: false).count
        if unverified > 0
          redirect_to researcher_assignment_path(@assignment), alert: "#{unverified} accounts haven't been verified on Google/platform yet."
          return
        end
      end

      @assignment.complete!

      # Track assignment completion
      track_event('Assignment Completed', {
        task_type: @assignment.task_type,
        person_id: @assignment.person_id
      })
      increment_mixpanel_counter(current_user, 'assignments_completed')

      redirect_to researcher_assignments_path, notice: "Assignment completed!"
    end

    def reopen
      if @assignment.has_validation_assignment?
        redirect_to researcher_assignment_path(@assignment), alert: "Cannot reopen — this person already has an active validation assignment."
        return
      end

      @assignment.reopen!
      redirect_to researcher_assignment_path(@assignment), notice: "Assignment reopened."
    end

    private

    def set_assignment
      @assignment = current_user.assignments.data_collection.find(params[:id])
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
