class Admin::DistrictsController < Admin::BaseController
  before_action :set_district, only: [:show, :edit, :update, :destroy]

  def index
    @districts = District.all

    # Filters
    @districts = @districts.where(level: params[:level]) if params[:level].present?
    @districts = @districts.where(state: params[:state]) if params[:state].present?
    @districts = @districts.where(chamber: params[:chamber]) if params[:chamber].present?

    @districts = @districts.order(:state, :level, :district_number).page(params[:page]).per(50)
  end

  def show
    @offices = @district.offices.order(:title).page(params[:page]).per(20)
  end

  def new
    @district = District.new
  end

  def create
    @district = District.new(district_params)

    if @district.save
      redirect_to admin_districts_path, notice: 'District was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @district.update(district_params)
      redirect_to admin_district_path(@district), notice: 'District was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @district.destroy
    redirect_to admin_districts_path, notice: 'District was successfully deleted.'
  end

  private

  def set_district
    @district = District.find(params[:id])
  end

  def district_params
    params.require(:district).permit(:state, :level, :chamber, :district_number, :ocdid)
  end
end
