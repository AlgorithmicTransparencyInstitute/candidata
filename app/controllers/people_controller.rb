# frozen_string_literal: true

class PeopleController < ApplicationController
  
  def index
    @people = Person.includes(:person_parties, :parties, :party_affiliation, :officeholders, :offices)
    
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
    
    # Filter by office (category or title)
    if params[:office_title].present?
      # For statewide offices, filter by office_category; for others, use title
      @people = @people.joins(:offices).where(offices: { office_category: params[:office_title] }).or(
        @people.joins(:offices).where(offices: { title: params[:office_title] })
      ).distinct
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
    @offices_by_category = grouped_offices_for_filter
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

  private

  def grouped_offices_for_filter
    # Get distinct office data that have current officeholders
    all_offices = Office.joins(:officeholders)
                        .merge(Officeholder.current)
                        .distinct
                        .pluck(:title, :office_category, :level, :branch)
                        .uniq

    {
      'Federal' => all_offices.select { |_, _, level, _| level == 'federal' }
                               .map(&:first)
                               .uniq
                               .sort,
      'Statewide Executive' => all_offices.select { |_, category, level, branch|
                                             level == 'state' &&
                                             branch == 'executive' &&
                                             category.present?
                                           }
                                           .map { |_, category, _, _| category }
                                           .uniq
                                           .sort,
      'Statewide Judicial' => all_offices.select { |_, category, level, branch|
                                            level == 'state' &&
                                            branch == 'judicial' &&
                                            category.present?
                                          }
                                          .map { |_, category, _, _| category }
                                          .uniq
                                          .sort,
      'State Legislative' => all_offices.select { |_, _, level, branch|
                                           level == 'state' &&
                                           branch == 'legislative'
                                         }
                                         .map(&:first)
                                         .uniq
                                         .sort,
      'Local' => all_offices.select { |_, _, level, _| level == 'local' }
                            .map(&:first)
                            .uniq
                            .sort
                            .take(50) # Limit local offices to avoid huge list
    }.reject { |_, offices| offices.empty? }
  end
end
