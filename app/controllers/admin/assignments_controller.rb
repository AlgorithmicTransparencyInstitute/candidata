module Admin
  class AssignmentsController < Admin::BaseController
    before_action :set_assignment, only: [:show, :edit, :update, :destroy, :complete, :mark_incomplete]

    def index
      @assignments = Assignment.includes(:user, :assigned_by, person: [
        :party_affiliation,
        { person_parties: :party },
        :social_media_accounts,
        { officeholders: :office },
        { candidates: { contest: [:office, :ballot] } }
      ]).order(created_at: :desc)

      if params[:status].present?
        @assignments = @assignments.where(status: params[:status])
      end

      if params[:task_type].present?
        @assignments = @assignments.where(task_type: params[:task_type])
      end

      if params[:user_id].present?
        @assignments = @assignments.where(user_id: params[:user_id])
      end

      @assignments = @assignments.page(params[:page]).per(50)
      @users = User.researchers.order(:name)
    end

    def show
      @person = @assignment.person
      @accounts = @person.social_media_accounts.order(:platform)
    end

    def new
      @researchers = User.researchers.order(:name)
      @researcher_workloads = Assignment.where(user_id: @researchers.pluck(:id))
                                        .active
                                        .group(:user_id)
                                        .count

      @task_type = params[:task_type] || 'data_collection'
      @selected_researcher_id = params[:user_id]

      @people = Person.includes(:parties, :assignments, :social_media_accounts,
                                officeholders: :office,
                                candidates: { contest: :office })
                      .order(:last_name, :first_name)

      if params[:state].present?
        @people = @people.by_state(params[:state])
      end

      if params[:party_id].present?
        @people = @people.by_party(params[:party_id])
      end

      if params[:body_id].present?
        # Find people who are EITHER officeholders OR candidates in this body
        officeholder_ids = Person.joins(officeholders: { office: :body })
                                 .where(bodies: { id: params[:body_id] })
                                 .distinct
                                 .pluck(:id)

        candidate_ids = Person.joins(candidates: { contest: { office: :body } })
                              .where(bodies: { id: params[:body_id] })
                              .distinct
                              .pluck(:id)

        combined_ids = (officeholder_ids + candidate_ids).uniq
        @people = @people.where(id: combined_ids)
      end

      # Role filter: current officeholders vs candidates
      case params[:role_filter]
      when 'officeholders'
        @people = @people.current_officeholders
      when 'candidates'
        @people = @people.joins(:candidates).distinct
      end

      if params[:level].present?
        @people = @people.joins(officeholders: :office).where(offices: { level: params[:level] }).distinct
      end

      if params[:q].present?
        search_term = "%#{params[:q].downcase}%"
        @people = @people.where("LOWER(first_name) LIKE :term OR LOWER(last_name) LIKE :term", term: search_term)
      end

      # 2026 candidate filters
      if params[:year].present?
        @people = @people.candidates_in_year(params[:year].to_i)
      end

      if params[:ballot_id].present?
        @people = @people.joins(candidates: { contest: :ballot })
                         .where(ballots: { id: params[:ballot_id] })
                         .distinct
      end

      if params[:contest_id].present?
        @people = @people.joins(candidates: :contest)
                         .where(contests: { id: params[:contest_id] })
                         .distinct
      end

      case params[:assignment_filter]
      when 'unassigned'
        @people = @people.left_joins(:assignments)
                         .where(assignments: { id: nil })
                         .distinct
      when 'no_collection'
        assigned_ids = Assignment.where(task_type: 'data_collection').select(:person_id)
        @people = @people.where.not(id: assigned_ids)
      when 'no_validation'
        assigned_ids = Assignment.where(task_type: 'data_validation').select(:person_id)
        @people = @people.where.not(id: assigned_ids)
      when 'no_secondary_verification'
        assigned_ids = Assignment.where(task_type: 'secondary_verification').select(:person_id)
        @people = @people.where.not(id: assigned_ids)
      when 'has_collection'
        assigned_ids = Assignment.where(task_type: 'data_collection').select(:person_id)
        @people = @people.where(id: assigned_ids)
      when 'has_validation'
        assigned_ids = Assignment.where(task_type: 'data_validation').select(:person_id)
        @people = @people.where(id: assigned_ids)
      when 'has_secondary_verification'
        assigned_ids = Assignment.where(task_type: 'secondary_verification').select(:person_id)
        @people = @people.where(id: assigned_ids)
      when 'needs_secondary_verification'
        @people = @people.needs_secondary_verification
      end

      @people = @people.page(params[:page]).per(50)

      @states = Person.where.not(state_of_residence: [nil, '']).distinct.pluck(:state_of_residence).sort
      # Sort parties with Republican and Democratic first
      @parties = Party.all.sort_by do |party|
        case party.name
        when 'Republican' then [0, party.name]
        when 'Democratic' then [1, party.name]
        else [2, party.name]
        end
      end
      # Sort bodies with US House and US Senate first
      @bodies = ::Body.all.sort_by do |body|
        case body.name
        when 'U.S. House of Representatives' then [0, body.name]
        when 'U.S. Senate' then [1, body.name]
        else [2, body.name]
        end
      end
      @levels = Office.where.not(level: [nil, '']).distinct.pluck(:level).sort
      @years = Contest.where.not(date: nil).distinct.pluck(Arel.sql('EXTRACT(YEAR FROM date)::integer')).sort.reverse
      @ballots = Ballot.where(year: params[:year] || 2026).order(:state, :party)
      @contests = if params[:ballot_id].present?
                    Contest.where(ballot_id: params[:ballot_id]).includes(:office).order(Arel.sql('offices.title'), :party)
                  else
                    []
                  end

      respond_to do |format|
        format.html
        format.json do
          render json: {
            ballots: @ballots.map { |b| { id: b.id, full_name: b.full_name } },
            contests: @contests.map { |c| { id: c.id, full_name: c.full_name } }
          }
        end
      end
    end

    def create
      user = User.find(params[:user_id])
      task_type = params[:task_type] || 'data_collection'
      person_ids = params[:person_ids] || []

      if person_ids.empty?
        redirect_to new_admin_assignment_path, alert: "Please select at least one person."
        return
      end

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

      # Track assignment creation
      track_event('Assignments Created', {
        count: created,
        skipped: skipped,
        task_type: task_type,
        assigned_to_user_id: user.id
      })

      redirect_to admin_assignments_path, notice: "Created #{created} assignments#{skipped > 0 ? ", skipped #{skipped} (already assigned)" : ''}."
    end

    def edit
      @researchers = User.researchers.order(:name)
    end

    def update
      if @assignment.update(assignment_params)
        redirect_to admin_assignment_path(@assignment), notice: "Assignment updated."
      else
        @researchers = User.researchers.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @assignment.destroy
      redirect_to admin_assignments_path, notice: "Assignment deleted."
    end

    def complete
      @assignment.complete!
      redirect_to admin_assignments_path, notice: "Assignment marked complete."
    end

    def mark_incomplete
      @assignment.update!(status: 'pending', completed_at: nil)
      redirect_back fallback_location: admin_assignments_path, notice: "Assignment marked as incomplete."
    end

    private

    def set_assignment
      @assignment = Assignment.find(params[:id])
    end

    def assignment_params
      params.require(:assignment).permit(:user_id, :person_id, :task_type, :status, :notes)
    end

  end
end
