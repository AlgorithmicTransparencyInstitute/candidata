module Verification
  class QueueController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'

    def index
      @validation_assignments = current_user.assignments.data_validation.active
                                            .includes(person: :social_media_accounts).order(created_at: :asc)
      @secondary_assignments = current_user.assignments.secondary_verification.active
                                           .includes(person: :social_media_accounts).order(created_at: :asc)
      @completed = current_user.assignments.verification_tasks.completed.includes(:person).order(completed_at: :desc).limit(10)

      @stats = {
        pending_validation: @validation_assignments.pending.count,
        pending_secondary: @secondary_assignments.pending.count,
        in_progress: current_user.assignments.verification_tasks.in_progress.count,
        completed_total: current_user.assignments.verification_tasks.completed.count
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
