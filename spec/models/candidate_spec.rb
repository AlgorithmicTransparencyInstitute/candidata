require 'rails_helper'

RSpec.describe Candidate, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:person) }
    it { is_expected.to belong_to(:contest) }
  end

  describe 'validations' do
    it 'validates outcome inclusion' do
      %w[won lost pending withdrawn unknown].each do |outcome|
        expect(build(:candidate, outcome: outcome)).to be_valid
      end
    end

    it 'allows blank outcome' do
      expect(build(:candidate, outcome: '')).to be_valid
    end

    it 'rejects invalid outcome' do
      expect(build(:candidate, outcome: 'disqualified')).not_to be_valid
    end

    it 'validates tally is non-negative' do
      expect(build(:candidate, tally: 0)).to be_valid
      expect(build(:candidate, tally: 100)).to be_valid
      expect(build(:candidate, tally: -1)).not_to be_valid
    end

    it 'allows nil tally' do
      expect(build(:candidate, tally: nil)).to be_valid
    end

    it 'validates uniqueness of airtable_id allowing nil' do
      create(:candidate, airtable_id: 'rec123')
      expect(build(:candidate, airtable_id: 'rec123')).not_to be_valid
      expect(build(:candidate, airtable_id: nil)).to be_valid
    end
  end

  describe 'scopes' do
    describe '.winners / .losers / .pending' do
      it 'filters by outcome' do
        winner = create(:candidate, :winner)
        loser = create(:candidate, :loser)
        pending = create(:candidate, outcome: 'pending')

        expect(Candidate.winners).to include(winner)
        expect(Candidate.losers).to include(loser)
        expect(Candidate.pending).to include(pending)
      end
    end

    describe '.incumbents / .challengers' do
      it 'filters by incumbent flag' do
        incumbent = create(:candidate, :incumbent)
        challenger = create(:candidate, incumbent: false)

        expect(Candidate.incumbents).to include(incumbent)
        expect(Candidate.challengers).to include(challenger)
      end
    end

    describe '.for_year' do
      it 'filters by contest year' do
        ballot = create(:ballot, date: Date.new(2024, 11, 5), year: 2024)
        contest_2024 = create(:contest, date: Date.new(2024, 11, 5), ballot: ballot)
        candidate_2024 = create(:candidate, contest: contest_2024)

        expect(Candidate.for_year(2024)).to include(candidate_2024)
        expect(Candidate.for_year(2022)).not_to include(candidate_2024)
      end
    end
  end

  describe '#vote_percentage' do
    it 'calculates percentage of total votes' do
      contest = create(:contest)
      create(:candidate, contest: contest, outcome: 'won', tally: 60)
      candidate = create(:candidate, contest: contest, person: create(:person), outcome: 'lost', tally: 40)

      expect(candidate.vote_percentage).to eq(40.0)
    end

    it 'returns 0 when contest has no votes' do
      contest = create(:contest)
      candidate = create(:candidate, contest: contest, tally: 0)

      expect(candidate.vote_percentage).to eq(0)
    end

    it 'returns 0 when tally is nil' do
      contest = create(:contest)
      candidate = create(:candidate, contest: contest, tally: nil)

      expect(candidate.vote_percentage).to eq(0)
    end
  end

  describe '#won? / #lost?' do
    it 'returns correct boolean for outcome' do
      expect(build(:candidate, outcome: 'won').won?).to be true
      expect(build(:candidate, outcome: 'won').lost?).to be false
      expect(build(:candidate, outcome: 'lost').lost?).to be true
      expect(build(:candidate, outcome: 'lost').won?).to be false
    end
  end

  describe 'delegation' do
    it 'delegates office to contest' do
      office = create(:office)
      contest = create(:contest, office: office)
      candidate = create(:candidate, contest: contest)

      expect(candidate.office).to eq(office)
    end

    it 'delegates ballot to contest' do
      ballot = create(:ballot)
      contest = create(:contest, ballot: ballot)
      candidate = create(:candidate, contest: contest)

      expect(candidate.ballot).to eq(ballot)
    end
  end
end
