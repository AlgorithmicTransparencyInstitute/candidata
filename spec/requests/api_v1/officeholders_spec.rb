require 'rails_helper'

RSpec.describe "GET /api/v1/officeholders", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  let!(:dem) { Party.create!(name: "Democratic", abbreviation: "D") }
  let!(:rep) { Party.create!(name: "Republican", abbreviation: "R") }

  # Congressional districts in this schema: level "federal", chamber nil
  # (see District.congressional). State-house districts: level "state",
  # chamber "lower".
  let!(:tx14) do
    District.create!(state: "TX", district_number: 14, level: "federal")
  end
  let!(:tx_hd5) do
    District.create!(state: "TX", district_number: 5, level: "state", chamber: "lower")
  end
  let!(:house_office) do
    Office.create!(title: "U.S. Representative TX-14", level: "federal", branch: "legislative",
                   state: "TX", office_category: "U.S. Representative",
                   body_name: "U.S. House of Representatives", district: tx14)
  end
  let!(:senate_office) do
    Office.create!(title: "U.S. Senator (NY)", level: "federal", branch: "legislative",
                   state: "NY", office_category: "U.S. Senator", body_name: "U.S. Senate")
  end
  let!(:state_house_office) do
    Office.create!(title: "TX State Representative HD-5", level: "state", branch: "legislative",
                   state: "TX", office_category: "State Representative",
                   body_name: "TX State House", district: tx_hd5)
  end

  let!(:rep_person) do
    Person.create!(first_name: "Randy", last_name: "Weber", state_of_residence: "TX",
                   person_uuid: SecureRandom.uuid).tap { |p| p.add_party(rep, is_primary: true) }
  end
  let!(:sen_person) do
    Person.create!(first_name: "Kirsten", last_name: "Gillibrand", state_of_residence: "NY",
                   person_uuid: SecureRandom.uuid).tap { |p| p.add_party(dem, is_primary: true) }
  end

  let!(:current_rep) do
    Officeholder.create!(person: rep_person, office: house_office,
                         start_date: Date.new(2025, 1, 3), elected_year: 2024)
  end
  let!(:current_sen) do
    Officeholder.create!(person: sen_person, office: senate_office,
                         start_date: Date.new(2025, 1, 3))
  end
  let!(:former_holder) do
    Officeholder.create!(person: sen_person, office: house_office,
                         start_date: Date.new(2019, 1, 3), end_date: Date.new(2021, 1, 3))
  end
  let!(:state_rep_person) do
    Person.create!(first_name: "Terri", last_name: "Leo", state_of_residence: "TX",
                   person_uuid: SecureRandom.uuid).tap { |p| p.add_party(rep, is_primary: true) }
  end
  let!(:current_state_rep) do
    Officeholder.create!(person: state_rep_person, office: state_house_office,
                         start_date: Date.new(2025, 1, 14), elected_year: 2024)
  end

  def get_index(params = {})
    get "/api/v1/officeholders", params: params, headers: headers
    JSON.parse(response.body)
  end

  it "returns only current officeholders by default, with person and office embedded" do
    body = get_index
    expect(response).to have_http_status(:ok)
    ids = body["data"].map { |o| o["id"] }
    expect(ids).to contain_exactly(current_rep.id, current_sen.id, current_state_rep.id)

    row = body["data"].find { |o| o["id"] == current_rep.id }
    expect(row["current"]).to be(true)
    expect(row["person"]["full_name"]).to eq("Randy Weber")
    expect(row["person"]["party"]).to eq("name" => "Republican", "abbreviation" => "R")
    expect(row["office"]["office_category"]).to eq("U.S. Representative")
    expect(row["office"]["district"]).to include("state" => "TX", "district_number" => 14, "chamber" => nil)
  end

  it "includes former officeholders with current=false" do
    body = get_index(current: "false")
    expect(body["data"].map { |o| o["id"] }).to include(former_holder.id)
  end

  it "answers 'who is the TX-14 rep'" do
    body = get_index(state: "TX", office_category: "U.S. Representative", district: 14)
    expect(body["data"].length).to eq(1)
    expect(body["data"].first["person"]["last_name"]).to eq("Weber")
  end

  it "filters by state, level, branch, body_name, chamber" do
    expect(get_index(state: "NY")["data"].map { |o| o["id"] }).to eq([current_sen.id])
    expect(get_index(level: "federal")["data"].length).to eq(2)
    expect(get_index(branch: "executive")["data"]).to be_empty
    expect(get_index(body_name: "U.S. Senate")["data"].map { |o| o["id"] }).to eq([current_sen.id])
    # chamber filters via the district — congressional districts have nil
    # chamber, so only the state-house holder matches "lower"
    expect(get_index(chamber: "lower")["data"].map { |o| o["id"] }).to eq([current_state_rep.id])
  end

  it "filters by party (name or abbreviation, primary party)" do
    expect(get_index(party: "Republican")["data"].map { |o| o["id"] })
      .to contain_exactly(current_rep.id, current_state_rep.id)
    expect(get_index(party: "D")["data"].map { |o| o["id"] }).to eq([current_sen.id])
  end

  it "filters by party via the legacy party_affiliation fallback" do
    legacy = Person.create!(first_name: "Leg", last_name: "Acy", state_of_residence: "TX",
                            person_uuid: SecureRandom.uuid, party_affiliation: rep)
    holder = Officeholder.create!(person: legacy, office: senate_office, start_date: Date.new(2025, 1, 3))
    expect(get_index(party: "R")["data"].map { |o| o["id"] })
      .to contain_exactly(current_rep.id, current_state_rep.id, holder.id)
  end

  it "supports updated_since" do
    current_rep.update_column(:updated_at, 3.days.ago)
    current_state_rep.update_column(:updated_at, 3.days.ago)
    body = get_index(updated_since: 1.day.ago.iso8601)
    expect(body["data"].map { |o| o["id"] }).to eq([current_sen.id])
  end
end
