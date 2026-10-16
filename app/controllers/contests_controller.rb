class ContestsController < PublicController
  def index
    @contests = Contest.includes(:office, :ballot, :candidates).order(date: :desc)

    if params[:year].present?
      year = params[:year].to_i
      @contests = @contests.joins(:ballot).where(ballots: { year: year })
    end

    if params[:state].present?
      @contests = @contests.joins(:ballot).where(ballots: { state: params[:state] })
    end

    if params[:party].present?
      @contests = @contests.where(party: params[:party])
    end

    if params[:contest_type].present?
      @contests = @contests.where(contest_type: params[:contest_type])
    end

    @contests = @contests.page(params[:page]).per(50)

    @years = Ballot.where.not(year: nil).distinct.pluck(:year).sort.reverse
    @states = Ballot.where.not(state: nil).distinct.pluck(:state).sort
    @parties = Contest.where.not(party: nil).distinct.pluck(:party).sort
    @contest_types = Contest::CONTEST_TYPES
  end

  def show
    @contest = Contest.includes({ office: [:district, :body] }, { ballot: :election },
                                candidates: { person: [:social_media_accounts, { person_parties: :party }] })
                      .find(params[:id])
    @candidates = Candidate.in_public_order(@contest.candidates.to_a)
    @total_votes = @candidates.sum { |c| c.tally.to_i }

    # The same seat's other contests that year: a general links back to the
    # primaries its nominees came from, a primary forward to the general.
    @related_contests = if @contest.office_id
                          Contest.joins(:ballot).includes(:ballot)
                                 .where(office_id: @contest.office_id, ballots: { year: @contest.ballot&.year })
                                 .where.not(id: @contest.id)
                                 .order(:date, :party)
                        else
                          Contest.none
                        end
  end
end
