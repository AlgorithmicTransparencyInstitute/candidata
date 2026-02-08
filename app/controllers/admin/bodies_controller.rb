class Admin::BodiesController < Admin::BaseController
  before_action :set_body, only: [:show, :edit, :update, :destroy]

  def index
    @bodies = Body.all

    # Filters
    @bodies = @bodies.where(level: params[:level]) if params[:level].present?
    @bodies = @bodies.where(state: params[:state]) if params[:state].present?
    @bodies = @bodies.where(branch: params[:branch]) if params[:branch].present?
    @bodies = @bodies.where(chamber_type: params[:chamber_type]) if params[:chamber_type].present?

    @bodies = @bodies.order(:country, :state, :name).page(params[:page]).per(50)
  end

  def show
    @offices = @body.offices.order(:title).page(params[:page]).per(20)
    @sub_bodies = @body.sub_bodies
  end

  def new
    @body = Body.new
  end

  def create
    @body = Body.new(body_params)

    if @body.save
      redirect_to admin_bodies_path, notice: 'Body was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @body.update(body_params)
      redirect_to admin_body_path(@body), notice: 'Body was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @body.destroy
    redirect_to admin_bodies_path, notice: 'Body was successfully deleted.'
  end

  private

  def set_body
    @body = Body.find(params[:id])
  end

  def body_params
    params.require(:body).permit(:name, :level, :branch, :chamber_type, :state, :country, :parent_body_id)
  end
end
