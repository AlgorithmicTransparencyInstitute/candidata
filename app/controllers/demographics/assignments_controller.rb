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
        redirect_to demographics_assignment_path(@assignment),
                    notice: "Saved. #{@person.unsettled_demographic_fields.size} #{'field'.pluralize(@person.unsettled_demographic_fields.size)} still need a determination."
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

    # Completion gate: every core field that applies to this person needs a
    # determination — a sourced value, or an explicit "not publicly
    # documented". Leaving a field blank is not an answer.
    def complete
      unsettled = @assignment.person.unsettled_demographic_fields

      if unsettled.any?
        redirect_to demographics_assignment_path(@assignment),
                    alert: "#{unsettled.size} #{'field'.pluralize(unsettled.size)} still need a determination: #{unsettled.map(&:label).to_sentence}."
        return
      end

      @assignment.complete!
      @assignment.person.refresh_demographics_status!(reviewer: current_user)
      redirect_to demographics_assignments_path, notice: "Demographic research completed!"
    end

    def reopen
      @assignment.reopen!
      redirect_to demographics_assignment_path(@assignment), notice: "Assignment reopened."
    end

    private

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
