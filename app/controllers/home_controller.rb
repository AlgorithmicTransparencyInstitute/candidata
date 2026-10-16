class HomeController < PublicController
  def index
    # Headline counts change slowly; cache them rather than run nine COUNTs
    # per page view. Accounts = what the public site actually shows.
    counts = Rails.cache.fetch('home/counts/v2', expires_in: 10.minutes) do
      {
        people: Person.count, offices: Office.count,
        bodies: Office.where.not(body_name: [nil, '']).distinct.count(:body_name),
        parties: Party.count, states: State.count, districts: District.count,
        accounts: SocialMediaAccount.publicly_listed.count,
        current_officeholders: Officeholder.current.distinct.count(:person_id)
      }
    end
    @people_count = counts[:people]
    @offices_count = counts[:offices]
    @bodies_count = counts[:bodies]
    @parties_count = counts[:parties]
    @states_count = counts[:states]
    @districts_count = counts[:districts]
    @accounts_count = counts[:accounts]
    @current_officeholders_count = counts[:current_officeholders]

    # Upcoming elections
    @upcoming_elections = Election.where('date >= ?', Date.current)
                                   .order(:date)
                                   .includes(:ballots)
                                   .limit(6)

    # 2026 Primary data
    @has_2026_ballots = Ballot.where(year: 2026).exists?
    @total_2026_candidates = Candidate.joins(contest: :ballot).where(ballots: { year: 2026 }).count
    @total_2026_contests = Contest.joins(:ballot).where(ballots: { year: 2026 }).count
    @states_2026_count = Ballot.where(year: 2026).distinct.count(:state)

    # Preload state names for display
    @states_by_abbr = State.all.index_by(&:abbreviation)

    # Prepare state election data for map
    @state_elections_data = Election.where(year: 2026, election_type: 'primary')
                                     .select('elections.*, COUNT(DISTINCT contests.id) as contest_count')
                                     .joins('LEFT JOIN ballots ON ballots.election_id = elections.id')
                                     .joins('LEFT JOIN contests ON contests.ballot_id = ballots.id')
                                     .group('elections.id')
                                     .order('elections.state')
                                     .index_by(&:state)
  end

  def help
    # Public help page showing researcher guides
  end
end
