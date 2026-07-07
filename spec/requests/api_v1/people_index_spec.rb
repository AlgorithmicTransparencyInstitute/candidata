require 'rails_helper'

RSpec.describe "GET /api/v1/people", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  let!(:ny_person) do
    Person.create!(first_name: "Kathy", last_name: "Hochul",
                   state_of_residence: "NY", person_uuid: SecureRandom.uuid)
  end
  let!(:tx_person) do
    Person.create!(first_name: "Greg", last_name: "Abbott",
                   state_of_residence: "TX", person_uuid: SecureRandom.uuid)
  end

  def get_index(params = {})
    get "/api/v1/people", params: params, headers: headers
    JSON.parse(response.body)
  end

  it "returns paginated people ordered by id" do
    body = get_index
    expect(response).to have_http_status(:ok)
    expect(body["data"].map { |p| p["id"] }).to eq([ny_person.id, tx_person.id].sort)
    expect(body["meta"]).to include("total" => 2, "page" => 1, "per_page" => 25)
  end

  it "filters by state" do
    body = get_index(state: "TX")
    expect(body["data"].map { |p| p["last_name"] }).to eq(["Abbott"])
  end

  it "filters by name search q" do
    body = get_index(q: "hoch")
    expect(body["data"].map { |p| p["last_name"] }).to eq(["Hochul"])

    body = get_index(q: "kathy hochul")
    expect(body["data"].map { |p| p["last_name"] }).to eq(["Hochul"])
  end

  it "filters by updated_since" do
    ny_person.update_column(:updated_at, 3.days.ago)
    body = get_index(updated_since: 1.day.ago.iso8601)
    expect(body["data"].map { |p| p["id"] }).to eq([tx_person.id])
  end

  it "400s on malformed updated_since" do
    get "/api/v1/people", params: { updated_since: "not-a-date" }, headers: headers
    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)["code"]).to eq("INVALID_PARAM")
  end

  it "caps per_page at 500" do
    body = get_index(per_page: 9999)
    expect(body["meta"]["per_page"]).to eq(500)
  end
end
