require 'rails_helper'

RSpec.describe Ballot, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:election).optional }
    it { is_expected.to have_many(:contests).dependent(:destroy) }
    it { is_expected.to have_many(:offices).through(:contests) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:election_type) }
    it { is_expected.to validate_inclusion_of(:election_type).in_array(%w[primary general special runoff]) }
    it { is_expected.to validate_presence_of(:year) }

    it 'validates party inclusion when present' do
      valid = %w[Democratic Republican Libertarian Independent] + ['Working Class']
      valid.each do |party|
        expect(build(:ballot, party: party)).to be_valid
      end
    end

    it 'allows nil party for non-primary' do
      expect(build(:ballot, election_type: 'general', party: nil)).to be_valid
    end

    it 'requires party for primary ballots' do
      ballot = build(:ballot, election_type: 'primary', party: nil)
      expect(ballot).not_to be_valid
    end
  end

  describe 'constants' do
    it 'defines ELECTION_TYPES' do
      expect(Ballot::ELECTION_TYPES).to eq(%w[primary general special runoff])
    end
  end

  describe 'callbacks' do
    describe 'set_year_from_date' do
      it 'auto-sets year from date when year is nil' do
        ballot = build(:ballot, date: Date.new(2024, 11, 5), year: nil)
        ballot.valid?

        expect(ballot.year).to eq(2024)
      end

      it 'does not overwrite existing year' do
        ballot = build(:ballot, date: Date.new(2024, 11, 5), year: 2023)
        ballot.valid?

        expect(ballot.year).to eq(2023)
      end
    end
  end

  describe 'scopes' do
    describe '.primary / .general / .special / .runoff' do
      it 'filters by election_type' do
        primary = create(:ballot, :primary)
        general = create(:ballot, election_type: 'general')

        expect(Ballot.primary).to include(primary)
        expect(Ballot.general).to include(general)
      end
    end

    describe '.for_year' do
      it 'filters by year' do
        b2024 = create(:ballot, year: 2024)
        b2022 = create(:ballot, year: 2022)

        expect(Ballot.for_year(2024)).to include(b2024)
        expect(Ballot.for_year(2024)).not_to include(b2022)
      end
    end

    describe '.for_state' do
      it 'filters by state' do
        ca = create(:ballot, state: 'CA')
        tx = create(:ballot, state: 'TX')

        expect(Ballot.for_state('CA')).to include(ca)
        expect(Ballot.for_state('CA')).not_to include(tx)
      end
    end

    describe '.for_party' do
      it 'filters by party' do
        dem = create(:ballot, :primary, party: 'Democratic')
        rep = create(:ballot, :primary, party: 'Republican', state: 'TX')

        expect(Ballot.for_party('Democratic')).to include(dem)
        expect(Ballot.for_party('Democratic')).not_to include(rep)
      end
    end
  end

  describe '#full_name' do
    it 'returns the name if present' do
      ballot = build(:ballot, name: 'Custom Ballot Name')
      expect(ballot.full_name).to eq('Custom Ballot Name')
    end

    it 'builds name from components when name is blank' do
      ballot = build(:ballot, name: nil, year: 2024, state: 'CA', election_type: 'general')
      expect(ballot.full_name).to eq('2024 CA General')
    end

    it 'includes party for primary ballots' do
      ballot = build(:ballot, name: nil, year: 2024, state: 'TX', election_type: 'primary', party: 'Democratic')
      expect(ballot.full_name).to eq('2024 TX Democratic Primary')
    end
  end
end
