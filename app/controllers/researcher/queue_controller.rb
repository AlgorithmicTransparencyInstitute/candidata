module Researcher
  class QueueController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'

    def index
      @assignments = current_user.assignments.data_collection.active.includes(person: :social_media_accounts).order(created_at: :asc)
      @completed = current_user.assignments.data_collection.completed.includes(:person).order(completed_at: :desc).limit(10)

      @stats = {
        pending: @assignments.pending.count,
        in_progress: @assignments.in_progress.count,
        completed_total: current_user.assignments.data_collection.completed.count
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
