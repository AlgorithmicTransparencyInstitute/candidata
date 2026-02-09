require 'rails_helper'

RSpec.describe Party, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:affiliated_people).class_name('Person') }
    it { is_expected.to have_many(:person_parties).dependent(:destroy) }
    it { is_expected.to have_many(:people).through(:person_parties) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:abbreviation) }

    it 'validates uniqueness of name' do
      create(:party, name: 'Unique Party')
      expect(build(:party, name: 'Unique Party')).not_to be_valid
    end

    it 'validates uniqueness of abbreviation' do
      create(:party, abbreviation: 'UP')
      expect(build(:party, abbreviation: 'UP')).not_to be_valid
    end
  end

  describe 'scopes' do
    describe '.major / .minor' do
      it 'distinguishes major and minor parties' do
        dem = create(:party, :democratic)
        rep = create(:party, :republican)
        green = create(:party, name: 'Green Party', abbreviation: 'GRN')

        expect(Party.major).to include(dem, rep)
        expect(Party.major).not_to include(green)
        expect(Party.minor).to include(green)
        expect(Party.minor).not_to include(dem, rep)
      end
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      party = create(:party)
      party.update!(ideology: 'center')

      expect(party.versions.count).to eq(2)
    end
  end
end
