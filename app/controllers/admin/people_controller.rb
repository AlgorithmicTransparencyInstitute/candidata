class Admin::PeopleController < Admin::BaseController
  before_action :set_person, only: [:show, :edit, :update, :destroy, :assign_researcher, :prepopulate_accounts]

  def index
    @people = Person.includes(:parties, :social_media_accounts)

    if params[:q].present?
      search_term = "%#{params[:q].downcase}%"
      @people = @people.where("LOWER(first_name) LIKE :term OR LOWER(last_name) LIKE :term", term: search_term)
    end

    if params[:needs_research].present?
      @people = @people.left_joins(:assignments)
                       .where(assignments: { id: nil })
                       .or(@people.left_joins(:assignments).where.not(assignments: { task_type: 'data_collection' }))
    end

    @people = @people.order(:last_name, :first_name).page(params[:page]).per(50)
    @researchers = User.researchers.order(:name)
  end

  def show
    @accounts = @person.social_media_accounts.order(:platform)
    @assignments = @person.assignments.includes(:user, :assigned_by).order(created_at: :desc)
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
    @people = Person.order(:last_name, :first_name)

    if params[:contest_id].present?
      contest = Contest.find(params[:contest_id])
      @people = Person.joins(:candidates).where(candidates: { contest_id: contest.id })
    elsif params[:state].present?
      @people = @people.by_state(params[:state])
    end

    @people = @people.page(params[:page]).per(100)
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
    params.require(:person).permit(:first_name, :middle_name, :last_name, :suffix, :gender,
                                   :date_of_birth, :photo_url, :website_official, :website_campaign,
                                   :state_of_residence, :person_uuid)
  end

end
