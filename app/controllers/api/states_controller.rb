module Api
  class StatesController < BaseController
    # GET /api/states?state_type=
    def index
      scope = State.order(:name)
      scope = scope.where(state_type: params[:state_type]) if params[:state_type].present?

      records, meta = paginate(scope)
      json_response(records.map { |s| state_json(s) }, meta: meta)
    end

    def show
      state = State.find(params[:id])
      # districts/offices/ballots key on the state abbreviation string,
      # not a state_id foreign key — query by abbreviation.
      json_response(state_json(state).merge(
        districts_count: District.where(state: state.abbreviation).count,
        offices_count: Office.where(state: state.abbreviation).count,
        ballots_count: Ballot.where(state: state.abbreviation).count
      ))
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
  end
end
