module Api
  class OfficesController < BaseController
    before_action :find_office, only: [:show, :update]
    before_action :authorize_admin!, except: [:index, :show]

    def index
      scope = Office.all
      scope = scope.where(level: params[:level]) if params[:level].present?
      scope = scope.where(branch: params[:branch]) if params[:branch].present?
      scope = scope.where(category: params[:category]) if params[:category].present?
      scope = scope.where(district_id: params[:district_id]) if params[:district_id].present?
      scope = scope.where(body_id: params[:body_id]) if params[:body_id].present?

      records, meta = paginate(scope.order(:category), page: params[:page], per_page: params[:per_page])
      json_response(records.map { |o| office_json(o) }, meta: meta)
    end

    def show
      json_response(office_detail_json(@office))
    end

    def create
      office = Office.new(office_params)
      office.save!
      json_response(office_detail_json(office), status: :created)
    end

    def update
      @office.update!(office_params)
      json_response(office_detail_json(@office))
    end

    private

    def find_office
      @office = Office.find(params[:id])
    end

    def authorize_admin!
      render json: { error: "Unauthorized", code: "FORBIDDEN" }, status: :forbidden unless current_user.admin?
    end

    def office_params
      params.require(:office).permit(
        :district_id, :body_id, :category, :level, :branch, :role, :body_name, :ocd_id
      )
    end

    def office_json(office)
      {
        id: office.id,
        category: office.category,
        level: office.level,
        branch: office.branch,
        body_name: office.body_name,
        state: office.district&.state&.abbreviation,
        current_holders_count: office.officeholders.current.count
      }
    end

    def office_detail_json(office)
      {
        id: office.id,
        category: office.category,
        level: office.level,
        branch: office.branch,
        role: office.role,
        body_name: office.body_name,
        body_id: office.body_id,
        district_id: office.district_id,
        district_name: office.district&.full_name,
        state: office.district&.state&.abbreviation,
        ocd_id: office.ocd_id,
        current_holders: office.officeholders.current.map { |oh| current_holder_json(oh) }
      }
    end

    def current_holder_json(officeholder)
      {
        id: officeholder.id,
        person_id: officeholder.person_id,
        person_name: officeholder.person.full_name,
        start_date: officeholder.start_date,
        end_date: officeholder.end_date,
        elected_year: officeholder.elected_year,
        appointed: officeholder.appointed
      }
    end
  end
end
