module Api
  module V1
    class PeopleController < BaseController
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
