require 'rails_helper'

RSpec.describe Election, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:ballots).dependent(:nullify) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:election_type) }
    it { is_expected.to validate_inclusion_of(:election_type).in_array(%w[primary general special]) }
    it { is_expected.to validate_presence_of(:year) }
  end

  describe 'callbacks' do
    describe 'set_year_from_date' do
      it 'auto-sets year from date when year is blank' do
        election = build(:election, date: Date.new(2024, 11, 5), year: nil)
        election.valid?

        expect(election.year).to eq(2024)
      end

      it 'does not overwrite existing year' do
        election = build(:election, date: Date.new(2024, 11, 5), year: 2023)
        election.valid?

        expect(election.year).to eq(2023)
      end

      it 'does not run when date is blank' do
        election = build(:election, date: nil, year: nil)
        election.valid?

        expect(election.year).to be_nil
      end
    end
  end

  describe 'scopes' do
    describe '.primaries / .generals' do
      it 'filters by election_type' do
        primary = create(:election, :primary)
        general = create(:election, election_type: 'general')

        expect(Election.primaries).to include(primary)
        expect(Election.generals).to include(general)
      end
    end

    describe '.by_year' do
      it 'filters by year' do
        e2024 = create(:election, year: 2024)
        e2022 = create(:election, year: 2022)

        expect(Election.by_year(2024)).to include(e2024)
        expect(Election.by_year(2024)).not_to include(e2022)
      end
    end

    describe '.by_state' do
      it 'filters by state' do
        ca = create(:election, state: 'CA')
        tx = create(:election, state: 'TX')

        expect(Election.by_state('CA')).to include(ca)
        expect(Election.by_state('CA')).not_to include(tx)
      end
    end

    describe '.upcoming / .past' do
      it 'filters by date relative to today' do
        upcoming = create(:election, :upcoming)
        past = create(:election, :past)

        expect(Election.upcoming).to include(upcoming)
        expect(Election.upcoming).not_to include(past)
        expect(Election.past).to include(past)
        expect(Election.past).not_to include(upcoming)
      end
    end
  end

  describe '#full_name' do
    it 'returns name if present' do
      election = build(:election, name: 'Custom Election')
      expect(election.full_name).to eq('Custom Election')
    end

    it 'builds name from components when name is blank' do
      election = build(:election, name: nil, state: 'CA', election_type: 'general', year: 2024)
      expect(election.full_name).to eq('CA General 2024')
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      election = create(:election)
      election.update!(name: 'Updated')

      expect(election.versions.count).to eq(2)
    end
  end
end
