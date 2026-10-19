class HomeController < PublicController
  YEAR = ElectionsController::YEAR

  def index
    # Headline counts change slowly; cache them rather than run a COUNT per
    # page view. Accounts = what the public site actually shows.
    counts = Rails.cache.fetch('home/counts/v3', expires_in: 10.minutes) do
      {
        people: Person.count,
        current_officeholders: Officeholder.current.distinct.count(:person_id),
        accounts: SocialMediaAccount.publicly_listed.count,
        offices: Office.count, states: State.count, districts: District.count,
        bodies: Office.where.not(body_name: [nil, '']).distinct.count(:body_name),
        parties: Party.count
      }
    end
    @counts = counts

    load_general_races
  end

  # The geographic map is ~75 KB of path data, so the home page renders the
  # tile grid and fetches this only when a visitor switches to the map.
  def state_map
    load_general_races
    @geo = self.class.state_paths
    @abbr_by_fips = State.pluck(:fips_code, :abbreviation).to_h
    expires_in 10.minutes, public: true
    render partial: 'public/state_geo_map_frame', layout: false
  end

  def self.state_paths
    @state_paths ||= JSON.parse(Rails.root.join('lib/data/us_state_paths.json').read).freeze
  end

  def help
    # Public help page showing researcher guides
  end

  private

  # 2026 general: which federal/governor races each state has, for the maps
  # and the office tiles.
  def load_general_races
    general = Rails.cache.fetch("home/general/#{YEAR}/v1", expires_in: 10.minutes) do
      rows = Contest.joins(:ballot, :office)
                    .where(ballots: { year: YEAR }, contest_type: 'general',
                           offices: { office_category: ElectionsController::OFFICES.values })
                    .group('ballots.state', 'offices.office_category').count
      by_state = {}
      rows.each { |(state, category), n| (by_state[state] ||= {})[category] = n }
      totals = rows.each_with_object({}) { |((_, category), n), h| h[category] = h.fetch(category, 0) + n }
      { by_state: by_state, totals: totals,
        date: Election.where(year: YEAR, election_type: 'general').minimum(:date) }
    end
    @general_by_state = general[:by_state]
    @general_totals = general[:totals]
    @general_date = general[:date]
    @state_names = State.pluck(:abbreviation, :name).to_h
  end
end
