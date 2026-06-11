module Api
  class PartiesController < BaseController
    def index
      scope = Party.all
      scope = scope.where(ideology: params[:ideology]) if params[:ideology].present?

      records, meta = paginate(scope.order(:name), page: params[:page], per_page: params[:per_page])
      json_response(records.map { |p| party_json(p) }, meta: meta)
    end

    def show
      party = Party.find(params[:id])
      json_response(party_detail_json(party))
    end

    private

    def party_json(party)
      {
        id: party.id,
        name: party.name,
        abbreviation: party.abbreviation,
        ideology: party.ideology,
        people_count: party.people.count
      }
    end

    def party_detail_json(party)
      {
        id: party.id,
        name: party.name,
        abbreviation: party.abbreviation,
        ideology: party.ideology,
        description: party.description,
        people_count: party.people.count
      }
    end
  end
end
