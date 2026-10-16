# Site-wide search: one box across people, states, 2026 races and offices.
class SearchController < PublicController
  # "TX-8", "tx 8", "TX-Sen", "ca senate", "ny governor"
  SEAT_PATTERN = /\A(?<state>[a-z]{2})[\s-]*(?<seat>\d{1,2}|al|at-large|sen|senate|gov|governor)\z/i

  def index
    @q = params[:q].to_s.squish.first(100)
    return if @q.blank?

    @people = Person.name_matching(@q)
                    .includes(person_parties: :party, officeholders: { office: :district })
                    .limit(30).to_a
    @states = State.where('name ILIKE :p OR abbreviation ILIKE :q',
                          p: "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%", q: @q).order(:name).limit(5)
    @races = seat_races
    @offices = Office.search_text(@q).where(level: %w[federal state]).includes(:district).order(:title).limit(10)
  end

  private

  def seat_races
    m = SEAT_PATTERN.match(@q) or return []

    state = m[:state].upcase
    seat = m[:seat].downcase
    category = case seat
               when 'sen', 'senate' then 'U.S. Senator'
               when 'gov', 'governor' then 'Governor'
               else 'U.S. Representative'
               end
    scope = Contest.joins(:ballot, :office)
                   .where(ballots: { state: state, year: ElectionsController::YEAR }, offices: { office_category: category })
                   .includes({ office: :district }, { ballot: :election }, candidates: :person)
                   .order(Arel.sql("CASE contests.contest_type WHEN 'general' THEN 0 ELSE 1 END"), :party)
    if category == 'U.S. Representative'
      number = seat.match?(/\A\d+\z/) ? seat.to_i : 0
      scope = scope.joins(office: :district).where(districts: { district_number: number })
    end
    scope.limit(6).to_a
  end
end
