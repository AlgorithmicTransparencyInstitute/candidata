module Admin
  class ElectionsController < Admin::BaseController
    before_action :set_election, only: [:show, :edit, :update, :destroy]

    def index
      @elections = Election.order(date: :asc)

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
      @states = State.order(:name).pluck(:abbreviation, :name)
      @years = Election.distinct.pluck(:year).compact.sort.reverse
    end

    def show
      @ballots = @election.ballots.includes(:contests).order(:party, :date)
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

    def election_params
      params.require(:election).permit(:name, :date, :state, :election_type, :year, :registration_deadline, :early_voting_start, :early_voting_end)
    end
  end
end
