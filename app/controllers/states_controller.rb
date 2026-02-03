# frozen_string_literal: true

class StatesController < ApplicationController
  
  def index
    @states = State.all
    
    # Search by name
    if params[:q].present?
      search_term = "%#{params[:q].downcase}%"
      @states = @states.where("LOWER(name) LIKE :term OR LOWER(abbreviation) LIKE :term", term: search_term)
    end
    
    # Filter by type
    if params[:type].present?
      @states = @states.where(state_type: params[:type])
    end
    
    # Sort
    @states = case params[:sort]
              when 'abbreviation'
                @states.order(:abbreviation)
              else
                @states.order(:name)
              end
    
    @state_types = State.distinct.pluck(:state_type).compact.sort
  end
  
  def show
    @state = State.find_by!(abbreviation: params[:id].upcase)
    
    # Politicians from this state
    @people = Person.where(state_of_residence: @state.abbreviation)
                    .includes(:parties, :officeholders)
                    .order(:last_name, :first_name)
                    .page(params[:page]).per(50)
    
    @people_count = Person.where(state_of_residence: @state.abbreviation).count
    @current_officeholders_count = Person.where(state_of_residence: @state.abbreviation).current_officeholders.count
    
    # Offices in this state
    @offices_count = Office.where(state: @state.abbreviation).count
    @offices_by_level = Office.where(state: @state.abbreviation).group(:level).count
    @offices_by_branch = Office.where(state: @state.abbreviation).group(:branch).count
    
    # Districts
    @districts_count = District.where(state: @state.abbreviation).count
    @districts_by_level = District.where(state: @state.abbreviation).group(:level).count
    
    # Party breakdown
    @party_breakdown = Person.where(state_of_residence: @state.abbreviation)
                             .joins(:parties)
                             .group('parties.name')
                             .count
                             .sort_by { |_, v| -v }
  end
end
