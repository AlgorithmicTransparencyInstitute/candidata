module Api
  module V1
    class OfficeholdersController < BaseController
      # GET /api/v1/officeholders — current by default (current=false for all).
      # Joins are all belongs_to (no row multiplication), except the party
      # filter which uses a subquery to avoid duplicates.
      def index
        since = updated_since_param
        return if performed?

        scope = Officeholder.joins(:office).order(:id)
        scope = scope.merge(Officeholder.current) unless params[:current] == "false"
        scope = scope.where("officeholders.updated_at >= ?", since) if since

        %i[state level branch office_category body_name].each do |field|
          scope = scope.where(offices: { field => params[field] }) if params[field].present?
        end

        if params[:district].present?
          scope = scope.joins(office: :district)
                       .where(districts: { district_number: params[:district] })
        end
        if params[:chamber].present?
          scope = scope.joins(office: :district).where(districts: { chamber: params[:chamber] })
        end

        if params[:party].present?
          party_ids = Party.where("name = :p OR abbreviation = :p", p: params[:party]).select(:id)
          scope = scope.joins(:person).where(
            "people.id IN (SELECT person_id FROM person_parties WHERE is_primary AND party_id IN (:ids)) " \
            "OR people.party_affiliation_id IN (:ids)",
            ids: party_ids
          )
        end

        records, meta = paginate(
          scope.includes(
            { person: [:party_affiliation, :social_media_accounts, { person_parties: :party }] },
            { office: :district }
          )
        )
        json_response(records.map { |oh| officeholder_json(oh) }, meta: meta)
      end

      private

      def officeholder_json(officeholder)
        {
          id: officeholder.id,
          start_date: officeholder.start_date,
          end_date: officeholder.end_date,
          elected_year: officeholder.elected_year,
          appointed: officeholder.appointed == true,
          current: officeholder.current?,
          updated_at: officeholder.updated_at&.iso8601,
          person: person_core_json(officeholder.person),
          office: office_json(officeholder.office)
        }
      end
    end
  end
end
