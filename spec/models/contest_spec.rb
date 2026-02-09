require 'rails_helper'

RSpec.describe Contest, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:office) }
    it { is_expected.to belong_to(:ballot) }
    it { is_expected.to have_many(:candidates).dependent(:destroy) }
    it { is_expected.to have_many(:people).through(:candidates) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:contest_type) }
    it { is_expected.to validate_inclusion_of(:contest_type).in_array(%w[primary general special runoff]) }

    it 'validates party inclusion when present' do
      valid_parties = %w[Democratic Republican Libertarian Independent] + ['Working Class']
      valid_parties.each do |party|
        expect(build(:contest, party: party)).to be_valid
      end
    end

    it 'allows nil party for non-primary contests' do
      expect(build(:contest, contest_type: 'general', party: nil)).to be_valid
    end

    it 'requires party for primary contests' do
      contest = build(:contest, contest_type: 'primary', party: nil)
      expect(contest).not_to be_valid
      expect(contest.errors[:party]).to be_present
    end

    it 'rejects invalid party' do
      expect(build(:contest, party: 'Green')).not_to be_valid
    end
  end

  describe 'constants' do
    it 'defines CONTEST_TYPES' do
      expect(Contest::CONTEST_TYPES).to eq(%w[primary general special runoff])
    end
  end

  describe 'scopes' do
    describe '.primary / .general / .special / .runoff' do
      it 'filters by contest_type' do
        primary = create(:contest, :primary)
        general = create(:contest, contest_type: 'general')

        expect(Contest.primary).to include(primary)
        expect(Contest.general).to include(general)
      end
    end

    describe '.for_year' do
      it 'returns contests in a specific year' do
        contest_2024 = create(:contest, date: Date.new(2024, 11, 5))
        contest_2022 = create(:contest, date: Date.new(2022, 11, 8))

        expect(Contest.for_year(2024)).to include(contest_2024)
        expect(Contest.for_year(2024)).not_to include(contest_2022)
      end
    end

    describe '.for_office' do
      it 'filters by office' do
        office = create(:office)
        matching = create(:contest, office: office)
        other = create(:contest)

        expect(Contest.for_office(office)).to include(matching)
        expect(Contest.for_office(office)).not_to include(other)
      end
    end
  end

  describe '#full_name' do
    it 'builds a descriptive name' do
      ballot = create(:ballot, state: 'CA', year: 2024, election_type: 'general')
      office = create(:office, title: 'Governor')
      contest = create(:contest, ballot: ballot, office: office, contest_type: 'general', date: Date.new(2024, 11, 5))

      expect(contest.full_name).to include('2024')
      expect(contest.full_name).to include('CA')
      expect(contest.full_name).to include('General')
    end

    it 'includes party for primary contests' do
      ballot = create(:ballot, :primary, state: 'TX')
      contest = create(:contest, ballot: ballot, contest_type: 'primary', party: 'Democratic', date: Date.new(2024, 3, 5))

      expect(contest.full_name).to include('Democratic')
    end
  end

  describe '#winner' do
    it 'returns the winning person' do
      contest = create(:contest)
      winner_person = create(:person)
      create(:candidate, contest: contest, person: winner_person, outcome: 'won')
      create(:candidate, contest: contest, person: create(:person), outcome: 'lost')

      expect(contest.winner).to eq(winner_person)
    end

    it 'returns nil when no winner' do
      contest = create(:contest)
      create(:candidate, contest: contest, outcome: 'pending')

      expect(contest.winner).to be_nil
    end
  end

  describe '#winners' do
    it 'returns all winning people' do
      contest = create(:contest)
      winner1 = create(:person)
      winner2 = create(:person)
      create(:candidate, contest: contest, person: winner1, outcome: 'won')
      create(:candidate, contest: contest, person: winner2, outcome: 'won')

      expect(contest.winners).to contain_exactly(winner1, winner2)
    end
  end

  describe '#total_votes' do
    it 'sums all candidate tallies' do
      contest = create(:contest)
      create(:candidate, contest: contest, tally: 100)
      create(:candidate, contest: contest, person: create(:person), tally: 200)

      expect(contest.total_votes).to eq(300)
    end

    it 'returns 0 when no candidates' do
      contest = create(:contest)
      expect(contest.total_votes).to eq(0)
    end
  end

  describe '#decided?' do
    it 'returns true when a winner exists' do
      contest = create(:contest)
      create(:candidate, contest: contest, outcome: 'won')

      expect(contest.decided?).to be true
    end

    it 'returns false when no winner' do
      contest = create(:contest)
      create(:candidate, contest: contest, outcome: 'pending')

      expect(contest.decided?).to be false
    end
  end

  describe 'delegation' do
    it 'delegates state, election_type, and year to ballot' do
      ballot = create(:ballot, state: 'NY', election_type: 'general', year: 2024)
      contest = create(:contest, ballot: ballot)

      expect(contest.state).to eq('NY')
      expect(contest.election_type).to eq('general')
      expect(contest.year).to eq(2024)
    end
  end
end
