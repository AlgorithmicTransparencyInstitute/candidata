module Admin
  class ContestsController < Admin::BaseController
    before_action :set_contest, only: [:show, :edit, :update, :destroy]

    def index
      @contests = Contest.includes(:office, :ballot).order(date: :desc)

      if params[:q].present?
        @contests = @contests.joins(:office).where("offices.title ILIKE ?", "%#{params[:q]}%")
      end

      if params[:contest_type].present?
        @contests = @contests.where(contest_type: params[:contest_type])
      end

      if params[:year].present?
        @contests = @contests.where("EXTRACT(YEAR FROM date) = ?", params[:year])
      end

      @contests = @contests.page(params[:page]).per(50)
      @contest_types = Contest::CONTEST_TYPES rescue ['general', 'primary', 'runoff', 'special']
      @years = Contest.distinct.pluck(Arel.sql("EXTRACT(YEAR FROM date)")).compact.sort.reverse
    end

    def show
      @candidates = @contest.candidates.includes(:person).order(tally: :desc, created_at: :asc)
    end

    def new
      @contest = Contest.new
      @offices = Office.order(:title).limit(100)
      @ballots = Ballot.order(date: :desc).limit(50)
    end

    def create
      @contest = Contest.new(contest_params)
      if @contest.save
        redirect_to admin_contest_path(@contest), notice: "Contest created."
      else
        @offices = Office.order(:title).limit(100)
        @ballots = Ballot.order(date: :desc).limit(50)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @offices = Office.order(:title).limit(100)
      @ballots = Ballot.order(date: :desc).limit(50)
    end

    def update
      if @contest.update(contest_params)
        redirect_to admin_contest_path(@contest), notice: "Contest updated."
      else
        @offices = Office.order(:title).limit(100)
        @ballots = Ballot.order(date: :desc).limit(50)
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

    def contest_params
      params.require(:contest).permit(:office_id, :ballot_id, :date, :contest_type, :party, :location)
    end
  end
end
