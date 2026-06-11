module Api
  class ContestsController < BaseController
    before_action :find_contest, only: [:show, :update, :destroy]
    before_action :authorize_admin!

    def index
      scope = Contest.all
      scope = scope.where(ballot_id: params[:ballot_id]) if params[:ballot_id].present?
      scope = scope.where(office_id: params[:office_id]) if params[:office_id].present?
      scope = scope.where(contest_type: params[:contest_type]) if params[:contest_type].present?

      records, meta = paginate(scope.includes(:office, :ballot), page: params[:page], per_page: params[:per_page])
      json_response(records.map { |c| contest_json(c) }, meta: meta)
    end

    def show
      json_response(contest_detail_json(@contest))
    end

    def create
      contest = Contest.new(contest_params)
      contest.save!
      json_response(contest_detail_json(contest), status: :created)
    end

    def update
      @contest.update!(contest_params)
      json_response(contest_detail_json(@contest))
    end

    def destroy
      @contest.destroy!
      render json: {}, status: :no_content
    end

    private

    def find_contest
      @contest = Contest.find(params[:id])
    end

    def authorize_admin!
      render json: { error: "Unauthorized", code: "FORBIDDEN" }, status: :forbidden unless current_user.admin?
    end

    def contest_params
      params.require(:contest).permit(:ballot_id, :office_id, :contest_type, :description, :total_votes, :number_of_seats)
    end

    def contest_json(contest)
      {
        id: contest.id,
        ballot_id: contest.ballot_id,
        office_id: contest.office_id,
        office_name: contest.office.category,
        office_level: contest.office.level,
        office_branch: contest.office.branch,
        contest_type: contest.contest_type,
        candidates_count: contest.candidates.count,
        total_votes: contest.total_votes
      }
    end

    def contest_detail_json(contest)
      {
        id: contest.id,
        ballot_id: contest.ballot_id,
        office_id: contest.office_id,
        office: {
          id: contest.office.id,
          category: contest.office.category,
          level: contest.office.level,
          branch: contest.office.branch,
          body_name: contest.office.body_name
        },
        contest_type: contest.contest_type,
        description: contest.description,
        total_votes: contest.total_votes,
        number_of_seats: contest.number_of_seats,
        candidates: contest.candidates.map { |c| candidate_detail_json(c) }
      }
    end

    def candidate_detail_json(candidate)
      {
        id: candidate.id,
        person_id: candidate.person_id,
        person_name: candidate.person.full_name,
        outcome: candidate.outcome,
        tally: candidate.tally,
        incumbent: candidate.incumbent,
        party_at_time: candidate.party_at_time
      }
    end
  end
end
