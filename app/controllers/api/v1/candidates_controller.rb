module Api
  module V1
    class CandidatesController < BaseController
      # GET /api/v1/candidates — all joins are belongs_to chains (candidate →
      # contest → ballot/office → district), so no row multiplication.
      def index
        since = updated_since_param
        return if performed?

        scope = Candidate.joins(contest: [:ballot, :office]).order(:id)
        scope = scope.where("candidates.updated_at >= ?", since) if since
        scope = scope.merge(Candidate.for_year(params[:year].to_i)) if params[:year].present?
        scope = scope.where(ballots: { state: params[:state] }) if params[:state].present?
        scope = scope.where(offices: { office_category: params[:office_category] }) if params[:office_category].present?

        if params[:district].present?
          scope = scope.joins(contest: { office: :district })
                       .where(districts: { district_number: params[:district] })
        end
        if params[:chamber].present?
          scope = scope.joins(contest: { office: :district })
                       .where(districts: { chamber: params[:chamber] })
        end

        scope = scope.where(party_at_time: params[:party]) if params[:party].present?
        scope = scope.where(outcome: params[:outcome]) if params[:outcome].present?
        scope = scope.where(outcome: Candidate::WINNING_OUTCOMES) if params[:winners] == "true"

        case params[:incumbent]
        when "true" then scope = scope.merge(Candidate.incumbents)
        when "false" then scope = scope.merge(Candidate.challengers)
        end

        records, meta = paginate(
          scope.includes(
            { person: [:party_affiliation, :social_media_accounts, { person_parties: :party }] },
            { contest: [{ office: :district }, { ballot: :election }] }
          )
        )
        json_response(records.map { |c| candidate_json(c) }, meta: meta)
      end

      private

      def candidate_json(candidate)
        {
          id: candidate.id,
          outcome: candidate.outcome,
          winner: candidate.winner?,
          incumbent: candidate.incumbent == true,
          party_at_time: candidate.party_at_time,
          tally: candidate.tally,
          updated_at: candidate.updated_at&.iso8601,
          person: person_core_json(candidate.person),
          contest: contest_json(candidate.contest)
        }
      end
    end
  end
end
