module Api
  class PeopleController < BaseController
    before_action :find_person, only: [:show, :update]
    before_action :authorize_admin!, except: [:show, :index]

    def index
      scope = Person.all
      scope = scope.where("CONCAT(first_name, ' ', last_name) ILIKE ?", "%#{search_query}%") if search_query.present?
      scope = scope.by_state(filter_state) if filter_state.present?
      scope = scope.by_party(filter_party) if filter_party.present?

      records, meta = paginate(scope, page: params[:page], per_page: params[:per_page])
      json_response(records.map { |p| person_json(p) }, meta: meta)
    end

    def show
      json_response(person_detail_json(@person))
    end

    def create
      person = Person.new(person_params)
      person.save!
      json_response(person_detail_json(person), status: :created)
    end

    def update
      @person.update!(person_params)
      json_response(person_detail_json(@person))
    end

    def bulk_assign
      authorize_admin!
      people = Person.where(id: params[:person_ids])
      user = User.find(params[:user_id])

      assignments = people.map do |person|
        Assignment.create!(
          person: person,
          user: user,
          assigned_by: current_user,
          assignment_type: params[:assignment_type] || 'data_collection',
          notes: params[:notes]
        )
      end

      json_response(
        assignments.map { |a| assignment_json(a) },
        meta: { created: assignments.length }
      )
    end

    private

    def find_person
      @person = Person.find(params[:id])
    end

    def authorize_admin!
      render json: { error: "Unauthorized", code: "FORBIDDEN" }, status: :forbidden unless current_user.admin?
    end

    def search_query
      params[:q].presence
    end

    def filter_state
      params[:state].presence
    end

    def filter_party
      params[:party_id].presence
    end

    def person_params
      params.require(:person).permit(
        :first_name, :last_name, :middle_name, :suffix, :gender, :date_of_birth,
        :place_of_birth, :state_of_residence, :website, :bio, :primary_party_id
      )
    end

    def person_json(person)
      {
        id: person.id,
        first_name: person.first_name,
        last_name: person.last_name,
        full_name: person.full_name,
        state_of_residence: person.state_of_residence,
        primary_party: person.primary_party ? { id: person.primary_party.id, name: person.primary_party.name } : nil,
        needs_secondary_verification: person.needs_secondary_verification,
        current_offices_count: person.current_offices.count,
        social_media_accounts_count: person.social_media_accounts.count
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
        date_of_birth: person.date_of_birth,
        place_of_birth: person.place_of_birth,
        state_of_residence: person.state_of_residence,
        website: person.website,
        bio: person.bio,
        person_uuid: person.person_uuid,
        airtable_id: person.airtable_id,
        needs_secondary_verification: person.needs_secondary_verification,
        primary_party: person.primary_party ? { id: person.primary_party.id, name: person.primary_party.name, abbreviation: person.primary_party.abbreviation } : nil,
        parties: person.parties.map { |p| { id: p.id, name: p.name, abbreviation: p.abbreviation, is_primary: person.person_parties.find_by(party: p)&.is_primary? } },
        current_offices: person.current_offices.map { |o| office_json(o, person) },
        former_offices: person.officeholders.former.map { |oh| { id: oh.office.id, category: oh.office.category, state: oh.office.district&.state&.abbreviation, start_date: oh.start_date, end_date: oh.end_date } },
        candidates: person.candidates.includes(:contest).map { |c| candidate_json(c) },
        social_media_accounts: person.social_media_accounts.map { |a| account_json(a) },
        assignments: person.assignments.map { |a| assignment_json(a) }
      }
    end

    def office_json(office, person)
      officeholder = person.officeholders.find_by(office: office)
      {
        id: office.id,
        category: office.category,
        level: office.level,
        branch: office.branch,
        body_name: office.body_name,
        state: office.district&.state&.abbreviation,
        start_date: officeholder&.start_date,
        end_date: officeholder&.end_date
      }
    end

    def candidate_json(candidate)
      {
        id: candidate.id,
        contest_id: candidate.contest.id,
        contest_name: candidate.contest.office.category,
        outcome: candidate.outcome,
        tally: candidate.tally,
        incumbent: candidate.incumbent
      }
    end

    def account_json(account)
      {
        id: account.id,
        platform: account.platform,
        handle: account.handle,
        url: account.url,
        channel_type: account.channel_type,
        verified: account.verified,
        research_status: account.research_status,
        verified_at: account.verified_at
      }
    end

    def assignment_json(assignment)
      {
        id: assignment.id,
        assignment_type: assignment.assignment_type,
        status: assignment.status,
        user_id: assignment.user_id,
        person_id: assignment.person_id,
        started_at: assignment.started_at,
        completed_at: assignment.completed_at
      }
    end
  end
end
