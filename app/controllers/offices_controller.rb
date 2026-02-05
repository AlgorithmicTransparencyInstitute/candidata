# frozen_string_literal: true

class OfficesController < ApplicationController
  
  def index
    @offices = Office.includes(:district, :officeholders, :body)
    
    # Search by title
    if params[:q].present?
      search_term = "%#{params[:q].downcase}%"
      @offices = @offices.left_joins(:body).where("LOWER(offices.title) LIKE :term OR LOWER(bodies.name) LIKE :term", term: search_term)
    end
    
    # Filter by state
    if params[:state].present?
      @offices = @offices.where(state: params[:state])
    end
    
    # Filter by level
    if params[:level].present?
      @offices = @offices.where(level: params[:level])
    end
    
    # Filter by branch
    if params[:branch].present?
      @offices = @offices.where(branch: params[:branch])
    end
    
    # Filter by category
    if params[:category].present?
      @offices = @offices.where(office_category: params[:category])
    end
    
    # Filter by body
    if params[:body].present?
      @offices = @offices.where(body_id: params[:body])
    end
    
    # Sort
    @offices = case params[:sort]
               when 'title_desc'
                 @offices.order(title: :desc)
               when 'state'
                 @offices.order(:state, :title)
               when 'level'
                 @offices.order(:level, :state, :title)
               else
                 @offices.order(:title)
               end
    
    @offices = @offices.page(params[:page]).per(50)
    
    # Data for filters
    @states = Office.where.not(state: [nil, '']).distinct.pluck(:state).compact.sort
    @levels = Office::LEVELS
    @branches = Office::BRANCHES
    @categories = Office.where.not(office_category: [nil, '']).distinct.pluck(:office_category).compact.sort
    @bodies = ::Body.order(:name).pluck(:id, :name)
  end
  
  def show
    @office = Office.includes(:district, :body, officeholders: :person).find(params[:id])
    @current_holder = @office.officeholders.current.includes(:person).first
    @past_holders = @office.officeholders.former.includes(:person).order(end_date: :desc).limit(20)
  end
end
