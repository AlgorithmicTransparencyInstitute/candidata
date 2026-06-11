module Api
  class ElectionsController < BaseController
    before_action :find_election, only: [:show, :update, :destroy]
    before_action :authorize_admin!

    def index
      scope = Election.all
      scope = scope.where(year: filter_year) if filter_year.present?

      records, meta = paginate(scope.order(year: :desc), page: params[:page], per_page: params[:per_page])
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
      render json: {}, status: :no_content
    end

    private

    def find_election
      @election = Election.find(params[:id])
    end

    def authorize_admin!
      render json: { error: "Unauthorized", code: "FORBIDDEN" }, status: :forbidden unless current_user.admin?
    end

    def filter_year
      params[:year].presence
    end

    def election_params
      params.require(:election).permit(:year, :election_type, :description)
    end

    def election_json(election)
      {
        id: election.id,
        year: election.year,
        election_type: election.election_type,
        ballots_count: election.ballots.count,
        description: election.description
      }
    end

    def election_detail_json(election)
      {
        id: election.id,
        year: election.year,
        election_type: election.election_type,
        description: election.description,
        ballots: election.ballots.map { |b| ballot_json(b) }
      }
    end

    def ballot_json(ballot)
      {
        id: ballot.id,
        state: ballot.state.abbreviation,
        state_id: ballot.state_id,
        ballot_type: ballot.ballot_type,
        ballot_date: ballot.ballot_date,
        contests_count: ballot.contests.count
      }
    end
  end
end
