module Demographics
  class AssignmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_assignment, only: [:show, :update, :start, :complete, :reopen]
    before_action :load_reference_material, only: [:show, :update]

    def index
      @assignments = current_user.assignments.demographic_research.active
                                 .includes(person: :demographic_verifications)
                                 .order(created_at: :asc)
      @completed = current_user.assignments.demographic_research.completed
                               .includes(:person).order(completed_at: :desc).limit(10)
    end

    def show
      @assignment.start! if @assignment.pending?
    end

    # One submission saves every field at once — researchers work the whole
    # person in a pass, and a per-field save would multiply page reloads by
    # twelve.
    def update
      result = DemographicsReview.new(
        person: @person, user: current_user, assignment: @assignment
      ).save(values: values_params, evidence: evidence_params)

      if result.success?
        @person.reload
        remaining = @assignment.unsettled_demographic_fields(@person).size
        redirect_to demographics_assignment_path(@assignment),
                    notice: "Saved. #{remaining} #{'field'.pluralize(remaining)} still need a determination."
      else
        @field_errors = result.errors
        # The rollback restores the DB but @person keeps the submitted values in
        # memory, so the value half of each row redisplays what was typed. The
        # evidence half comes from @verifications, which was loaded before the
        # save — without this overlay the researcher would lose every source URL
        # and note they entered and have to retype them to fix one field.
        @submitted_evidence = evidence_params
        flash.now[:alert] = "Nothing was saved — #{result.errors.size} #{'field'.pluralize(result.errors.size)} need attention."
        render :show, status: :unprocessable_entity
      end
    end

    def start
      @assignment.start!
      redirect_to demographics_assignment_path(@assignment), notice: "Demographic research started."
    end

    # Completion gate: every field REQUIRED BY THIS ASSIGNMENT that applies to
    # this person needs a determination — a sourced value, or an explicit "not
    # publicly documented". Leaving a field blank is not an answer.
    #
    # The scope is the assignment's, not the person's: a task narrowed to race
    # and gender completes on those two. The person-level rollup below still
    # measures all core fields, so a narrow task can complete while the person
    # remains "in progress" — which is the honest description of that state.
    def complete
      unsettled = @assignment.unsettled_demographic_fields(@person)

      if unsettled.any?
        redirect_to demographics_assignment_path(@assignment),
                    alert: "#{unsettled.size} #{'field'.pluralize(unsettled.size)} still need a determination: #{unsettled.map(&:label).to_sentence}."
        return
      end

      @assignment.complete!
      @assignment.person.refresh_demographics_status!(reviewer: current_user)
      redirect_to demographics_assignments_path, notice: completion_notice
    end

    def reopen
      @assignment.reopen!
      redirect_to demographics_assignment_path(@assignment), notice: "Assignment reopened."
    end

    private

    # Be explicit when a narrowed task finishes but the person still has gaps,
    # so nobody reads "completed" as "this person's demographics are done".
    def completion_notice
      return "Demographic research completed!" unless @assignment.scoped_demographics?

      still_open = @person.unsettled_demographic_fields.size
      return "Demographic research completed!" if still_open.zero?

      "Demographic research completed for #{@assignment.demographic_scope_summary}. " \
        "#{still_open} other #{'field'.pluralize(still_open)} on this person remain unresearched."
    end

    def set_assignment
      @assignment = current_user.assignments.demographic_research.find(params[:id])
      @person = @assignment.person
    end

    # Everything a researcher needs to source a determination without leaving
    # the page: the person's own sites, their Wikipedia entry, and every active
    # social account we hold (verified ones first — an unverified handle is
    # still a lead worth reading, it just carries less weight).
    def load_reference_material
      @social_accounts = @person.social_media_accounts
                                .active
                                .where.not(url: [nil, ''])
                                .order(verified: :desc, platform: :asc)
      @current_offices = @person.officeholders.current.includes(office: [:body, :district])
      @candidacies = @person.candidates.includes(contest: [:ballot, :office]).order('contests.date DESC')
      @verifications = @person.demographic_verifications.index_by(&:field_key)
    end

    def values_params
      return {} unless params[:values]

      params.require(:values).permit(
        *DemographicField::ALL.reject(&:multi_select?).map(&:key),
        race: []
      ).to_h.symbolize_keys
    end

    def evidence_params
      return {} unless params[:evidence]

      permitted = DemographicField::KEYS.index_with { [:status, :source_url, :notes] }
      params.require(:evidence).permit(permitted).to_h.symbolize_keys
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
