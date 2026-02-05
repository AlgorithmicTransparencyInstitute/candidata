class BodiesController < ApplicationController
  def index
    @bodies = ::Body.order(:name)

    # Search
    if params[:q].present?
      @bodies = @bodies.where('name ILIKE ?', "%#{params[:q]}%")
    end

    # Filter by level
    if params[:level].present?
      @bodies = @bodies.where(level: params[:level])
    end

    # Filter by state
    if params[:state].present?
      @bodies = @bodies.where(state: params[:state])
    end

    @bodies = @bodies.page(params[:page]).per(50)

    @states = State.order(:name).pluck(:abbreviation, :name)
    @levels = ::Body::LEVELS
  end

  def show
    @body = ::Body.find(params[:id])
    @offices = @body.offices
                    .includes(:district, officeholders: :person)
                    .order(:title, :seat)
                    .page(params[:page]).per(25)

    @current_holders = @body.current_officeholders.includes(:person, :office)
  end
end
