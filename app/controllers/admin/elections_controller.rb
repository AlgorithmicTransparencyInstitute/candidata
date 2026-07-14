module Admin
  class ElectionsController < Admin::BaseController
    before_action :set_election, only: [:show, :edit, :update, :destroy, :add_ballots]

    def index
      @elections = Election.includes(ballots: :contests).order(date: :asc)

      if params[:q].present?
        @elections = @elections.where("name ILIKE ? OR state ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
      end

      if params[:year].present?
        @elections = @elections.where(year: params[:year])
      end

      if params[:state].present?
        @elections = @elections.where(state: params[:state])
      end

      if params[:election_type].present?
        @elections = @elections.where(election_type: params[:election_type])
      end

      @elections = @elections.page(params[:page]).per(50)
      # [name, abbreviation] so the submitted value matches elections.state.
      @states = State.order(:name).pluck(:name, :abbreviation)
      @years = Election.distinct.pluck(:year).compact.sort.reverse
    end

    def show
      @ballots = @election.ballots.includes(:contests).order(:party, :date)
      # Guided ballot coverage: for a primary, surface which party ballots don't
      # yet exist so they can be created in one click.
      @existing_ballot_parties = @ballots.map(&:party).compact
      @missing_ballot_parties =
        if @election.election_type == 'primary'
          Party.ballot_vocabulary - @existing_ballot_parties
        else
          []
        end
      # Parties already used by candidates in this election that lack a ballot —
      # the strongest "should exist" signal.
      @suggested_ballot_parties = suggested_missing_parties
    end

    # Create one or more ballots for this election (find-or-create, so it's
    # idempotent and never duplicates). Primaries take a list of parties.
    def add_ballots
      requested =
        if @election.election_type == 'primary'
          Array(params[:parties]).map { |p| p.to_s.strip }.reject(&:blank?)
        else
          [nil] # a single non-party ballot
        end

      if @election.election_type == 'primary' && requested.empty?
        return redirect_to admin_election_path(@election), alert: 'Pick at least one party to add ballots for.'
      end

      created = requested.filter_map do |party|
        next if party && !Party.ballot_vocabulary.include?(party)

        ballot = find_or_create_election_ballot(party)
        ballot if ballot.previously_new_record?
      end

      notice = created.any? ? "Added #{helpers.pluralize(created.size, 'ballot')}." : 'No new ballots — they already exist.'
      redirect_to admin_election_path(@election), notice: notice
    end

    def new
      @election = Election.new
    end

    def create
      @election = Election.new(election_params)
      if @election.save
        redirect_to admin_election_path(@election), notice: "Election created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @election.update(election_params)
        redirect_to admin_election_path(@election), notice: "Election updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @election.destroy
      redirect_to admin_elections_path, notice: "Election deleted."
    end

    private

    def set_election
      @election = Election.find(params[:id])
    end

    # Find-or-create a ballot for this election on the same keys the editor uses,
    # backfilling year + election link. Idempotent.
    def find_or_create_election_ballot(party)
      Ballot.find_or_create_by!(
        state: @election.state,
        date: @election.date,
        election_type: @election.election_type,
        party: party
      ) do |b|
        b.year = @election.year
        b.election_id = @election.id
      end.tap { |b| b.update!(election_id: @election.id) if b.election_id.nil? }
    end

    # Parties that candidates in this election ran under but which have no ballot
    # yet — the clearest gaps to fill. Only meaningful for primaries.
    def suggested_missing_parties
      return [] unless @election.election_type == 'primary'

      used = Candidate.joins(contest: :ballot)
                      .where(ballots: { election_id: @election.id })
                      .distinct.pluck(:party_at_time)
                      .compact
      (used.map { |p| Party.canonical_ballot_party(p) || p }.uniq & Party.ballot_vocabulary) - @existing_ballot_parties
    end

    def election_params
      params.require(:election).permit(:name, :date, :state, :election_type, :year, :registration_deadline, :early_voting_start, :early_voting_end)
    end
  end
end
