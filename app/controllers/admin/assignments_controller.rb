module Admin
  class AssignmentsController < Admin::BaseController
    before_action :set_assignment, only: [:show, :edit, :update, :destroy, :complete]

    def index
      @assignments = Assignment.includes(:user, :assigned_by, :person).order(created_at: :desc)

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
      @assignment = Assignment.new
      @assignment.person_id = params[:person_id] if params[:person_id]
      @researchers = User.researchers.order(:name)
      @people = Person.order(:last_name, :first_name).limit(100)
    end

    def create
      @assignment = Assignment.new(assignment_params)
      @assignment.assigned_by = current_user

      if @assignment.save
        redirect_to admin_assignments_path, notice: "Assignment created."
      else
        @researchers = User.researchers.order(:name)
        @people = Person.order(:last_name, :first_name).limit(100)
        render :new, status: :unprocessable_entity
      end
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

    private

    def set_assignment
      @assignment = Assignment.find(params[:id])
    end

    def assignment_params
      params.require(:assignment).permit(:user_id, :person_id, :task_type, :status, :notes)
    end

  end
end
