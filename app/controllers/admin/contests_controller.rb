module Admin
  class ContestsController < Admin::BaseController
    before_action :set_contest, only: [:show, :edit, :update, :destroy]

    def index
      # includes + references => LEFT JOINs, so we can filter on the joined
      # offices/districts/ballots tables without duplicate-join errors.
      @contests = Contest.includes(:candidates, office: :district, ballot: :election).order('contests.date DESC')

      if params[:q].present?
        @contests = @contests.where('offices.title ILIKE :p OR offices.seat ILIKE :p', p: "%#{params[:q]}%").references(:offices)
      end
      @contests = @contests.where(contest_type: params[:contest_type]) if params[:contest_type].present?
      @contests = @contests.where(party: params[:party]) if params[:party].present?
      @contests = @contests.where('EXTRACT(YEAR FROM contests.date) = ?', params[:year]) if params[:year].present?
      if params[:state].present?
        @contests = @contests.where(ballots: { state: params[:state] }).references(:ballots)
      end
      if params[:district_number].present?
        @contests = @contests.where(districts: { district_number: params[:district_number] }).references(:districts)
      end

      @contests = @contests.page(params[:page]).per(50)
      @contest_types = Contest::CONTEST_TYPES
      @years = Contest.distinct.pluck(Arel.sql('EXTRACT(YEAR FROM date)')).compact.map(&:to_i).sort.reverse
      @parties = Contest.where.not(party: [nil, '']).distinct.order(:party).pluck(:party)
      @states = State.order(:name).pluck(:name, :abbreviation)
    end

    def show
      @candidates = @contest.candidates.includes(:person).order(tally: :desc, created_at: :asc)
    end

    def new
      @contest = Contest.new
      load_form_collections
    end

    def create
      @contest = Contest.new(contest_params)
      if @contest.save
        redirect_to admin_contest_path(@contest), notice: "Contest created."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_collections
    end

    def update
      if @contest.update(contest_params)
        redirect_to admin_contest_path(@contest), notice: "Contest updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @contest.destroy
      redirect_to admin_contests_path, notice: "Contest deleted."
    end

    private

    def set_contest
      @contest = Contest.find(params[:id])
    end

    # Office is chosen via the search-as-you-type picker (see office_search
    # Stimulus controller + /admin/offices/search), so no office collection is
    # pre-loaded. Ballots (~100s) and the party vocabulary are small enough to
    # embed directly.
    def load_form_collections
      @ballots = Ballot.includes(:election).order(date: :desc)
      @party_options = Party.ballot_vocabulary
    end

    def contest_params
      params.require(:contest).permit(:office_id, :ballot_id, :date, :contest_type, :party, :location)
    end
  end
end
