module Api
  class PeopleController < BaseController
    before_action :require_admin!, only: [:create, :update, :bulk_assign]
    before_action :set_person, only: [:show, :update]

    # GET /api/people?q=&state=&party_id=&page=&per_page=
    def index
      scope = Person.order(:last_name, :first_name)

      if params[:q].present?
        params[:q].split(/\s+/).each do |term|
          pattern = "%#{Person.sanitize_sql_like(term)}%"
          scope = scope.where("first_name ILIKE :p OR last_name ILIKE :p OR middle_name ILIKE :p", p: pattern)
        end
      end
      scope = scope.by_state(params[:state]) if params[:state].present?
      scope = scope.by_party(params[:party_id]) if params[:party_id].present?

      records, meta = paginate(scope.includes(:social_media_accounts, person_parties: :party))
      json_response(records.map { |p| person_json(p) }, meta: meta)
    end

    def show
      json_response(person_detail_json(@person))
    end

    def create
      person = Person.new(person_params)
      person.save!
      apply_primary_party(person)
      json_response(person_detail_json(person), status: :created)
    end

    def update
      @person.update!(person_params)
      apply_primary_party(@person)
      json_response(person_detail_json(@person))
    end

    # POST /api/people/bulk_assign
    # { person_ids: [], user_id:, task_type: "data_collection", notes: "" }
    def bulk_assign
      user = User.find(params.require(:user_id))
      people = Person.where(id: Array(params.require(:person_ids)))
      task_type = params[:task_type].presence || "data_collection"

      created = []
      skipped = []
      people.each do |person|
        assignment = Assignment.new(
          person: person, user: user, assigned_by: current_user,
          task_type: task_type, status: "pending", notes: params[:notes]
        )
        if assignment.save
          created << assignment
        else
          skipped << { person_id: person.id, errors: assignment.errors.full_messages }
        end
      end

      json_response(
        created.map { |a| assignment_json(a) },
        meta: { created: created.size, skipped: skipped.size, skipped_details: skipped }
      )
    end

    private

    def set_person
      @person = Person.find(params[:id])
    end

    def person_params
      params.require(:person).permit(
        :first_name, :last_name, :middle_name, :suffix, :gender, :race,
        :birth_date, :state_of_residence, :photo_url,
        :website_official, :website_campaign, :website_personal
      )
    end

    def apply_primary_party(person)
      return unless params[:person]&.key?(:primary_party_id)

      party_id = params[:person][:primary_party_id]
      person.primary_party = party_id.present? ? Party.find(party_id) : nil
    end

    def person_json(person)
      {
        id: person.id,
        first_name: person.first_name,
        last_name: person.last_name,
        full_name: person.full_name,
        state_of_residence: person.state_of_residence,
        gender: person.gender,
        race: person.race,
        primary_party: party_ref(person.person_parties.find(&:is_primary)&.party),
        social_media_accounts_count: person.social_media_accounts.size,
        needs_secondary_verification: person.needs_secondary_verification
      }
    end

    def person_detail_json(person)
      {
        id: person.id,
        first_name: person.first_name,
        last_name: person.last_name,
        middle_name: person.middle_name,
        suffix: person.suffix,
        full_name: person.full_name,
        gender: person.gender,
        race: person.race,
        birth_date: person.birth_date,
        state_of_residence: person.state_of_residence,
        photo_url: person.photo_url,
        website_official: person.website_official,
        website_campaign: person.website_campaign,
        website_personal: person.website_personal,
        person_uuid: person.person_uuid,
        needs_secondary_verification: person.needs_secondary_verification,
        primary_party: party_ref(person.primary_party),
        parties: person.person_parties.includes(:party).map { |pp|
          party_ref(pp.party).merge(is_primary: pp.is_primary)
        },
        current_offices: person.current_offices.map { |o|
          { id: o.id, title: o.title, level: o.level, branch: o.branch, state: o.state, seat: o.seat }
        },
        candidacies: person.candidates.includes(contest: [:office, :ballot]).map { |c|
          {
            id: c.id,
            contest_id: c.contest_id,
            contest: c.contest.full_name,
            outcome: c.outcome,
            tally: c.tally,
            incumbent: c.incumbent,
            party_at_time: c.party_at_time
          }
        },
        social_media_accounts: person.social_media_accounts.map { |a|
          {
            id: a.id, platform: a.platform, handle: a.handle, url: a.url,
            channel_type: a.channel_type, verified: a.verified,
            research_status: a.research_status, account_inactive: a.account_inactive
          }
        },
        assignments: person.assignments.map { |a| assignment_json(a) }
      }
    end

    def assignment_json(assignment)
      {
        id: assignment.id,
        person_id: assignment.person_id,
        user_id: assignment.user_id,
        assigned_by_id: assignment.assigned_by_id,
        task_type: assignment.task_type,
        status: assignment.status,
        notes: assignment.notes,
        completed_at: assignment.completed_at
      }
    end

    def party_ref(party)
      return nil unless party

      { id: party.id, name: party.name, abbreviation: party.abbreviation }
    end
  end
end
