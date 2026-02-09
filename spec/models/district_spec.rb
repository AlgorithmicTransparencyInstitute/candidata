require 'rails_helper'

RSpec.describe District, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:offices) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:level) }

    it 'validates chamber inclusion' do
      expect(build(:district, chamber: 'upper')).to be_valid
      expect(build(:district, chamber: 'lower')).to be_valid
      expect(build(:district, chamber: nil)).to be_valid
      expect(build(:district, chamber: 'middle')).not_to be_valid
    end

    it 'validates district_number uniqueness scoped to state, level, chamber' do
      create(:district, state: 'CA', level: 'federal', district_number: 1, chamber: nil)
      duplicate = build(:district, state: 'CA', level: 'federal', district_number: 1, chamber: nil)
      expect(duplicate).not_to be_valid
    end

    it 'allows same district_number in different states' do
      create(:district, state: 'CA', level: 'federal', district_number: 1)
      different_state = build(:district, state: 'TX', level: 'federal', district_number: 1)
      expect(different_state).to be_valid
    end

    it 'validates ocdid uniqueness allowing nil' do
      create(:district, ocdid: 'ocd-division/country:us/state:ca/cd:1')
      expect(build(:district, ocdid: 'ocd-division/country:us/state:ca/cd:1')).not_to be_valid
      expect(build(:district, ocdid: nil)).to be_valid
    end
  end

  describe 'constants' do
    it 'defines CHAMBERS' do
      expect(District::CHAMBERS).to eq(%w[upper lower])
    end

    it 'defines VOTING_AT_LARGE_STATES' do
      expect(District::VOTING_AT_LARGE_STATES).to eq(%w[AK DE ND SD VT WY])
    end

    it 'defines TERRITORY_DELEGATES' do
      expect(District::TERRITORY_DELEGATES).to eq(%w[AS DC GU MP PR VI])
    end
  end

  describe 'scopes' do
    describe '.federal / .state_level / .local' do
      it 'filters by level' do
        federal = create(:district, level: 'federal')
        state = create(:district, level: 'state', chamber: 'upper')
        local = create(:district, level: 'local')

        expect(District.federal).to include(federal)
        expect(District.state_level).to include(state)
        expect(District.local).to include(local)
      end
    end

    describe '.upper_chamber / .lower_chamber' do
      it 'filters by chamber' do
        upper = create(:district, level: 'state', chamber: 'upper')
        lower = create(:district, level: 'state', chamber: 'lower')

        expect(District.upper_chamber).to include(upper)
        expect(District.lower_chamber).to include(lower)
      end
    end

    describe '.at_large' do
      it 'returns federal districts with district_number 0' do
        at_large = create(:district, level: 'federal', district_number: 0, state: 'AK')
        numbered = create(:district, level: 'federal', district_number: 5, state: 'CA')

        expect(District.at_large).to include(at_large)
        expect(District.at_large).not_to include(numbered)
      end
    end

    describe '.state_senate / .state_house' do
      it 'combines level and chamber filters' do
        senate = create(:district, level: 'state', chamber: 'upper')
        house = create(:district, level: 'state', chamber: 'lower')

        expect(District.state_senate).to include(senate)
        expect(District.state_house).to include(house)
      end
    end
  end

  describe '#full_name' do
    it 'returns federal congressional district name' do
      district = build(:district, level: 'federal', state: 'CA', district_number: 12, chamber: nil)
      expect(district.full_name).to eq('CA Congressional District 12')
    end

    it 'returns at-large name for district 0' do
      district = build(:district, level: 'federal', state: 'AK', district_number: 0)
      expect(district.full_name).to eq('AK At-Large')
    end

    it 'returns state senate district name' do
      district = build(:district, level: 'state', state: 'TX', district_number: 5, chamber: 'upper')
      expect(district.full_name).to eq('TX State Senate District 5')
    end

    it 'returns state house district name' do
      district = build(:district, level: 'state', state: 'NY', district_number: 10, chamber: 'lower')
      expect(district.full_name).to eq('NY State House District 10')
    end

    it 'returns generic local district name' do
      district = build(:district, level: 'local', state: 'FL', district_number: nil)
      expect(district.full_name).to eq('FL Local')
    end
  end
end
