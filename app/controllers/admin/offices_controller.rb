module Admin
  class OfficesController < Admin::BaseController
    before_action :set_office, only: [:show, :edit, :update, :destroy]

    def index
      @offices = Office.includes(:district, :body).order(:title)

      if params[:q].present?
        @offices = @offices.where("title ILIKE ?", "%#{params[:q]}%")
      end

      if params[:level].present?
        @offices = @offices.where(level: params[:level])
      end

      if params[:state].present?
        @offices = @offices.where(state: params[:state])
      end

      @offices = @offices.page(params[:page]).per(50)
      @states = State.order(:name).pluck(:abbreviation, :name)
      @levels = Office::LEVELS
    end

    def show
      @officeholders = @office.officeholders.includes(:person).order(start_date: :desc)
      @contests = @office.contests.includes(:ballot).order(date: :desc).limit(10)
    end

    def new
      @office = Office.new
    end

    def create
      @office = Office.new(office_params)
      if @office.save
        redirect_to admin_office_path(@office), notice: "Office created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @office.update(office_params)
        redirect_to admin_office_path(@office), notice: "Office updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @office.destroy
      redirect_to admin_offices_path, notice: "Office deleted."
    end

    private

    def set_office
      @office = Office.find(params[:id])
    end

    def office_params
      params.require(:office).permit(:title, :level, :state, :district_id, :body_id, :seat,
                                     :term_length, :filing_deadline, :next_election_date)
    end
  end
end
