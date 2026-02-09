require 'rails_helper'

RSpec.describe PersonParty, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:person) }
    it { is_expected.to belong_to(:party) }
  end

  describe 'validations' do
    it 'validates uniqueness of person_id scoped to party_id' do
      person = create(:person)
      party = create(:party)
      create(:person_party, person: person, party: party)

      duplicate = build(:person_party, person: person, party: party)
      expect(duplicate).not_to be_valid
    end

    it 'allows same person with different parties' do
      person = create(:person)
      party1 = create(:party, name: 'Party A', abbreviation: 'PA')
      party2 = create(:party, name: 'Party B', abbreviation: 'PB')
      create(:person_party, person: person, party: party1)

      different = build(:person_party, person: person, party: party2)
      expect(different).to be_valid
    end

    describe 'only_one_primary_per_person' do
      it 'prevents multiple primary parties for the same person' do
        person = create(:person)
        party1 = create(:party, name: 'Party 1', abbreviation: 'P1')
        party2 = create(:party, name: 'Party 2', abbreviation: 'P2')
        create(:person_party, person: person, party: party1, is_primary: true)

        duplicate_primary = build(:person_party, person: person, party: party2, is_primary: true)
        expect(duplicate_primary).not_to be_valid
        expect(duplicate_primary.errors[:is_primary]).to be_present
      end

      it 'allows non-primary parties alongside a primary' do
        person = create(:person)
        party1 = create(:party, name: 'Primary', abbreviation: 'PRI')
        party2 = create(:party, name: 'Secondary', abbreviation: 'SEC')
        create(:person_party, person: person, party: party1, is_primary: true)

        non_primary = build(:person_party, person: person, party: party2, is_primary: false)
        expect(non_primary).to be_valid
      end

      it 'allows different people to each have a primary party' do
        party = create(:party)
        create(:person_party, person: create(:person), party: party, is_primary: true)

        other_primary = build(:person_party, person: create(:person), party: party, is_primary: true)
        expect(other_primary).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.primary' do
      it 'returns only primary party affiliations' do
        primary = create(:person_party, :primary)
        secondary = create(:person_party, is_primary: false)

        expect(PersonParty.primary).to include(primary)
        expect(PersonParty.primary).not_to include(secondary)
      end
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      pp = create(:person_party, is_primary: false)
      # Must first remove any existing primary before making this one primary
      pp.update!(is_primary: true)

      expect(pp.versions.count).to eq(2)
    end
  end
end
