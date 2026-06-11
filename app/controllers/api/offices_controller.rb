module Api
  class OfficesController < BaseController
    before_action :require_admin!, only: [:create, :update]
    before_action :set_office, only: [:show, :update]

    # GET /api/offices?q=&level=&branch=&state=&office_category=&body_name=
    def index
      scope = Office.order(:title, :seat)
      if params[:q].present?
        pattern = "%#{Office.sanitize_sql_like(params[:q])}%"
        scope = scope.where("title ILIKE :p OR seat ILIKE :p OR body_name ILIKE :p", p: pattern)
      end
      scope = scope.where(level: params[:level]) if params[:level].present?
      scope = scope.where(branch: params[:branch]) if params[:branch].present?
      scope = scope.where(state: params[:state]) if params[:state].present?
      scope = scope.by_category(params[:office_category]) if params[:office_category].present?
      scope = scope.by_body(params[:body_name]) if params[:body_name].present?

      records, meta = paginate(scope)
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

    def set_office
      @office = Office.find(params[:id])
    end

    def office_params
      params.require(:office).permit(
        :title, :level, :branch, :state, :seat, :role, :office_category,
        :body_name, :jurisdiction, :county, :district_id, :body_id, :ocdid
      )
    end

    def office_json(office)
      {
        id: office.id,
        title: office.title,
        display_name: office.display_name,
        seat: office.seat,
        level: office.level,
        branch: office.branch,
        state: office.state,
        office_category: office.office_category,
        body_name: office.body_name
      }
    end

    def office_detail_json(office)
      office_json(office).merge(
        role: office.role,
        jurisdiction: office.jurisdiction,
        county: office.county,
        ocdid: office.ocdid,
        district_id: office.district_id,
        body_id: office.body_id,
        current_officeholders: office.officeholders.current.includes(:person).map { |oh|
          {
            id: oh.id,
            person_id: oh.person_id,
            person_name: oh.person.full_name,
            start_date: oh.start_date,
            end_date: oh.end_date,
            elected_year: oh.elected_year,
            appointed: oh.appointed
          }
        }
      )
    end
  end
end
