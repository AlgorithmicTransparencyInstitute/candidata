require 'rails_helper'

RSpec.describe "Api::V1 authentication", type: :request do
  let!(:person) { create(:person) } # any routable record for a probe request
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:probe_path) { "/api/v1/people/#{person.reload.person_uuid || 'missing'}" }

  before { person.update!(person_uuid: SecureRandom.uuid) }

  it "returns 401 UNAUTHORIZED with no Authorization header" do
    get probe_path
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["code"]).to eq("UNAUTHORIZED")
  end

  it "returns 401 for a malformed or unknown token" do
    get probe_path, headers: { "Authorization" => "Bearer nonsense" }
    expect(response).to have_http_status(:unauthorized)

    get probe_path, headers: { "Authorization" => "Token abc" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 for a revoked token" do
    raw = api_token.raw_token
    api_token.revoke!
    get probe_path, headers: { "Authorization" => "Bearer #{raw}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "authenticates a valid token and stamps last_used_at" do
    expect(api_token.last_used_at).to be_nil
    get probe_path, headers: { "Authorization" => "Bearer #{api_token.raw_token}" }
    expect(response).to have_http_status(:ok)
    expect(api_token.reload.last_used_at).to be_present
  end

  it "does not create a session or require CSRF" do
    get probe_path, headers: { "Authorization" => "Bearer #{api_token.raw_token}" }
    expect(response.headers["Set-Cookie"].to_s).not_to include("_session")
  end
end
