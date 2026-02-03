# frozen_string_literal: true

class PartiesController < ApplicationController
  
  def index
    @parties = Party.left_joins(:people)
                    .select('parties.*, COUNT(DISTINCT people.id) as people_count')
                    .group('parties.id')
    
    # Search by name
    if params[:q].present?
      search_term = "%#{params[:q].downcase}%"
      @parties = @parties.where("LOWER(name) LIKE :term OR LOWER(abbreviation) LIKE :term", term: search_term)
    end
    
    # Filter by ideology
    if params[:ideology].present?
      @parties = @parties.where(ideology: params[:ideology])
    end
    
    # Sort
    @parties = case params[:sort]
               when 'name_desc'
                 @parties.order(name: :desc)
               when 'members'
                 @parties.order('people_count DESC')
               when 'members_asc'
                 @parties.order('people_count ASC')
               else
                 @parties.order(:name)
               end
    
    @parties = @parties.page(params[:page]).per(50)
    
    @ideologies = Party.where.not(ideology: [nil, '']).distinct.pluck(:ideology).compact.sort
  end
  
  def show
    @party = Party.find(params[:id])
    @members = @party.people.includes(:officeholders, :offices)
                     .order(:last_name, :first_name)
                     .page(params[:page]).per(50)
    @current_officeholders_count = @party.people.current_officeholders.count
    @total_members = @party.people.count
    
    # State breakdown
    @by_state = @party.people
                      .where.not(state_of_residence: [nil, ''])
                      .group(:state_of_residence)
                      .count
                      .sort_by { |_, v| -v }
  end
end
