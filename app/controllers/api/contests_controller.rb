module Api
  class ContestsController < BaseController
    before_action :require_admin!, only: [:create, :update, :destroy]
    before_action :set_contest, only: [:show, :update, :destroy]

    # GET /api/contests?ballot_id=&office_id=&contest_type=&party=&year=
    def index
      scope = Contest.order(date: :desc)
      scope = scope.where(ballot_id: params[:ballot_id]) if params[:ballot_id].present?
      scope = scope.for_office(params[:office_id]) if params[:office_id].present?
      scope = scope.where(contest_type: params[:contest_type]) if params[:contest_type].present?
      scope = scope.for_party(params[:party]) if params[:party].present?
      scope = scope.for_year(params[:year].to_i) if params[:year].present?

      records, meta = paginate(scope.includes(:office, :ballot, :candidates))
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
      head :no_content
    end

    private

    def set_contest
      @contest = Contest.find(params[:id])
    end

    def contest_params
      params.require(:contest).permit(:date, :location, :contest_type, :party, :office_id, :ballot_id)
    end

    def contest_json(contest)
      {
        id: contest.id,
        full_name: contest.full_name,
        date: contest.date,
        location: contest.location,
        contest_type: contest.contest_type,
        party: contest.party,
        office_id: contest.office_id,
        office_title: contest.office.display_name,
        ballot_id: contest.ballot_id,
        candidates_count: contest.candidates.size
      }
    end

    def contest_detail_json(contest)
      contest_json(contest).merge(
        office: {
          id: contest.office.id,
          title: contest.office.title,
          seat: contest.office.seat,
          level: contest.office.level,
          branch: contest.office.branch,
          state: contest.office.state
        },
        ballot: {
          id: contest.ballot.id,
          full_name: contest.ballot.full_name,
          date: contest.ballot.date
        },
        total_votes: contest.total_votes,
        candidates: contest.candidates.includes(:person).map { |c|
          {
            id: c.id,
            person_id: c.person_id,
            person_name: c.person.full_name,
            outcome: c.outcome,
            tally: c.tally,
            incumbent: c.incumbent,
            party_at_time: c.party_at_time
          }
        }
      )
    end
  end
end
