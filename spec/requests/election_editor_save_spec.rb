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

  it "does not unverify a verified account when its own URL is re-sent (legacy @-prefixed handle)" do
    person = Person.create!(first_name: "Kathy", last_name: "Hochul", state_of_residence: "NY")
    account = person.social_media_accounts.create!(
      platform: "TikTok", handle: "@kathyhochul", url: "https://www.tiktok.com/@kathyhochul",
      channel_type: "Campaign", verified: true
    )

    rows = [row(key: "r1", first: "Kathy", last: "Hochul", personId: person.id,
                socials: { TikTok: { accountId: account.id, value: account.url } })]

    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json

    body = JSON.parse(response.body)
    expect(body["results"].first["ok"]).to be(true)
    expect(body["results"].first["warnings"]).to eq([])
    expect(account.reload.verified).to be(true)
    expect(account.handle).to eq("@kathyhochul") # untouched
  end

  it "treats cosmetic URL variants of the same handle as unchanged (verified stays verified)" do
    person = Person.create!(first_name: "Ed", last_name: "Markey", state_of_residence: "NY")
    account = person.social_media_accounts.create!(
      platform: "Twitter", handle: "EdMarkey", url: "https://twitter.com/EdMarkey",
      channel_type: "Official Office", verified: true
    )

    rows = [row(key: "r1", first: "Ed", last: "Markey", personId: person.id,
                socials: { Twitter: { accountId: account.id, value: "https://x.com/EdMarkey?lang=en" } })]
    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json

    expect(JSON.parse(response.body)["results"].first["warnings"]).to eq([])
    expect(account.reload.verified).to be(true)
    expect(account.url).to eq("https://twitter.com/EdMarkey") # verified URL untouched
  end

  it "fills in a missing URL for the same handle without unverifying" do
    person = Person.create!(first_name: "Ayanna", last_name: "Pressley", state_of_residence: "NY")
    account = person.social_media_accounts.create!(
      platform: "Twitter", handle: "RepPressley", url: nil, channel_type: "Official Office", verified: true
    )

    rows = [row(key: "r1", first: "Ayanna", last: "Pressley", personId: person.id,
                socials: { Twitter: { accountId: account.id, value: "https://x.com/RepPressley" } })]
    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json

    expect(account.reload.url).to eq("https://x.com/RepPressley")
    expect(account.verified).to be(true)
  end

  it "repairs a garbage stored handle when the identical URL is re-sent, keeping verified" do
    person = Person.create!(first_name: "Ayanna", last_name: "Pressley", state_of_residence: "NY")
    account = person.social_media_accounts.create!(
      platform: "YouTube", handle: "videos", # legacy extractor bug
      url: "https://www.youtube.com/@ayannapressley4542/videos",
      channel_type: "Official Office", verified: true
    )

    rows = [row(key: "r1", first: "Ayanna", last: "Pressley", personId: person.id,
                socials: { YouTube: { accountId: account.id, value: account.url } })]
    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json

    expect(JSON.parse(response.body)["results"].first["warnings"]).to eq([])
    expect(account.reload.handle).to eq("ayannapressley4542")
    expect(account.verified).to be(true)
  end

  it "persists website_campaign and fills name_source only when blank" do
    rows = [row(key: "r1", first: "Abigail", last: "Spanberger",
                website: "https://abigailspanberger.com", nameSource: "Abigail A. Spanberger")]
    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json

    person = Person.find_by!(first_name: "Abigail", last_name: "Spanberger")
    expect(person.website_campaign).to eq("https://abigailspanberger.com")
    expect(person.name_source).to eq("Abigail A. Spanberger")

    rows = [row(key: "r1", first: "Abigail", last: "Spanberger", personId: person.id,
                website: "https://spanberger2026.com", nameSource: "SPANBERGER, ABIGAIL")]
    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json

    person.reload
    expect(person.website_campaign).to eq("https://spanberger2026.com") # website updates
    expect(person.name_source).to eq("Abigail A. Spanberger")           # provenance never overwritten
  end

  it "persists middle name and suffix on create and clears them when blanked" do
    rows = [row(key: "r1", first: "Clyde", last: "Jones", middleName: "W.", suffix: "Jr.")]
    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json

    person = Person.find_by!(first_name: "Clyde", last_name: "Jones")
    expect(person.middle_name).to eq("W.")
    expect(person.suffix).to eq("Jr.")

    rows = [row(key: "r1", first: "Clyde", last: "Jones", personId: person.id, middleName: "", suffix: "")]
    post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json
    expect(person.reload.middle_name).to be_nil
    expect(person.suffix).to be_nil
  end

  describe "placeholder account slots" do
    it "pre-populates the 6 core platform stubs for a new person and binds them" do
      rows = [row(key: "r1", first: "Testy", last: "McTest",
                  socials: { Twitter: { accountId: nil, value: "testymc" } })]
      post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json
      result = JSON.parse(response.body)["results"].first
      person = Person.find(result["personId"])

      core = SocialMediaAccount::CORE_PLATFORMS
      created = person.social_media_accounts
      expect(created.map(&:platform)).to match_array(core)
      # the filled one is entered; the rest are blank pre-populated stubs
      twitter = created.find { |a| a.platform == "Twitter" }
      expect(twitter.handle).to eq("testymc")
      expect(twitter.pre_populated).to be(false)
      stubs = created.reject { |a| a.platform == "Twitter" }
      expect(stubs.map(&:pre_populated).uniq).to eq([true])
      expect(stubs.map(&:handle).compact).to be_empty
      # every core platform is bound in the response so later edits fill in place
      expect(result["socials"].keys).to match_array(core)
    end

    it "does not create duplicate accounts on re-save" do
      rows = [row(key: "r1", first: "Testy", last: "McTest",
                  socials: { Twitter: { accountId: nil, value: "testymc" } })]
      post admin_election_editor_save_path(election), params: { rows: rows, deletedCandidateIds: [] }, as: :json
      person = Person.find(JSON.parse(response.body)["results"].first["personId"])
      count = person.social_media_accounts.count

      resave = [row(key: "r1", first: "Testy", last: "McTest", personId: person.id,
                    socials: { Twitter: { accountId: nil, value: "testymc" } })]
      post admin_election_editor_save_path(election), params: { rows: resave, deletedCandidateIds: [] }, as: :json
      expect(person.social_media_accounts.count).to eq(count)
    end
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
