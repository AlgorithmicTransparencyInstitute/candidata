module Api
  class BallotsController < BaseController
    before_action :require_admin!, only: [:create, :update, :destroy]
    before_action :set_ballot, only: [:show, :update, :destroy]

    # GET /api/ballots?election_id=&state=&election_type=&year=&party=
    def index
      scope = Ballot.order(date: :desc, state: :asc)
      scope = scope.where(election_id: params[:election_id]) if params[:election_id].present?
      scope = scope.for_state(params[:state]) if params[:state].present?
      scope = scope.where(election_type: params[:election_type]) if params[:election_type].present?
      scope = scope.for_year(params[:year]) if params[:year].present?
      scope = scope.for_party(params[:party]) if params[:party].present?

      records, meta = paginate(scope.includes(:contests))
      json_response(records.map { |b| ballot_json(b) }, meta: meta)
    end

    def show
      json_response(ballot_detail_json(@ballot))
    end

    def create
      ballot = Ballot.new(ballot_params)
      ballot.save!
      json_response(ballot_detail_json(ballot), status: :created)
    end

    def update
      @ballot.update!(ballot_params)
      json_response(ballot_detail_json(@ballot))
    end

    def destroy
      @ballot.destroy!
      head :no_content
    end

    private

    def set_ballot
      @ballot = Ballot.find(params[:id])
    end

    def ballot_params
      params.require(:ballot).permit(:state, :date, :election_type, :year, :name, :party, :election_id)
    end

    def ballot_json(ballot)
      {
        id: ballot.id,
        full_name: ballot.full_name,
        name: ballot.name,
        state: ballot.state,
        date: ballot.date,
        election_type: ballot.election_type,
        year: ballot.year,
        party: ballot.party,
        election_id: ballot.election_id,
        contests_count: ballot.contests.size
      }
    end

    def ballot_detail_json(ballot)
      ballot_json(ballot).merge(
        contests: ballot.contests.includes(:office, :candidates).map { |c|
          {
            id: c.id,
            office_id: c.office_id,
            office_title: c.office.display_name,
            contest_type: c.contest_type,
            party: c.party,
            candidates_count: c.candidates.size
          }
        }
      )
    end
  end
end
