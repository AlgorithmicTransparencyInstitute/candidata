require 'rails_helper'

RSpec.describe "GET /api/v1/people/:person_uuid", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  let!(:party) { Party.create!(name: "Democratic", abbreviation: "D") }
  let!(:person) do
    Person.create!(
      first_name: "Kathy", last_name: "Hochul", state_of_residence: "NY",
      person_uuid: SecureRandom.uuid, gender: "Female", race: "White",
      website_official: "https://governor.ny.gov",
      website_campaign: "https://kathyhochul.com",
      photo_url: "https://example.com/kh.jpg", wikipedia_id: "Kathy_Hochul"
    ).tap { |p| p.add_party(party, is_primary: true) }
  end

  let!(:verified_account) do
    person.social_media_accounts.create!(
      platform: "Twitter", handle: "GovKathyHochul",
      url: "https://twitter.com/GovKathyHochul",
      channel_type: "Official Office", verified: true, research_status: "verified"
    )
  end
  let!(:unverified_account) do
    person.social_media_accounts.create!(
      platform: "TikTok", handle: "kathyhochul",
      url: "https://www.tiktok.com/@kathyhochul",
      channel_type: "Campaign", verified: false, research_status: "entered"
    )
  end
  let!(:inactive_verified_account) do
    person.social_media_accounts.create!(
      platform: "Facebook", handle: "OldPage", url: "https://facebook.com/OldPage",
      channel_type: "Campaign", verified: true, account_inactive: true
    )
  end

  it "returns the person with verified active socials, party, demographics, websites" do
    get "/api/v1/people/#{person.person_uuid}", headers: headers

    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)["data"]

    expect(data["person_uuid"]).to eq(person.person_uuid)
    expect(data["id"]).to eq(person.id)
    expect(data["full_name"]).to eq("Kathy Hochul")
    expect(data["gender"]).to eq("Female")
    expect(data["race"]).to eq("White")
    expect(data["websites"]).to eq(
      "official" => "https://governor.ny.gov",
      "campaign" => "https://kathyhochul.com",
      "personal" => nil
    )
    expect(data["party"]).to eq("name" => "Democratic", "abbreviation" => "D")
    expect(data["parties"]).to eq([{ "name" => "Democratic", "abbreviation" => "D", "is_primary" => true }])

    platforms = data["social_media_accounts"].map { |a| a["platform"] }
    expect(platforms).to eq(["Twitter"]) # verified + active only
    expect(data["social_media_accounts"].first).to eq(
      "platform" => "Twitter", "handle" => "GovKathyHochul",
      "url" => "https://twitter.com/GovKathyHochul", "channel_type" => "Official Office"
    )
  end

  it "never leaks workflow fields" do
    get "/api/v1/people/#{person.person_uuid}", headers: headers
    body = response.body
    %w[research_status entered_by verified_by junkipedia needs_secondary_verification].each do |field|
      expect(body).not_to include(field)
    end
  end

  it "includes current offices and candidacies" do
    office = Office.create!(title: "Governor", level: "state", branch: "executive",
                            state: "NY", office_category: "Governor")
    Officeholder.create!(person: person, office: office, start_date: Date.new(2021, 8, 24))
    election = Election.create!(state: "NY", date: Date.new(2026, 6, 23), election_type: "primary", year: 2026)
    ballot = Ballot.create!(state: "NY", date: election.date, election_type: "primary",
                            party: "Democratic", year: 2026, election: election)
    contest = Contest.create!(office: office, ballot: ballot, date: ballot.date,
                              party: "Democratic", contest_type: "primary")
    Candidate.create!(person: person, contest: contest, outcome: "won", incumbent: true,
                      party_at_time: "Democratic")

    get "/api/v1/people/#{person.person_uuid}", headers: headers
    data = JSON.parse(response.body)["data"]

    expect(data["current_offices"].length).to eq(1)
    expect(data["current_offices"].first["title"]).to eq("Governor")
    expect(data["candidacies"].length).to eq(1)
    expect(data["candidacies"].first).to include(
      "outcome" => "won", "winner" => true, "incumbent" => true, "party_at_time" => "Democratic"
    )
  end

  it "404s on an unknown uuid" do
    get "/api/v1/people/#{SecureRandom.uuid}", headers: headers
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)["code"]).to eq("NOT_FOUND")
  end
end
