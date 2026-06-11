module Api
  class CandidatesController < BaseController
    before_action :find_candidate, only: [:show, :update, :destroy]
    before_action :authorize_admin!

    def index
      scope = Candidate.all
      scope = scope.where(contest_id: params[:contest_id]) if params[:contest_id].present?
      scope = scope.where(person_id: params[:person_id]) if params[:person_id].present?
      scope = scope.where(outcome: params[:outcome]) if params[:outcome].present?

      records, meta = paginate(scope.includes(:person, :contest), page: params[:page], per_page: params[:per_page])
      json_response(records.map { |c| candidate_json(c) }, meta: meta)
    end

    def show
      json_response(candidate_detail_json(@candidate))
    end

    def create
      candidate = Candidate.new(candidate_params)
      candidate.save!
      json_response(candidate_detail_json(candidate), status: :created)
    end

    def update
      @candidate.update!(candidate_params)
      json_response(candidate_detail_json(@candidate))
    end

    def destroy
      @candidate.destroy!
      render json: {}, status: :no_content
    end

    private

    def find_candidate
      @candidate = Candidate.find(params[:id])
    end

    def authorize_admin!
      render json: { error: "Unauthorized", code: "FORBIDDEN" }, status: :forbidden unless current_user.admin?
    end

    def candidate_params
      params.require(:candidate).permit(:person_id, :contest_id, :outcome, :tally, :incumbent, :party_at_time)
    end

    def candidate_json(candidate)
      {
        id: candidate.id,
        person_id: candidate.person_id,
        person_name: candidate.person.full_name,
        contest_id: candidate.contest_id,
        contest_office: candidate.contest.office.category,
        outcome: candidate.outcome,
        tally: candidate.tally,
        incumbent: candidate.incumbent
      }
    end

    def candidate_detail_json(candidate)
      {
        id: candidate.id,
        person_id: candidate.person_id,
        person: {
          id: candidate.person.id,
          first_name: candidate.person.first_name,
          last_name: candidate.person.last_name,
          full_name: candidate.person.full_name,
          state_of_residence: candidate.person.state_of_residence
        },
        contest_id: candidate.contest_id,
        contest: {
          id: candidate.contest.id,
          office_category: candidate.contest.office.category,
          office_level: candidate.contest.office.level
        },
        outcome: candidate.outcome,
        tally: candidate.tally,
        incumbent: candidate.incumbent,
        party_at_time: candidate.party_at_time
      }
    end
  end
end
