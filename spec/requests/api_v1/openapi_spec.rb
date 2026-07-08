require 'rails_helper'

RSpec.describe "GET /api/v1/openapi.json", type: :request do
  it "serves the OpenAPI spec without authentication" do
    get "/api/v1/openapi.json"

    expect(response).to have_http_status(:ok)
    spec = JSON.parse(response.body)
    expect(spec["openapi"]).to eq("3.1.0")
    expect(spec["paths"].keys).to include(
      "/officeholders", "/candidates", "/people", "/people/{person_uuid}"
    )
    expect(spec.dig("components", "securitySchemes", "bearerAuth", "scheme")).to eq("bearer")
  end

  it "documents every filter param the controllers actually accept" do
    get "/api/v1/openapi.json"
    spec = JSON.parse(response.body)

    param_names = lambda do |path|
      spec.dig("paths", path, "get", "parameters").map { |p|
        p["name"] || p["$ref"]&.split("/")&.last
      }
    end

    expect(param_names.call("/officeholders")).to include(
      "state", "level", "branch", "office_category", "body_name",
      "district", "chamber", "party", "current"
    )
    expect(param_names.call("/candidates")).to include(
      "year", "state", "office_category", "district", "chamber",
      "party", "outcome", "winners", "incumbent"
    )
    expect(param_names.call("/people")).to include("state", "q")
  end

  it "is cacheable and public" do
    get "/api/v1/openapi.json"
    expect(response.headers["Cache-Control"]).to include("public")
  end
end
