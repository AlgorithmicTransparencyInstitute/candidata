class Admin::PartiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_party, only: [:show, :edit, :update, :destroy]

  def index
    @parties = Party.order(:name)
  end

  def new
    @party = Party.new
  end

  def create
    @party = Party.new(party_params)
    
    if @party.save
      redirect_to admin_parties_path, notice: 'Party was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @party.update(party_params)
      redirect_to admin_parties_path, notice: 'Party was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @party.destroy
    redirect_to admin_parties_path, notice: 'Party was successfully deleted.'
  end

  private

  def set_party
    @party = Party.find(params[:id])
  end

  def party_params
    params.require(:party).permit(:name, :abbreviation, :ideology)
  end

end
