require 'rails_helper'

RSpec.describe "Api::V1 non-scalar param rejection", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  it "400s INVALID_PARAM on array-style params instead of 500" do
    [
      ["/api/v1/people", { "q" => ["a"] }],
      ["/api/v1/people", { "page" => ["1"] }],
      ["/api/v1/people", { "updated_since" => ["2026-01-01"] }],
      ["/api/v1/officeholders", { "party" => ["DEM"] }],
      ["/api/v1/candidates", { "per_page" => ["10"] }]
    ].each do |path, params|
      get path, params: params, headers: headers
      expect(response).to have_http_status(:bad_request), "#{path} #{params} got #{response.status}"
      expect(JSON.parse(response.body)["code"]).to eq("INVALID_PARAM")
    end
  end

  it "still serves plain scalar params" do
    get "/api/v1/people", params: { q: "smith", page: "1" }, headers: headers
    expect(response).to have_http_status(:ok)
  end
end
