require 'rails_helper'

RSpec.describe "Public search", type: :request do
  let!(:himes) { Person.create!(first_name: "Jim", last_name: "Himes", state_of_residence: "CT") }
  let!(:other) { Person.create!(first_name: "Ann", last_name: "Other") }

  it "finds people by substring and by close spelling" do
    get search_path(q: "hime")
    expect(response.body).to include("Jim Himes")
    expect(response.body).not_to include("Ann Other")

    get search_path(q: "jim hymes")
    expect(response.body).to include("Jim Himes")
  end

  it "treats LIKE wildcards in the query as plain text" do
    get search_path(q: "%%")
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Jim Himes")
  end

  it "finds states" do
    State.create!(name: "Connecticut", abbreviation: "CT")
    get search_path(q: "connect")
    expect(response.body).to include(state_path("CT"))
  end

  it "resolves seat shorthand like TX-8 to the 2026 race" do
    ballot = Ballot.create!(state: "TX", date: Date.new(2026, 11, 3), election_type: "general", year: 2026)
    district = District.create!(state: "TX", district_number: 8, level: "federal")
    office = Office.create!(title: "U.S. Representative", office_category: "U.S. Representative",
                            level: "federal", branch: "legislative", state: "TX", district: district)
    contest = Contest.create!(ballot: ballot, office: office, date: Date.new(2026, 11, 3), contest_type: "general")

    get search_path(q: "tx 8")
    expect(response.body).to include(contest_path(contest))
  end

  it "keeps the people index name search on the same matcher" do
    get people_path(q: "himes")
    expect(response.body).to include("Jim Himes")
    expect(response.body).not_to include("Ann Other")
  end
end
