module Api
  class StatesController < BaseController
    def index
      scope = State.all
      scope = scope.where(state_type: params[:state_type]) if params[:state_type].present?

      records, meta = paginate(scope.order(:name), page: params[:page], per_page: params[:per_page])
      json_response(records.map { |s| state_json(s) }, meta: meta)
    end

    def show
      state = State.find(params[:id])
      json_response(state_detail_json(state))
    end

    private

    def state_json(state)
      {
        id: state.id,
        name: state.name,
        abbreviation: state.abbreviation,
        state_type: state.state_type,
        fips_code: state.fips_code
      }
    end

    def state_detail_json(state)
      {
        id: state.id,
        name: state.name,
        abbreviation: state.abbreviation,
        state_type: state.state_type,
        fips_code: state.fips_code,
        districts_count: state.districts.count,
        offices_count: state.offices.count,
        ballots_count: state.ballots.count
      }
    end
  end
end
