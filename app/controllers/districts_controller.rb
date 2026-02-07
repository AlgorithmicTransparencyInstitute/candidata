# frozen_string_literal: true

class DistrictsController < ApplicationController
  
  def index
    @districts = District.includes(:offices)
    
    # Search
    if params[:q].present?
      search_term = "%#{params[:q].downcase}%"
      @districts = @districts.where("LOWER(state) LIKE :term OR CAST(district_number AS TEXT) LIKE :term", term: search_term)
    end
    
    # Filter by state
    if params[:state].present?
      @districts = @districts.where(state: params[:state])
    end
    
    # Filter by level
    if params[:level].present?
      @districts = @districts.where(level: params[:level])
    end
    
    # Filter by chamber
    if params[:chamber].present?
      @districts = @districts.where(chamber: params[:chamber])
    end

    # Filter by district type
    if params[:district_type].present?
      case params[:district_type]
      when 'numbered'
        @districts = @districts.where('district_number > 0')
      when 'at_large_voting'
        # At-large voting states (6 states with 1 House member each)
        voting_states = %w[AK DE ND SD VT WY]
        @districts = @districts.where(level: 'federal', district_number: 0, state: voting_states)
      when 'at_large_territory'
        # At-large territories (6 non-voting delegates)
        territories = %w[AS DC GU MP PR VI]
        @districts = @districts.where(level: 'federal', district_number: 0, state: territories)
      end
    end

    # Sort
    @districts = case params[:sort]
                 when 'state'
                   @districts.order(:state, :level, :district_number)
                 when 'number'
                   @districts.order(:district_number, :state)
                 else
                   @districts.order(:state, :level, :chamber, :district_number)
                 end
    
    @districts = @districts.page(params[:page]).per(50)
    
    # Data for filters
    @states = District.distinct.pluck(:state).compact.sort
    @levels = District.distinct.pluck(:level).compact.sort
    @chambers = District.where.not(chamber: [nil, '']).distinct.pluck(:chamber).compact.sort
  end
  
  def show
    @district = District.includes(offices: { officeholders: :person }).find(params[:id])
    @offices = @district.offices.includes(officeholders: :person)
    @current_representatives = @district.offices.flat_map { |o| o.officeholders.current.includes(:person) }
  end
end
