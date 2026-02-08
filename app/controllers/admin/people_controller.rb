class Admin::PeopleController < Admin::BaseController
  before_action :set_person, only: [:show, :edit, :update, :destroy, :assign_researcher, :prepopulate_accounts]

  def index
    @people = Person.includes(:parties, :social_media_accounts, :officeholders, :person_parties)

    # Text search
    if params[:q].present?
      search_term = "%#{params[:q].downcase}%"
      @people = @people.where("LOWER(first_name) LIKE :term OR LOWER(last_name) LIKE :term", term: search_term)
    end

    # State filter
    if params[:state].present?
      @people = @people.where(state_of_residence: params[:state])
    end

    # Party filter
    if params[:party_id].present?
      @people = @people.joins(:person_parties).where(person_parties: { party_id: params[:party_id] })
    end

    # Office filter (current officeholders only)
    if params[:office_level].present?
      @people = @people.joins(officeholders: :office)
                       .where('officeholders.end_date IS NULL OR officeholders.end_date >= ?', Date.current)
                       .where(offices: { level: params[:office_level] })
                       .distinct
    end

    # Research status filter
    if params[:research_status].present?
      @people = @people.joins(:social_media_accounts)
                       .where(social_media_accounts: { research_status: params[:research_status] })
                       .distinct
    end

    # Assignment status filter
    case params[:assignment_status]
    when 'unassigned'
      @people = @people.left_joins(:assignments).where(assignments: { id: nil })
    when 'assigned'
      @people = @people.joins(:assignments).where(assignments: { status: %w[pending in_progress] }).distinct
    when 'completed'
      @people = @people.joins(:assignments).where(assignments: { status: 'completed' }).distinct
    end

    # Account status filter
    case params[:account_status]
    when 'has_accounts'
      @people = @people.joins(:social_media_accounts).distinct
    when 'no_accounts'
      @people = @people.left_joins(:social_media_accounts).where(social_media_accounts: { id: nil })
    end

    @people = @people.order(:last_name, :first_name).page(params[:page]).per(50)
    @researchers = User.researchers.order(:name)
    @states = State.order(:name)
    @parties = Party.order(:name)
  end

  def show
    @accounts = @person.social_media_accounts.order(:platform)
    @assignments = @person.assignments.includes(:user, :assigned_by).order(created_at: :desc)
    @officeholders = @person.officeholders.includes(:office).order(start_date: :desc)
    @candidates = @person.candidates.includes(contest: [:ballot, :office]).order('ballots.date DESC')
    @person_parties = @person.person_parties.includes(:party).order(created_at: :desc)
  end

  def new
    @person = Person.new
  end

  def create
    @person = Person.new(person_params)
    if @person.save
      redirect_to admin_person_path(@person), notice: "Person created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @person.update(person_params)
      redirect_to admin_person_path(@person), notice: "Person updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @person.destroy
    redirect_to admin_people_path, notice: "Person deleted."
  end

  def assign_researcher
    user = User.find(params[:user_id])
    task_type = params[:task_type] || 'data_collection'

    assignment = @person.assignments.find_or_initialize_by(user: user, task_type: task_type)
    assignment.assigned_by = current_user
    assignment.status = 'pending'

    if assignment.save
      SocialMediaAccount.prepopulate_for_person!(@person) if task_type == 'data_collection'
      redirect_to admin_person_path(@person), notice: "#{user.name} assigned to #{task_type} for #{@person.full_name}."
    else
      redirect_to admin_person_path(@person), alert: "Failed to assign: #{assignment.errors.full_messages.join(', ')}"
    end
  end

  def prepopulate_accounts
    SocialMediaAccount.prepopulate_for_person!(@person)
    redirect_to admin_person_path(@person), notice: "Accounts prepopulated for #{@person.full_name}."
  end

  def bulk_assign
    @researchers = User.researchers.order(:name)
    @states = State.order(:name)
    @parties = Party.order(:name)
    @people = Person.includes(:parties, :social_media_accounts, :officeholders, :person_parties)

    # Text search
    if params[:q].present?
      search_term = "%#{params[:q].downcase}%"
      @people = @people.where("LOWER(first_name) LIKE :term OR LOWER(last_name) LIKE :term", term: search_term)
    end

    # State filter
    if params[:state].present?
      @people = @people.where(state_of_residence: params[:state])
    end

    # Party filter
    if params[:party_id].present?
      @people = @people.joins(:person_parties).where(person_parties: { party_id: params[:party_id] })
    end

    # Office filter (current officeholders only)
    if params[:office_level].present?
      @people = @people.joins(officeholders: :office)
                       .where('officeholders.end_date IS NULL OR officeholders.end_date >= ?', Date.current)
                       .where(offices: { level: params[:office_level] })
                       .distinct
    end

    # Research status filter
    if params[:research_status].present?
      @people = @people.joins(:social_media_accounts)
                       .where(social_media_accounts: { research_status: params[:research_status] })
                       .distinct
    end

    # Assignment status filter
    case params[:assignment_status]
    when 'unassigned'
      @people = @people.left_joins(:assignments).where(assignments: { id: nil })
    when 'assigned'
      @people = @people.joins(:assignments).where(assignments: { status: %w[pending in_progress] }).distinct
    when 'completed'
      @people = @people.joins(:assignments).where(assignments: { status: 'completed' }).distinct
    end

    # Account status filter
    case params[:account_status]
    when 'has_accounts'
      @people = @people.joins(:social_media_accounts).distinct
    when 'no_accounts'
      @people = @people.left_joins(:social_media_accounts).where(social_media_accounts: { id: nil })
    end

    # Contest filter
    if params[:contest_id].present?
      @people = @people.joins(:candidates).where(candidates: { contest_id: params[:contest_id] })
    end

    @people = @people.order(:last_name, :first_name).page(params[:page]).per(100)
  end

  def create_bulk_assignments
    user = User.find(params[:user_id])
    task_type = params[:task_type] || 'data_collection'
    person_ids = params[:person_ids] || []

    created = 0
    skipped = 0

    person_ids.each do |pid|
      person = Person.find(pid)
      assignment = person.assignments.find_or_initialize_by(user: user, task_type: task_type)

      if assignment.new_record?
        assignment.assigned_by = current_user
        assignment.status = 'pending'
        if assignment.save
          SocialMediaAccount.prepopulate_for_person!(person) if task_type == 'data_collection'
          created += 1
        end
      else
        skipped += 1
      end
    end

    redirect_to admin_assignments_path, notice: "Created #{created} assignments, skipped #{skipped} (already assigned)."
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end

  def person_params
    params.require(:person).permit(:first_name, :middle_name, :last_name, :suffix, :gender, :race,
                                   :birth_date, :death_date, :photo_url, :website_official, :website_campaign,
                                   :website_personal, :wikipedia_id, :state_of_residence, :person_uuid)
  end

end
