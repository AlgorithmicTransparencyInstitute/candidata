module Researcher
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'

    def index
      @research_assignments = current_user.assignments.research.active.includes(person: :social_media_accounts)
      @verification_assignments = current_user.assignments.verification.active.includes(person: :social_media_accounts)
      @completed_assignments = current_user.assignments.completed.includes(:person).order(completed_at: :desc).limit(10)

      @stats = {
        pending_research: @research_assignments.pending.count,
        in_progress_research: @research_assignments.in_progress.count,
        pending_verification: @verification_assignments.pending.count,
        in_progress_verification: @verification_assignments.in_progress.count,
        completed_total: current_user.assignments.completed.count
      }
    end

    private

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
