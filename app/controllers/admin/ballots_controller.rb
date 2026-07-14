module Admin
  class BallotsController < Admin::BaseController
    before_action :set_ballot, only: [:show, :edit, :update, :destroy]

    def index
      @ballots = Ballot.order(date: :desc).includes(:contests)

      @ballots = @ballots.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      @ballots = @ballots.for_year(params[:year]) if params[:year].present?
      @ballots = @ballots.for_state(params[:state]) if params[:state].present?
      @ballots = @ballots.for_party(params[:party]) if params[:party].present?

      @ballots = @ballots.page(params[:page]).per(50)
      # [name, abbreviation] so the option label reads "Colorado" but the value
      # submitted is the "CO" abbreviation actually stored on ballots.state.
      @states = State.order(:name).pluck(:name, :abbreviation)
      @years = Ballot.distinct.pluck(:year).compact.sort.reverse
      @parties = Ballot.distinct.where.not(party: [nil, '']).pluck(:party).sort
    end

    def show
      @contests = @ballot.contests.includes(office: :district).order(:id)
    end

    def new
      @ballot = Ballot.new(election_id: params[:election_id])
      @ballot.assign_attributes(prefill_from_election) if @ballot.election
      load_form_collections
    end

    def create
      @ballot = Ballot.new(ballot_params)
      if @ballot.save
        redirect_to admin_ballot_path(@ballot), notice: "Ballot created."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      if @ballot.update(ballot_params)
        redirect_to admin_ballot_path(@ballot), notice: "Ballot updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @ballot.destroy
      redirect_to admin_ballots_path, notice: "Ballot deleted."
    end

    private

    def set_ballot
      @ballot = Ballot.find(params[:id])
    end

    def load_form_collections
      @party_options = Party.ballot_vocabulary
      @elections = Election.order(date: :desc)
    end

    # When creating a ballot from an election, seed its state/date/type/year so
    # the ballot lands on that election (matching the find-or-create keys).
    def prefill_from_election
      e = @ballot.election
      { state: e.state, date: e.date, election_type: e.election_type, year: e.year }
    end

    def ballot_params
      params.require(:ballot).permit(:name, :date, :state, :election_type, :party, :year, :election_id)
    end
  end
end
