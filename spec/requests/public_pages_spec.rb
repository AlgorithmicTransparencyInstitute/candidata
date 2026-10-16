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
      expect(response.body).to include("✓ Advanced")
    end

    it "shows no winner mark for pending candidates" do
      Candidate.create!(person: person, contest: contest, outcome: "pending")

      get election_path(election)

      expect(response.body).not_to include("✓")
    end

    it "shows no vote figures on a contest with no tallies" do
      Candidate.create!(person: person, contest: contest, outcome: "pending")

      get contest_path(contest)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to match(/\d votes</)
    end

    it "shows vote counts and shares once tallies exist" do
      Candidate.create!(person: person, contest: contest, outcome: "won", tally: 12_345)

      get contest_path(contest)

      expect(response.body).to include("12,345 votes")
      expect(response.body).to include("100.0%")
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

  describe "public layout" do
    it "renders one main landmark, lang, skip link, per-page title and footer" do
      get person_path(person)

      expect(response.body).to include('<html lang="en">')
      expect(response.body.scan("<main").size).to eq(1)
      expect(response.body).to include('href="#main"')
      expect(response.body).to include("<title>Jim Himes · CandiData</title>")
      expect(response.body).to include('rel="canonical"')
      expect(response.body).to include("Data sources &amp; methodology")
    end

    it "uses the default title on pages that don't set one" do
      get help_path
      expect(response.body).to include("<title>CandiData — U.S. officials and candidates</title>")
    end
  end

  describe "person URLs" do
    it "uses an id-name slug" do
      expect(person_path(person)).to eq("/people/#{person.id}-jim-himes")
    end

    it "redirects numeric and stale-slug URLs to the canonical one" do
      get "/people/#{person.id}"
      expect(response).to redirect_to(person_path(person))
      expect(response).to have_http_status(:moved_permanently)

      get "/people/#{person.id}-old-name"
      expect(response).to redirect_to(person_path(person))
    end

    it "lists elections with outcome and links to the contest" do
      election = Election.create!(state: "CT", date: Date.new(2026, 8, 11), election_type: "primary", year: 2026)
      ballot = Ballot.create!(state: "CT", date: Date.new(2026, 8, 11), election_type: "primary", year: 2026,
                              party: "Democratic", election: election)
      office = Office.create!(title: "U.S. Representative", level: "federal", branch: "legislative", state: "CT")
      contest = Contest.create!(ballot: ballot, office: office, date: Date.new(2026, 8, 11),
                                contest_type: "primary", party: "Democratic")
      Candidate.create!(person: person, contest: contest, outcome: "won", incumbent: true)

      get person_path(person)

      expect(response.body).to include(contest_path(contest))
      expect(response.body).to include("Democratic primary")
      expect(response.body).to include("✓ Won")
    end
  end

  describe "race page" do
    let(:election) { Election.create!(state: "TX", date: Date.new(2026, 11, 3), election_type: "general", year: 2026, name: "2026 TX General Election") }
    let(:ballot) { Ballot.create!(state: "TX", date: Date.new(2026, 11, 3), election_type: "general", year: 2026, election: election) }
    let(:office) { Office.create!(title: "U.S. Senator", level: "federal", branch: "legislative", state: "TX") }
    let(:general) { Contest.create!(ballot: ballot, office: office, date: Date.new(2026, 11, 3), contest_type: "general") }

    def candidate(first, last, party, **attrs)
      Candidate.create!(person: Person.create!(first_name: first, last_name: last), contest: general,
                        party_at_time: party, outcome: "pending", **attrs)
    end

    it "orders major parties first, incumbents next, then alphabetically, and states the rule" do
      candidate("Ted", "Brown", "Libertarian")
      candidate("James", "Talarico", "Democratic")
      candidate("Ken", "Paxton", "Republican")

      get contest_path(general)

      body = response.body
      expect(body.index("Ken Paxton")).to be < body.index("James Talarico")
      expect(body.index("James Talarico")).to be < body.index("Ted Brown")
      expect(body).to include("not a ranking or an endorsement")
    end

    it "shows only verified accounts and links to the seat's primaries" do
      c = candidate("James", "Talarico", "Democratic")
      c.person.social_media_accounts.create!(platform: "TikTok", handle: "jamestalarico",
                                             url: "https://www.tiktok.com/@jamestalarico", verified: true)
      c.person.social_media_accounts.create!(platform: "Twitter", handle: "unverifiedtalarico",
                                             url: "https://x.com/unverifiedtalarico", verified: false)
      pballot = Ballot.create!(state: "TX", date: Date.new(2026, 3, 3), election_type: "primary", year: 2026, party: "Democratic")
      primary = Contest.create!(ballot: pballot, office: office, date: Date.new(2026, 3, 3), contest_type: "primary", party: "Democratic")

      get contest_path(general)

      expect(response.body).to include("https://www.tiktok.com/@jamestalarico")
      expect(response.body).not_to include("unverifiedtalarico")
      expect(response.body).to include(contest_path(primary))
      expect(response.body).to include("<title>U.S. Senator · TX — 2026 general election · CandiData</title>")
    end
  end

  describe "elections index" do
    it "filters 2026 races by type, office and state, ignoring bad params" do
      State.create!(name: "Texas", abbreviation: "TX")
      ballot = Ballot.create!(state: "TX", date: Date.new(2026, 11, 3), election_type: "general", year: 2026)
      senate = Office.create!(title: "U.S. Senator", office_category: "U.S. Senator", level: "federal", branch: "legislative", state: "TX")
      house = Office.create!(title: "U.S. Representative", office_category: "U.S. Representative", level: "federal", branch: "legislative", state: "TX")
      Contest.create!(ballot: ballot, office: senate, date: Date.new(2026, 11, 3), contest_type: "general")
      Contest.create!(ballot: ballot, office: house, date: Date.new(2026, 11, 3), contest_type: "general")

      get elections_path(office: "senate", state: "tx")
      expect(response.body).to include("1 race")
      expect(response.body).to include("2026 elections in Texas")

      get elections_path(office: "bogus", type: "nope", state: "ZZ")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("2 races")
    end
  end

  describe "SEO groundwork" do
    it "serves a sitemap with person, state and race URLs" do
      State.create!(name: "Connecticut", abbreviation: "CT")
      get "/sitemap.xml"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include("/people/#{person.id}-jim-himes")
      expect(response.body).to include("/states/CT")
    end

    it "embeds schema.org Person data with only verified account URLs" do
      person.social_media_accounts.create!(platform: "Twitter", handle: "jahimes", url: "https://twitter.com/jahimes", verified: true)
      person.social_media_accounts.create!(platform: "TikTok", handle: "nope", url: "https://www.tiktok.com/@nope", verified: false)

      get person_path(person)

      ld = response.body[%r{<script type="application/ld\+json">(.*?)</script>}m, 1]
      data = JSON.parse(ld)
      expect(data).to include("@type" => "Person", "name" => "Jim Himes")
      expect(data["sameAs"]).to eq(["https://twitter.com/jahimes"])
    end

    it "keeps search engines blocked until the team decides otherwise" do
      expect(File.read(Rails.root.join("public/robots.txt"))).to include("Disallow: /")
    end
  end

  it "no longer serves the debug charts page" do
    get "/test/charts"
    expect(response).to have_http_status(:not_found)
  end
end
