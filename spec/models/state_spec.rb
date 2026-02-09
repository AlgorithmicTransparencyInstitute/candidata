require 'rails_helper'

RSpec.describe State, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:abbreviation) }

    it 'validates uniqueness of name' do
      create(:state, name: 'California', abbreviation: 'CA')
      expect(build(:state, name: 'California', abbreviation: 'XX')).not_to be_valid
    end

    it 'validates uniqueness of abbreviation' do
      create(:state, name: 'California', abbreviation: 'CA')
      expect(build(:state, name: 'Other', abbreviation: 'CA')).not_to be_valid
    end
  end

  describe 'scopes' do
    describe '.states / .territories / .federal_district' do
      it 'filters by state_type' do
        state = create(:state, state_type: 'state')
        territory = create(:state, :territory)
        dc = create(:state, :federal_district)

        expect(State.states).to include(state)
        expect(State.territories).to include(territory)
        expect(State.federal_district).to include(dc)
      end
    end
  end

  describe '.find_by_abbrev' do
    it 'finds by abbreviation' do
      ca = create(:state, name: 'California', abbreviation: 'CA')
      expect(State.find_by_abbrev('CA')).to eq(ca)
    end

    it 'converts to uppercase' do
      ca = create(:state, name: 'California', abbreviation: 'CA')
      expect(State.find_by_abbrev('ca')).to eq(ca)
    end

    it 'returns nil for non-existent abbreviation' do
      expect(State.find_by_abbrev('ZZ')).to be_nil
    end
  end

  describe '#territory?' do
    it 'returns true for territories' do
      expect(build(:state, state_type: 'territory').territory?).to be true
    end

    it 'returns false for states' do
      expect(build(:state, state_type: 'state').territory?).to be false
    end
  end

  describe '#federal_district?' do
    it 'returns true for federal district' do
      expect(build(:state, state_type: 'federal_district').federal_district?).to be true
    end

    it 'returns false for states' do
      expect(build(:state, state_type: 'state').federal_district?).to be false
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      state = create(:state)
      state.update!(fips_code: '99')

      expect(state.versions.count).to eq(2)
    end
  end
end
