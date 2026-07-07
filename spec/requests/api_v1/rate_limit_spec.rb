require 'rails_helper'

RSpec.describe "Api::V1 rate limiting", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  it "returns 429 RATE_LIMITED beyond 300 requests per minute per token" do
    memory_cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(memory_cache)

    travel_to Time.current.beginning_of_minute + 5.seconds do
      key = "api_v1_rate:#{api_token.id}:#{Time.current.to_i / 60}"
      300.times { memory_cache.increment(key, 1, expires_in: 2.minutes) }

      get "/api/v1/people", headers: headers
      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)["code"]).to eq("RATE_LIMITED")
    end
  end

  it "does not limit under the threshold" do
    memory_cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(memory_cache)

    get "/api/v1/people", headers: headers
    expect(response).to have_http_status(:ok)
  end

  it "no-ops when the cache store does not support increment counts (test default null_store)" do
    get "/api/v1/people", headers: headers
    expect(response).to have_http_status(:ok)
  end
end
