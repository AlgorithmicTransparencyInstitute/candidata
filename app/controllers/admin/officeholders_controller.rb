class Admin::OfficeholdersController < Admin::BaseController
  before_action :set_officeholder, only: [:show, :edit, :update, :destroy]

  def index
    @officeholders = Officeholder.includes(:person, :office).order(start_date: :desc).page(params[:page]).per(50)
  end

  def show
  end

  def edit
  end

  def update
    if @officeholder.update(officeholder_params)
      redirect_to admin_person_path(@officeholder.person), notice: "Officeholder updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @officeholder.destroy
    redirect_to admin_officeholders_path, notice: "Officeholder deleted."
  end

  private

  def set_officeholder
    @officeholder = Officeholder.find(params[:id])
  end

  def officeholder_params
    params.require(:officeholder).permit(:person_id, :office_id, :start_date, :end_date,
                                        :elected_year, :appointed, :term_end_date, :next_election_date,
                                        :official_email, :official_phone, :official_address, :contact_form_url)
  end
end
