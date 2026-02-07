class HomeController < ApplicationController
  def index
    @people_count = Person.count
    @offices_count = Office.count
    @bodies_count = Office.where.not(body_name: [nil, '']).distinct.count(:body_name)
    @parties_count = Party.count
    @states_count = State.count
    @districts_count = District.count
    @current_officeholders_count = Person.current_officeholders.count

    # 2026 Primary data
    @ballots_2026 = Ballot.where(year: 2026).includes(:contests).order(:state, :party)
    @total_2026_candidates = Candidate.joins(contest: :ballot).where(ballots: { year: 2026 }).count
    @total_2026_contests = Contest.joins(:ballot).where(ballots: { year: 2026 }).count
  end
end
