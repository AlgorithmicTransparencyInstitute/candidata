class BodiesController < ApplicationController
  def index
    @bodies = Office.where.not(body_name: [nil, ''])
                    .group(:body_name)
                    .select('body_name, COUNT(*) as offices_count, MAX(level) as level, MAX(state) as state')
                    .order(:body_name)

    # Search
    if params[:q].present?
      @bodies = @bodies.where('body_name ILIKE ?', "%#{params[:q]}%")
    end

    # Filter by level
    if params[:level].present?
      @bodies = Office.where.not(body_name: [nil, ''])
                      .where(level: params[:level])
                      .group(:body_name)
                      .select('body_name, COUNT(*) as offices_count, MAX(level) as level, MAX(state) as state')
                      .order(:body_name)
      @bodies = @bodies.where('body_name ILIKE ?', "%#{params[:q]}%") if params[:q].present?
    end

    # Filter by state
    if params[:state].present?
      @bodies = Office.where.not(body_name: [nil, ''])
                      .where(state: params[:state])
                      .group(:body_name)
                      .select('body_name, COUNT(*) as offices_count, MAX(level) as level, MAX(state) as state')
                      .order(:body_name)
      @bodies = @bodies.where('body_name ILIKE ?', "%#{params[:q]}%") if params[:q].present?
      @bodies = @bodies.where(level: params[:level]) if params[:level].present?
    end

    @bodies = @bodies.page(params[:page]).per(50)

    @states = State.order(:name).pluck(:abbreviation, :name)
    @levels = Office::LEVELS
  end

  def show
    @body_name = params[:id]
    @offices = Office.where(body_name: @body_name)
                     .includes(:district, officeholders: :person)
                     .order(:title, :seat)
                     .page(params[:page]).per(25)

    if @offices.empty?
      redirect_to bodies_path, alert: "Body not found"
      return
    end

    @sample_office = @offices.first
    @total_offices = Office.where(body_name: @body_name).count
    @current_holders = Officeholder.current
                                   .joins(:office)
                                   .where(offices: { body_name: @body_name })
                                   .includes(:person, :office)
  end
end
