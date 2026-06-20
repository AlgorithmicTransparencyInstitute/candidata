require 'rails_helper'

# Guards the server side of the save endpoint: a single POST with MANY rows must
# upsert every valid row (not just the first). The "only one row saves" bug that
# prompted this was actually client-side (a deferred React state updater in
# EditorApp.save), but this pins the server contract the client relies on.
RSpec.describe "Admin election editor save", type: :request do
  let(:admin) { create(:user, :admin) }

  let(:election) do
    Election.create!(state: "NY", date: Date.new(2026, 6, 23), election_type: "primary", year: 2026)
  end

  let(:office) do
    Office.create!(title: "Governor", level: "state", branch: "executive", state: "NY")
  end

  let(:ballot) do
    Ballot.create!(state: "NY", date: election.date, election_type: "primary",
                   party: "Democratic", year: 2026, election: election)
  end

  let(:contest) do
    Contest.create!(office: office, ballot: ballot, date: ballot.date,
                    party: "Democratic", contest_type: "primary")
  end

  before { sign_in admin }

  def row(key:, first:, last:, **extra)
    { key: key, candidateId: nil, personId: nil, contestId: contest.id,
      firstName: first, lastName: last, party: "Democratic",
      outcome: "pending", incumbent: false, gender: "", race: "",
      socials: {} }.merge(extra)
  end

  it "saves every valid row, not just the first" do
    rows = [
      row(key: "r1", first: "Kathy",   last: "Hochul"),
      row(key: "r2", first: "Antonio", last: "Delgado"),
      row(key: "r3", first: "Jumaane", last: "Williams")
    ]

    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    oks = body["results"].select { |r| r["ok"] }
    expect(oks.size).to eq(3)
    expect(Candidate.where(contest: contest).count).to eq(3)
  end
end
