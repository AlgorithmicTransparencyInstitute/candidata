require 'rails_helper'

# The public (signed-out) site. These pin the "phase 0" trust fixes: the site
# must never show more than /api/v1 does, and must not present empty data as
# a result.
RSpec.describe "Public pages", type: :request do
  let!(:person) { Person.create!(first_name: "Jim", last_name: "Himes", state_of_residence: "CT") }

  describe "person page social accounts" do
    before do
      person.social_media_accounts.create!(platform: "Twitter", handle: "jahimes",
                                           url: "https://twitter.com/jahimes", verified: true)
      person.social_media_accounts.create!(platform: "TikTok", handle: "unverifiedhimes",
                                           url: "https://www.tiktok.com/@unverifiedhimes", verified: false)
      person.social_media_accounts.create!(platform: "Facebook", handle: "oldhimes",
                                           url: "https://facebook.com/oldhimes", verified: true, account_inactive: true)
      # Verified absence: a verifier confirmed there is no account here.
      person.social_media_accounts.create!(platform: "Instagram", handle: nil, url: nil, verified: true)
    end

    it "lists only verified, active accounts that have a URL" do
      get person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://twitter.com/jahimes")
      expect(response.body).not_to include("unverifiedhimes")
      expect(response.body).not_to include("oldhimes")
      expect(response.body).not_to match(/>\s*Instagram\s*</)
    end

    it "matches the scope the public API uses" do
      listed = person.social_media_accounts.select(&:publicly_listed?)
      expect(listed.map(&:handle)).to eq(SocialMediaAccount.publicly_listed.where(person: person).pluck(:handle))
    end
  end

  describe "election and contest pages" do
    let!(:election) { Election.create!(state: "CT", date: Date.new(2026, 11, 3), election_type: "general", year: 2026, name: "2026 CT General") }
    let!(:ballot) { Ballot.create!(state: "CT", date: Date.new(2026, 11, 3), election_type: "general", year: 2026, election: election) }
    let!(:office) { Office.create!(title: "U.S. Representative", level: "federal", branch: "legislative") }
    let!(:contest) { Contest.create!(ballot: ballot, office: office, date: Date.new(2026, 11, 3), contest_type: "general") }

    it "marks won and advanced candidates as winners on the election page" do
      Candidate.create!(person: person, contest: contest, outcome: "advanced")

      get election_path(election)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("text-green-500")
    end

    it "shows no winner mark for pending candidates" do
      Candidate.create!(person: person, contest: contest, outcome: "pending")

      get election_path(election)

      expect(response.body).not_to include("text-green-500")
    end

    it "hides Total Votes on a contest with no tallies" do
      Candidate.create!(person: person, contest: contest, outcome: "pending")

      get contest_path(contest)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Total Votes")
    end

    it "shows Total Votes once tallies exist" do
      Candidate.create!(person: person, contest: contest, outcome: "won", tally: 12_345)

      get contest_path(contest)

      expect(response.body).to include("Total Votes")
      expect(response.body).to include("12,345")
    end
  end

  describe "privacy" do
    around do |example|
      original = ENV["MIXPANEL_TOKEN"]
      ENV["MIXPANEL_TOKEN"] = "test-token"
      example.run
    ensure
      ENV["MIXPANEL_TOKEN"] = original
    end

    it "offers an analytics choice and doesn't load Mixpanel for anonymous visitors until they accept" do
      get root_path

      expect(response.body).to include("Allow analytics")
      expect(response.body).to include("Essential only")
      expect(response.body).not_to include("do not use optional tracking")
      expect(response.body).to include('localStorage.getItem("analyticsConsent")')
      # Only the consent-gated call; no unconditional load.
      expect(response.body).not_to match(/^\s*window\.candidataLoadAnalytics\(\);/)
      expect(response.body).to include('if (consent === "granted") window.candidataLoadAnalytics();')
    end

    it "has the privacy section the banner links to" do
      get help_path
      expect(response.body).to include('id="privacy"')
    end
  end

  it "no longer serves the debug charts page" do
    get "/test/charts"
    expect(response).to have_http_status(:not_found)
  end
end
