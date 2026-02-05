module Admin
  class BallotsController < Admin::BaseController
    before_action :set_ballot, only: [:show, :edit, :update, :destroy]

    def index
      @ballots = Ballot.order(date: :desc)

      if params[:q].present?
        @ballots = @ballots.where("name ILIKE ?", "%#{params[:q]}%")
      end

      if params[:year].present?
        @ballots = @ballots.where("EXTRACT(YEAR FROM date) = ?", params[:year])
      end

      if params[:state].present?
        @ballots = @ballots.where(state: params[:state])
      end

      @ballots = @ballots.page(params[:page]).per(50)
      @states = State.order(:name).pluck(:abbreviation, :name)
      @years = Ballot.distinct.pluck(Arel.sql("EXTRACT(YEAR FROM date)")).compact.sort.reverse
    end

    def show
      @contests = @ballot.contests.includes(:office).order(:id)
    end

    def new
      @ballot = Ballot.new
    end

    def create
      @ballot = Ballot.new(ballot_params)
      if @ballot.save
        redirect_to admin_ballot_path(@ballot), notice: "Ballot created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @ballot.update(ballot_params)
        redirect_to admin_ballot_path(@ballot), notice: "Ballot updated."
      else
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

    def ballot_params
      params.require(:ballot).permit(:name, :date, :state, :election_type)
    end
  end
end
