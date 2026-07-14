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
      # [name, abbreviation] so the option value submitted matches offices.state.
      @states = State.order(:name).pluck(:name, :abbreviation)
      @levels = Office::LEVELS
    end

    # JSON typeahead backing the searchable office pickers (core contest form and,
    # via the editor's own endpoint, the election editor). Searches the whole
    # office table; optional state/level/branch narrowing.
    def search
      q = params[:q].to_s.strip
      return render json: { offices: [] } if q.length < 2

      offices = Office.search_text(q)
      offices = offices.where(state: params[:state]) if params[:state].present?
      offices = offices.where(level: params[:level]) if params[:level].present?
      offices = offices.where(branch: params[:branch]) if params[:branch].present?
      offices = offices.order(:state, :title, :seat).limit(25)

      render json: {
        offices: offices.map { |o|
          {
            id: o.id, label: o.search_label, title: o.title, seat: o.seat,
            state: o.state, body: o.body_name, category: o.office_category,
            level: o.level, branch: o.branch
          }
        }
      }
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
