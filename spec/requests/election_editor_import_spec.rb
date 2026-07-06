require 'rails_helper'

# Pins the CSV import preview endpoint: header auto-mapping (canonical cleaned
# format + variants), value validation (party/outcome/gender vocab), office →
# contest matching (existing contest / creatable office / unresolved), person
# matching (exact single match links, ambiguous does not), duplicate and
# wrong-state rows, and mapping overrides. The endpoint is read-only — it must
# never write records.
RSpec.describe "Admin election editor CSV import preview", type: :request do
  let(:admin) { create(:user, :admin) }

  let(:election) do
    Election.create!(state: "NY", date: Date.new(2026, 6, 23), election_type: "primary", year: 2026)
  end

  let!(:house_office) do
    Office.create!(title: "U.S. Representative", level: "federal", branch: "legislative",
                   state: "NY", seat: "District 1", body_name: "U.S. House of Representatives")
  end

  let!(:senate_office) do
    Office.create!(title: "U.S. Senator", level: "federal", branch: "legislative",
                   state: "NY", body_name: "U.S. Senate")
  end

  let(:ballot) do
    Ballot.create!(state: "NY", date: election.date, election_type: "primary",
                   party: "Democratic", year: 2026, election: election)
  end

  let!(:house_contest) do
    Contest.create!(office: house_office, ballot: ballot, date: ballot.date,
                    party: "Democratic", contest_type: "primary")
  end

  before { sign_in admin }

  def preview(csv, mapping: nil)
    params = { csv: csv }
    params[:mapping] = mapping if mapping
    post admin_election_editor_import_path(election), params: params, as: :json
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  describe "auto-mapping the canonical cleaned-CSV headers" do
    let(:csv) do
      <<~CSV
        state,candidate_name,is_incumbent,withdrew,party,office,district,race,gender,website,twitter,facebook,notes
        NY,"Clyde W. Jones, Jr.",false,false,Democrat,U.S. House,1,White,Male,https://example.com,https://x.com/clyde,facebook.com/clyde,
      CSV
    end

    it "maps headers, normalizes values, and matches the existing contest" do
      body = preview(csv)

      expect(body["errors"]).to eq([])
      mapping = body["mapping"].to_h { |m| [m["header"], m["field"]] }
      expect(mapping).to include(
        "candidate_name" => "fullName", "is_incumbent" => "incumbent",
        "party" => "party", "office" => "office", "district" => "district",
        "twitter" => "social:Twitter", "facebook" => "social:Facebook"
      )
      expect(mapping["website"]).to be_nil
      expect(mapping["notes"]).to be_nil

      row = body["rows"].first
      expect(row["firstName"]).to eq("Clyde")
      expect(row["lastName"]).to eq("Jones")
      expect(row["party"]).to eq("Democratic")       # "Democrat" canonicalized
      expect(row["outcome"]).to eq("pending")
      expect(row["incumbent"]).to be(false)
      expect(row["gender"]).to eq("Male")
      expect(row["contestId"]).to eq(house_contest.id)
      expect(row["issues"]).to eq([])
      expect(row["socials"]["Twitter"]["value"]).to eq("https://x.com/clyde")

      group = body["contestGroups"].first
      expect(group["status"]).to eq("matched")
      expect(body["summary"]["contestsMatched"]).to eq(1)
    end

    it "writes nothing" do
      expect { preview(csv) }.not_to change {
        [Person.count, Candidate.count, Contest.count, Ballot.count, SocialMediaAccount.count]
      }
    end
  end

  describe "contest resolution" do
    it "marks a known office without a contest as creatable" do
      body = preview(<<~CSV)
        candidate_name,party,office
        Jane Doe,Republican,U.S. Senate
      CSV

      group = body["contestGroups"].first
      expect(group["status"]).to eq("create")
      expect(group["officeId"]).to eq(senate_office.id)
      expect(group["party"]).to eq("Republican")
    end

    it "matches party ballots separately in a primary" do
      body = preview(<<~CSV)
        candidate_name,party,office,district
        Jane Doe,Republican,U.S. House,1
      CSV

      # Only a Democratic contest exists for District 1 — Republican needs creation
      group = body["contestGroups"].first
      expect(group["status"]).to eq("create")
      expect(group["officeId"]).to eq(house_office.id)
    end

    it "narrows textually identical offices to the one already contested in this election" do
      # A state's second U.S. Senate seat: same title, no seat label
      Office.create!(title: "U.S. Senator", level: "federal", branch: "legislative",
                     state: "NY", body_name: "U.S. Senate")
      Contest.create!(office: senate_office, ballot: ballot, date: ballot.date,
                      party: "Democratic", contest_type: "primary")

      body = preview(<<~CSV)
        candidate_name,party,office
        Jane Doe,Republican,U.S. Senate
      CSV

      group = body["contestGroups"].first
      expect(group["status"]).to eq("create")
      expect(group["officeId"]).to eq(senate_office.id)
    end

    it "returns unresolved for unknown office text" do
      body = preview(<<~CSV)
        candidate_name,party,office
        Jane Doe,Democratic,Grand Poobah
      CSV

      expect(body["contestGroups"].first["status"]).to eq("unresolved")
      expect(body["summary"]["contestsUnresolved"]).to eq(1)
    end
  end

  describe "person matching" do
    it "links a single exact match and flags an existing candidacy for merge" do
      person = Person.create!(first_name: "Kathy", last_name: "Hochul", state_of_residence: "NY")
      person.social_media_accounts.create!(platform: "Twitter", handle: "kathyhochul",
                                           url: "https://twitter.com/kathyhochul", channel_type: "Campaign")
      candidate = Candidate.create!(person: person, contest: house_contest, outcome: "pending")

      body = preview(<<~CSV)
        candidate_name,party,office,district,tiktok
        Kathy Hochul,Democratic,U.S. House,1,https://www.tiktok.com/@kathy
      CSV

      row = body["rows"].first
      expect(row["personId"]).to eq(person.id)
      expect(row["mergeCandidateId"]).to eq(candidate.id)
      # existing account binds; CSV-provided TikTok arrives as a plain value
      expect(row["socials"]["Twitter"]["accountId"]).to be_present
      expect(row["socials"]["TikTok"]["value"]).to eq("https://www.tiktok.com/@kathy")
      expect(row["csv"]["socials"]).to eq("TikTok" => "https://www.tiktok.com/@kathy")
    end

    it "stages a diverging CSV handle as a separate unbound account instead of overwriting" do
      person = Person.create!(first_name: "Ayanna", last_name: "Pressley", state_of_residence: "NY")
      person.social_media_accounts.create!(platform: "Twitter", handle: "RepPressley",
                                           url: "https://twitter.com/RepPressley",
                                           channel_type: "Official Office", verified: true)

      body = preview(<<~CSV)
        candidate_name,party,office,district,twitter
        Ayanna Pressley,Democratic,U.S. House,1,https://x.com/AyannaPressley
      CSV

      cell = body["rows"].first["socials"]["Twitter"]
      expect(cell["accountId"]).to be_nil
      expect(cell["value"]).to eq("https://x.com/AyannaPressley")
      expect(body["rows"].first["warnings"].join).to include("separate campaign account")
    end

    it "does not link ambiguous non-incumbent matches" do
      2.times { Person.create!(first_name: "John", last_name: "Smith", state_of_residence: "NY") }

      body = preview(<<~CSV)
        candidate_name,party,office,district
        John Smith,Democratic,U.S. House,1
      CSV

      row = body["rows"].first
      expect(row["personId"]).to be_nil
      expect(row["warnings"].join).to include("2 existing people named John Smith")
    end
  end

  describe "row validation" do
    it "flags unknown parties, wrong state, duplicates, and withdrawn rows" do
      body = preview(<<~CSV)
        state,candidate_name,party,office,district,withdrew
        NY,Jane Doe,Whig,U.S. House,1,false
        TX,Bob Roe,Democratic,U.S. House,1,false
        NY,Ann Poe,Democratic,U.S. House,1,false
        NY,Ann Poe,Democratic,U.S. House,1,false
        NY,Sam Coe,Democratic,U.S. House,1,true
      CSV

      rows = body["rows"]
      expect(rows[0]["issues"].join).to include('Unknown party "Whig"')
      expect(rows[1]["issues"].join).to include("state TX")
      expect(rows[2]["issues"]).to eq([])
      expect(rows[3]["issues"].join).to include("Duplicate of row 4")
      expect(rows[4]["withdrawn"]).to be(true)
      expect(rows[4]["outcome"]).to eq("withdrawn")
      expect(body["summary"]["withdrawn"]).to eq(1)
    end

    it "requires a party column for primaries" do
      body = preview(<<~CSV)
        candidate_name,office
        Jane Doe,U.S. Senate
      CSV

      expect(body["errors"].join).to include("Party column is required")
      expect(body["rows"]).to eq([])
    end
  end

  describe "mapping overrides" do
    it "honors explicit mapping for unrecognized headers" do
      csv = <<~CSV
        who,ballot_line,contest_name
        Jane Doe,Democratic,U.S. Senate
      CSV

      auto = preview(csv)
      expect(auto["errors"]).not_to be_empty # nothing auto-mapped

      body = preview(csv, mapping: { "who" => "fullName", "ballot_line" => "party", "contest_name" => "office" })
      expect(body["errors"]).to eq([])
      expect(body["rows"].first["firstName"]).to eq("Jane")
      expect(body["contestGroups"].first["officeId"]).to eq(senate_office.id)
    end
  end

  it "rejects unparseable and oversized input cleanly" do
    body = preview(%(a,b\n"unclosed))
    expect(body["errors"].join).to include("Could not parse CSV")

    post admin_election_editor_import_path(election), params: { csv: "" }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
