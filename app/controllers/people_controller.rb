# frozen_string_literal: true

class PeopleController < ApplicationController
  
  def index
    @people = Person.includes(:parties, :officeholders, :offices)
    
    # Search by name
    if params[:q].present?
      search_term = "%#{params[:q].downcase}%"
      @people = @people.where(
        "LOWER(first_name) LIKE :term OR LOWER(last_name) LIKE :term OR LOWER(CONCAT(first_name, ' ', last_name)) LIKE :term",
        term: search_term
      )
    end
    
    # Filter by state
    if params[:state].present?
      @people = @people.where(state_of_residence: params[:state])
    end
    
    # Filter by party
    if params[:party_id].present?
      @people = @people.joins(:parties).where(parties: { id: params[:party_id] })
    end
    
    # Filter by level (via current office)
    if params[:level].present?
      @people = @people.joins(:offices).where(offices: { level: params[:level] }).distinct
    end
    
    # Filter by branch (via current office)
    if params[:branch].present?
      @people = @people.joins(:offices).where(offices: { branch: params[:branch] }).distinct
    end
    
    # Filter by current officeholders only
    if params[:current] == '1'
      @people = @people.current_officeholders
    end
    
    # Sort
    @people = case params[:sort]
              when 'name_desc'
                @people.order(last_name: :desc, first_name: :desc)
              when 'state'
                @people.order(:state_of_residence, :last_name, :first_name)
              else
                @people.order(:last_name, :first_name)
              end
    
    @people = @people.distinct.page(params[:page]).per(50)
    
    # Data for filters
    @states = Person.where.not(state_of_residence: [nil, '']).distinct.pluck(:state_of_residence).compact.sort
    @parties = Party.joins(:people).distinct.order(:name)
    @levels = Office::LEVELS
    @branches = Office::BRANCHES
  end
  
  def show
    @person = Person.includes(
      :parties, 
      :social_media_accounts,
      officeholders: { office: :district },
      candidates: { contest: [:ballot, :office] }
    ).find(params[:id])
    
    @current_offices = @person.officeholders.current.includes(office: :district)
    @past_offices = @person.officeholders.former.includes(office: :district).order(end_date: :desc)
    @candidacies = @person.candidates.includes(contest: [:ballot, :office]).order('contests.date DESC')
  end
end
