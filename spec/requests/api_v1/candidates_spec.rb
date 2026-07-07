require 'rails_helper'

RSpec.describe "GET /api/v1/candidates", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  # A state-house race: gives us a district with a chamber so the
  # district/chamber/office_category filters can all be exercised on one office.
  let!(:ga_hd14) { District.create!(state: "GA", district_number: 14, level: "state", chamber: "lower") }
  let!(:office) do
    Office.create!(title: "GA State Representative HD-14", level: "state", branch: "legislative",
                   state: "GA", office_category: "State Representative",
                   body_name: "GA State House", district: ga_hd14)
  end
  let!(:election) { Election.create!(state: "GA", date: Date.new(2026, 5, 19), election_type: "primary", year: 2026) }
  let!(:ballot) do
    Ballot.create!(state: "GA", date: election.date, election_type: "primary",
                   party: "Republican", year: 2026, election: election)
  end
  let!(:contest) do
    Contest.create!(office: office, ballot: ballot, date: ballot.date,
                    party: "Republican", contest_type: "primary")
  end

  let!(:winner_person) do
    Person.create!(first_name: "Win", last_name: "Ner", state_of_residence: "GA", person_uuid: SecureRandom.uuid)
  end
  let!(:loser_person) do
    Person.create!(first_name: "Lo", last_name: "Ser", state_of_residence: "GA", person_uuid: SecureRandom.uuid)
  end
  let!(:advanced_person) do
    Person.create!(first_name: "Ad", last_name: "Vanced", state_of_residence: "GA", person_uuid: SecureRandom.uuid)
  end

  let!(:winner) do
    Candidate.create!(person: winner_person, contest: contest, outcome: "won",
                      incumbent: true, party_at_time: "Republican", tally: 100)
  end
  let!(:loser) do
    Candidate.create!(person: loser_person, contest: contest, outcome: "lost",
                      incumbent: false, party_at_time: "Republican", tally: 40)
  end
  let!(:advanced) do
    other_contest = Contest.create!(office: office, ballot: ballot, date: ballot.date,
                                    party: "Democratic", contest_type: "primary")
    Candidate.create!(person: advanced_person, contest: other_contest, outcome: "advanced",
                      incumbent: false, party_at_time: "Democratic")
  end

  def get_index(params = {})
    get "/api/v1/candidates", params: params, headers: headers
    JSON.parse(response.body)
  end

  it "returns candidates with person and contest chain embedded" do
    body = get_index
    expect(response).to have_http_status(:ok)
    expect(body["data"].length).to eq(3)

    row = body["data"].find { |c| c["id"] == winner.id }
    expect(row).to include("outcome" => "won", "winner" => true, "incumbent" => true,
                           "party_at_time" => "Republican", "tally" => 100)
    expect(row["person"]["full_name"]).to eq("Win Ner")
    expect(row["contest"]["contest_type"]).to eq("primary")
    expect(row["contest"]["office"]["district"]["district_number"]).to eq(14)
    expect(row["contest"]["ballot"]["election"]["year"]).to eq(2026)
  end

  it "filters by year, state, office_category, district, chamber" do
    expect(get_index(year: 2026)["data"].length).to eq(3)
    expect(get_index(year: 2024)["data"]).to be_empty
    expect(get_index(state: "GA")["data"].length).to eq(3)
    expect(get_index(state: "TX")["data"]).to be_empty
    expect(get_index(office_category: "State Representative")["data"].length).to eq(3)
    expect(get_index(district: 14)["data"].length).to eq(3)
    expect(get_index(district: 6)["data"]).to be_empty
    expect(get_index(chamber: "lower")["data"].length).to eq(3)
    expect(get_index(chamber: "upper")["data"]).to be_empty
  end

  it "filters by party_at_time" do
    expect(get_index(party: "Republican")["data"].map { |c| c["id"] }).to contain_exactly(winner.id, loser.id)
    expect(get_index(party: "Democratic")["data"].map { |c| c["id"] }).to eq([advanced.id])
  end

  it "filters by outcome, and winners=true includes won AND advanced" do
    expect(get_index(outcome: "lost")["data"].map { |c| c["id"] }).to eq([loser.id])
    expect(get_index(winners: "true")["data"].map { |c| c["id"] }).to contain_exactly(winner.id, advanced.id)
  end

  it "filters incumbents vs challengers" do
    expect(get_index(incumbent: "true")["data"].map { |c| c["id"] }).to eq([winner.id])
    expect(get_index(incumbent: "false")["data"].map { |c| c["id"] }).to contain_exactly(loser.id, advanced.id)
  end

  it "supports updated_since" do
    winner.update_column(:updated_at, 3.days.ago)
    loser.update_column(:updated_at, 3.days.ago)
    body = get_index(updated_since: 1.day.ago.iso8601)
    expect(body["data"].map { |c| c["id"] }).to eq([advanced.id])
  end
end
