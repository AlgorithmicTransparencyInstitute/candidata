module Admin
  class VisitsController < Admin::BaseController
    def index
      @visits = Ahoy::Visit.includes(:user)
                           .order(started_at: :desc)
                           .page(params[:page]).per(50)

      # Statistics
      @total_visits = Ahoy::Visit.count
      @unique_visitors = Ahoy::Visit.distinct.count(:user_id)
      @visits_today = Ahoy::Visit.where('started_at >= ?', Time.current.beginning_of_day).count
      @visits_this_week = Ahoy::Visit.where('started_at >= ?', 1.week.ago).count
      @visits_this_month = Ahoy::Visit.where('started_at >= ?', 1.month.ago).count

      # Most active users
      @most_active_users = User.joins(:visits)
                               .where('ahoy_visits.started_at >= ?', 1.month.ago)
                               .group('users.id')
                               .order('COUNT(ahoy_visits.id) DESC')
                               .limit(10)
                               .select('users.*, COUNT(ahoy_visits.id) as visits_count')

      # Filter by user if provided
      if params[:user_id].present?
        @visits = @visits.where(user_id: params[:user_id])
        @filtered_user = User.find(params[:user_id])
      end

      # Filter by date range if provided
      if params[:start_date].present?
        @visits = @visits.where('started_at >= ?', params[:start_date])
      end
      if params[:end_date].present?
        @visits = @visits.where('started_at <= ?', params[:end_date])
      end
    end
  end
end
