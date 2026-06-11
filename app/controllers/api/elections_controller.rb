module Api
  class ElectionsController < BaseController
    before_action :require_admin!, only: [:create, :update, :destroy]
    before_action :set_election, only: [:show, :update, :destroy]

    # GET /api/elections?year=&state=&election_type=
    def index
      scope = Election.order(date: :desc)
      scope = scope.by_year(params[:year]) if params[:year].present?
      scope = scope.by_state(params[:state]) if params[:state].present?
      scope = scope.where(election_type: params[:election_type]) if params[:election_type].present?

      records, meta = paginate(scope)
      json_response(records.map { |e| election_json(e) }, meta: meta)
    end

    def show
      json_response(election_detail_json(@election))
    end

    def create
      election = Election.new(election_params)
      election.save!
      json_response(election_detail_json(election), status: :created)
    end

    def update
      @election.update!(election_params)
      json_response(election_detail_json(@election))
    end

    def destroy
      @election.destroy!
      head :no_content
    end

    private

    def set_election
      @election = Election.find(params[:id])
    end

    def election_params
      params.require(:election).permit(
        :name, :state, :date, :election_type, :year,
        :registration_deadline, :early_voting_start, :early_voting_end
      )
    end

    def election_json(election)
      {
        id: election.id,
        name: election.name,
        full_name: election.full_name,
        state: election.state,
        date: election.date,
        election_type: election.election_type,
        year: election.year,
        ballots_count: election.ballots.size
      }
    end

    def election_detail_json(election)
      election_json(election).merge(
        registration_deadline: election.registration_deadline,
        early_voting_start: election.early_voting_start,
        early_voting_end: election.early_voting_end,
        ballots: election.ballots.includes(:contests).map { |b|
          {
            id: b.id,
            full_name: b.full_name,
            state: b.state,
            date: b.date,
            election_type: b.election_type,
            party: b.party,
            contests_count: b.contests.size
          }
        }
      )
    end
  end
end
