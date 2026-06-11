module Api
  class CandidatesController < BaseController
    before_action :require_admin!, only: [:create, :update, :destroy]
    before_action :set_candidate, only: [:show, :update, :destroy]

    # GET /api/candidates?contest_id=&person_id=&outcome=&incumbent=
    def index
      scope = Candidate.order(id: :desc)
      scope = scope.where(contest_id: params[:contest_id]) if params[:contest_id].present?
      scope = scope.where(person_id: params[:person_id]) if params[:person_id].present?
      scope = scope.where(outcome: params[:outcome]) if params[:outcome].present?
      scope = scope.where(incumbent: params[:incumbent] == "true") if params[:incumbent].present?

      records, meta = paginate(scope.includes(:person, contest: [:office, :ballot]))
      json_response(records.map { |c| candidate_json(c) }, meta: meta)
    end

    def show
      json_response(candidate_detail_json(@candidate))
    end

    def create
      candidate = Candidate.new(candidate_params)
      candidate.outcome = "pending" if candidate.outcome.blank?
      candidate.save!
      json_response(candidate_detail_json(candidate), status: :created)
    end

    def update
      @candidate.update!(candidate_params)
      json_response(candidate_detail_json(@candidate))
    end

    def destroy
      @candidate.destroy!
      head :no_content
    end

    private

    def set_candidate
      @candidate = Candidate.find(params[:id])
    end

    def candidate_params
      params.require(:candidate).permit(:person_id, :contest_id, :outcome, :tally, :party_at_time, :incumbent)
    end

    def candidate_json(candidate)
      {
        id: candidate.id,
        person_id: candidate.person_id,
        person_name: candidate.person.full_name,
        contest_id: candidate.contest_id,
        contest_name: candidate.contest.full_name,
        outcome: candidate.outcome,
        tally: candidate.tally,
        party_at_time: candidate.party_at_time,
        incumbent: candidate.incumbent
      }
    end

    def candidate_detail_json(candidate)
      candidate_json(candidate).merge(
        vote_percentage: candidate.vote_percentage,
        person: {
          id: candidate.person.id,
          full_name: candidate.person.full_name,
          state_of_residence: candidate.person.state_of_residence,
          gender: candidate.person.gender,
          race: candidate.person.race
        },
        contest: {
          id: candidate.contest.id,
          full_name: candidate.contest.full_name,
          contest_type: candidate.contest.contest_type,
          party: candidate.contest.party,
          date: candidate.contest.date
        }
      )
    end
  end
end
