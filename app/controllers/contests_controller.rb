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
    @candidates = order_candidates(@contest.candidates.to_a)
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

  private

  # Published ordering rule (stated on the page): winners first, then
  # Democrats and Republicans, then everyone else; incumbents before
  # challengers; then alphabetical by last name. Never by vote share alone
  # until tallies exist, never by engagement.
  def order_candidates(candidates)
    candidates.sort_by do |c|
      party = c.party_at_time.presence || @contest.party.to_s
      [Candidate::WINNING_OUTCOMES.include?(c.outcome) ? 0 : 1,
       -c.tally.to_i,
       party.start_with?('Democrat', 'Republican') ? 0 : 1,
       c.incumbent ? 0 : 1,
       c.person.last_name.to_s.downcase, c.person.first_name.to_s.downcase]
    end
  end
end
