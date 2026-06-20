require 'rails_helper'

RSpec.describe Candidate, type: :model do
  # Build the minimal contest graph an outcome test needs.
  def primary_contest
    office = Office.create!(title: "Governor", level: "state", branch: "executive", state: "NY")
    ballot = Ballot.create!(state: "NY", date: Date.new(2026, 6, 23), election_type: "primary",
                            party: "Democratic", year: 2026)
    Contest.create!(office: office, ballot: ballot, date: ballot.date,
                    party: "Democratic", contest_type: "primary")
  end

  describe "outcomes" do
    it "accepts 'advanced' (unopposed/cancelled primary)" do
      c = Candidate.new(person: create(:person), contest: primary_contest, outcome: "advanced")
      expect(c).to be_valid
    end
  end

  describe "winner semantics for 'advanced'" do
    let(:contest) { primary_contest }
    let!(:candidate) { Candidate.create!(person: create(:person), contest: contest, outcome: "advanced") }

    it "is not a literal win but counts as the nominee" do
      expect(candidate.won?).to be(false)
      expect(candidate.advanced?).to be(true)
      expect(candidate.winner?).to be(true)
    end

    it "is included in the winners scope" do
      expect(Candidate.winners).to include(candidate)
    end

    it "is surfaced as the contest winner" do
      expect(contest.winner).to eq(candidate.person)
      expect(contest.winners).to include(candidate.person)
      expect(contest.decided?).to be(true)
    end

    it "is counted among election winners for the year (feeds the primary→general pipeline)" do
      expect(Person.election_winners_in_year(2026)).to include(candidate.person)
    end
  end
end
