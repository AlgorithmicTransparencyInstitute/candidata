module Api
  class BallotsController < BaseController
    before_action :find_ballot, only: [:show, :update, :destroy]
    before_action :authorize_admin!

    def index
      scope = Ballot.all
      scope = scope.where(election_id: params[:election_id]) if params[:election_id].present?
      scope = scope.where(state_id: params[:state_id]) if params[:state_id].present?
      scope = scope.where(ballot_type: params[:ballot_type]) if params[:ballot_type].present?

      records, meta = paginate(scope.order(ballot_date: :desc), page: params[:page], per_page: params[:per_page])
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
      render json: {}, status: :no_content
    end

    private

    def find_ballot
      @ballot = Ballot.find(params[:id])
    end

    def authorize_admin!
      render json: { error: "Unauthorized", code: "FORBIDDEN" }, status: :forbidden unless current_user.admin?
    end

    def ballot_params
      params.require(:ballot).permit(:election_id, :state_id, :ballot_type, :ballot_date, :year)
    end

    def ballot_json(ballot)
      {
        id: ballot.id,
        election_id: ballot.election_id,
        state_id: ballot.state_id,
        state: ballot.state.abbreviation,
        ballot_type: ballot.ballot_type,
        ballot_date: ballot.ballot_date,
        year: ballot.year,
        contests_count: ballot.contests.count
      }
    end

    def ballot_detail_json(ballot)
      {
        id: ballot.id,
        election_id: ballot.election_id,
        state_id: ballot.state_id,
        state: ballot.state.abbreviation,
        ballot_type: ballot.ballot_type,
        ballot_date: ballot.ballot_date,
        year: ballot.year,
        contests: ballot.contests.map { |c| contest_summary_json(c) }
      }
    end

    def contest_summary_json(contest)
      {
        id: contest.id,
        office_id: contest.office_id,
        office_name: contest.office.category,
        contest_type: contest.contest_type,
        candidates_count: contest.candidates.count
      }
    end
  end
end
