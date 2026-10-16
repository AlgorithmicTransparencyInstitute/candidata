# frozen_string_literal: true

class PeopleController < PublicController
  
  def index
    # Eager load associations to avoid N+1 queries:
    # - person_parties with party (for primary_party display)
    # - current officeholders with their offices (for current office display)
    @people = Person.includes(
      person_parties: :party,
      party_affiliation: [],
      officeholders: :office
    )
    
    # Search by name
    if params[:q].present?
      @people = @people.name_matching(params[:q])
    end
    
    # Filter by state
    if params[:state].present?
      @people = @people.where(state_of_residence: params[:state])
    end
    
    # Filters are id subqueries rather than joins, so no DISTINCT is needed
    # (DISTINCT can't be combined with the search's relevance ordering).
    current_offices = Officeholder.current.joins(:office)

    if params[:party_id].present?
      @people = @people.where(id: PersonParty.where(party_id: params[:party_id]).select(:person_id))
    end

    # Level / branch / office filter on CURRENT offices
    if params[:level].present?
      @people = @people.where(id: current_offices.where(offices: { level: params[:level] }).select(:person_id))
    end

    if params[:branch].present?
      @people = @people.where(id: current_offices.where(offices: { branch: params[:branch] }).select(:person_id))
    end

    # Statewide offices filter by office_category, others by title
    if params[:office_title].present?
      @people = @people.where(id: current_offices.where('offices.office_category = :t OR offices.title = :t',
                                                        t: params[:office_title]).select(:person_id))
    end

    if params[:current] == '1'
      @people = @people.where(id: Officeholder.current.select(:person_id))
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

    @people = @people.page(params[:page]).per(50)

    # Data for filters
    @states = Person.where.not(state_of_residence: [nil, '']).distinct.pluck(:state_of_residence).compact.sort
    @parties = Party.joins(:people).distinct.order(:name)
    @levels = Office::LEVELS
    @branches = Office::BRANCHES
    @offices_by_category = grouped_offices_for_filter
  end
  
  def show
    @person = Person.includes(
      :social_media_accounts,
      person_parties: :party,
      officeholders: { office: [:district, :body] },
      candidates: { contest: [{ ballot: :election }, { office: :district }] }
    ).find(params[:id])

    # One canonical URL per person (/people/1234-jim-himes); old numeric links
    # and renamed slugs redirect permanently.
    return redirect_to(person_path(@person), status: :moved_permanently) if params[:id] != @person.to_param

    @accounts = @person.social_media_accounts.select(&:publicly_listed?)
                       .sort_by { |a| [SocialMediaAccount::PLATFORMS.index(a.platform) || 99, a.channel_type.to_s] }
    @current_offices = @person.officeholders.select { |oh| oh.end_date.nil? || oh.end_date >= Date.current }
                              .sort_by { |oh| oh.start_date || Date.new(1900) }.reverse
    @past_offices = (@person.officeholders.to_a - @current_offices).sort_by { |oh| oh.end_date || Date.new(1900) }.reverse
    @candidacies = @person.candidates.sort_by { |c| [c.contest.date || Date.new(1900), c.contest.contest_type == 'general' ? 1 : 0] }.reverse
    @parties = @person.person_parties.sort_by { |pp| pp.is_primary ? 0 : 1 }
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
