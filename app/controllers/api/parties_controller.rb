module Api
  class PartiesController < BaseController
    # GET /api/parties?ideology=
    def index
      scope = Party.order(:name)
      scope = scope.where(ideology: params[:ideology]) if params[:ideology].present?

      records, meta = paginate(scope)
      json_response(records.map { |p| party_json(p) }, meta: meta)
    end

    def show
      party = Party.find(params[:id])
      json_response(party_json(party).merge(people_count: party.people.count))
    end

    private

    def party_json(party)
      {
        id: party.id,
        name: party.name,
        abbreviation: party.abbreviation,
        ideology: party.ideology
      }
    end
  end
end
