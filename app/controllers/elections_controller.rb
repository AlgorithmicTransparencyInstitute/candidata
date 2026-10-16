class ElectionsController < PublicController
  YEAR = 2026
  # Filter key -> Office#office_category. Order here is the display order.
  OFFICES = { 'senate' => 'U.S. Senator', 'governor' => 'Governor', 'house' => 'U.S. Representative' }.freeze
  TYPES = %w[general primary].freeze
  OFFICE_ORDER = Arel.sql(
    "CASE offices.office_category WHEN 'U.S. Senator' THEN 0 WHEN 'Governor' THEN 1 ELSE 2 END"
  )

  def index
    @year = YEAR
    @type = TYPES.include?(params[:type]) ? params[:type] : 'general'
    @office = OFFICES.key?(params[:office]) ? params[:office] : nil
    @states = State.where(abbreviation: Ballot.where(year: @year).distinct.select(:state)).order(:name)
    @state = @states.find { |s| s.abbreviation == params[:state].to_s.upcase }

    base = Contest.joins(:ballot, :office)
                  .where(ballots: { year: @year }, contest_type: @type,
                         offices: { office_category: OFFICES.values })
    base = base.where(ballots: { state: @state.abbreviation }) if @state
    @office_counts = base.group('offices.office_category').count

    scope = @office ? base.where(offices: { office_category: OFFICES[@office] }) : base
    @contests = scope.left_joins(office: :district)
                     .includes({ office: :district }, { ballot: :election }, candidates: :person)
                     .order(OFFICE_ORDER, 'ballots.state', 'districts.district_number', 'contests.party')
                     .page(params[:page]).per(24)

    @elections_by_state = Election.where(year: @year).order(:date).group_by(&:state)
  end

  def show
    @election = Election.find(params[:id])
    contests = Contest.joins(:ballot).where(ballots: { election_id: @election.id })
                      .left_joins(office: :district)
                      .includes({ office: :district }, :ballot, candidates: :person)
                      .order(Arel.sql("CASE offices.office_category WHEN 'U.S. Senator' THEN 0 WHEN 'Governor' THEN 1 " \
                                      "WHEN 'U.S. Representative' THEN 2 ELSE 3 END"),
                             'districts.district_number', 'offices.title', 'contests.party')
                      .to_a
    @sections = contests.group_by { |c| section_for(c.office) }
    @state = State.find_by(abbreviation: @election.state)
    @other_elections = Election.where(state: @election.state, year: @election.year).where.not(id: @election.id).order(:date)
  end

  private

  def section_for(office)
    case office&.office_category
    when 'U.S. Senator' then 'U.S. Senate'
    when 'Governor' then 'Governor'
    when 'U.S. Representative' then 'U.S. House'
    else 'Other offices'
    end
  end
end
