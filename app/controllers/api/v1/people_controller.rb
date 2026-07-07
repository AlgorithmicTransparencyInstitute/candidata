module Api
  module V1
    class PeopleController < BaseController
      # GET /api/v1/people?state=&q=&updated_since=&page=&per_page=
      def index
        since = updated_since_param
        return if performed?

        scope = Person.order(:id)
        scope = scope.by_state(params[:state]) if params[:state].present?
        scope = scope.where("people.updated_at >= ?", since) if since

        if params[:q].present?
          params[:q].split(/\s+/).each do |term|
            pattern = "%#{Person.sanitize_sql_like(term)}%"
            scope = scope.where("first_name ILIKE :p OR last_name ILIKE :p OR middle_name ILIKE :p", p: pattern)
          end
        end

        records, meta = paginate(
          scope.includes(
            :party_affiliation, :social_media_accounts,
            { person_parties: :party },
            { officeholders: { office: :district } },
            { candidates: { contest: [:office, :ballot] } }
          )
        )
        json_response(records.map { |p| person_full_json(p) }, meta: meta)
      end

      # GET /api/v1/people/:person_uuid
      def show
        person = Person.includes(
          :party_affiliation, :social_media_accounts,
          { person_parties: :party },
          { officeholders: { office: :district } },
          { candidates: { contest: [:office, :ballot] } }
        ).find_by!(person_uuid: params[:person_uuid])

        json_response(person_full_json(person))
      end
    end
  end
end
