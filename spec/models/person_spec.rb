require 'rails_helper'

RSpec.describe Person, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:party_affiliation).class_name('Party').optional }
    it { is_expected.to have_many(:person_parties).dependent(:destroy) }
    it { is_expected.to have_many(:parties).through(:person_parties) }
    it { is_expected.to have_many(:candidates) }
    it { is_expected.to have_many(:contests).through(:candidates) }
    it { is_expected.to have_many(:officeholders) }
    it { is_expected.to have_many(:offices).through(:officeholders) }
    it { is_expected.to have_many(:social_media_accounts).dependent(:destroy) }
    it { is_expected.to have_many(:assignments).dependent(:destroy) }
    it { is_expected.to have_many(:assigned_researchers).through(:assignments).source(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }

    it 'validates uniqueness of person_uuid allowing nil' do
      create(:person, :with_uuid)
      person = build(:person, person_uuid: Person.last.person_uuid)
      expect(person).not_to be_valid
      expect(person.errors[:person_uuid]).to be_present
    end

    it 'allows nil person_uuid' do
      person = build(:person, person_uuid: nil)
      expect(person).to be_valid
    end

    it 'validates uniqueness of airtable_id allowing nil' do
      create(:person, :with_airtable_id)
      person = build(:person, airtable_id: Person.last.airtable_id)
      expect(person).not_to be_valid
    end

    it 'validates gender inclusion' do
      expect(build(:person, gender: 'Male')).to be_valid
      expect(build(:person, gender: 'Female')).to be_valid
      expect(build(:person, gender: 'Other')).to be_valid
      expect(build(:person, gender: nil)).to be_valid
      expect(build(:person, gender: '')).to be_valid
      expect(build(:person, gender: 'Unknown')).not_to be_valid
    end
  end

  describe 'constants' do
    it 'defines GENDERS' do
      expect(Person::GENDERS).to eq(%w[Male Female Other])
    end

    it 'defines SUFFIXES' do
      expect(Person::SUFFIXES).to eq(%w[Jr. Sr. II III IV V])
    end
  end

  describe '#full_name' do
    it 'returns first and last name' do
      person = build(:person, first_name: 'John', last_name: 'Doe', middle_name: nil, suffix: nil)
      expect(person.full_name).to eq('John Doe')
    end

    it 'includes middle name when present' do
      person = build(:person, first_name: 'John', middle_name: 'Michael', last_name: 'Doe', suffix: nil)
      expect(person.full_name).to eq('John Michael Doe')
    end

    it 'includes suffix when present' do
      person = build(:person, first_name: 'John', last_name: 'Doe', middle_name: nil, suffix: 'Jr.')
      expect(person.full_name).to eq('John Doe Jr.')
    end

    it 'includes all parts when present' do
      person = build(:person, first_name: 'John', middle_name: 'Michael', last_name: 'Doe', suffix: 'III')
      expect(person.full_name).to eq('John Michael Doe III')
    end

    it 'skips blank parts' do
      person = build(:person, first_name: 'John', middle_name: '', last_name: 'Doe', suffix: '')
      expect(person.full_name).to eq('John Doe')
    end
  end

  describe '#formal_name' do
    it 'returns first and last name without suffix' do
      person = build(:person, first_name: 'Jane', last_name: 'Smith', suffix: nil)
      expect(person.formal_name).to eq('Jane Smith')
    end

    it 'appends suffix with comma' do
      person = build(:person, first_name: 'John', last_name: 'Doe', suffix: 'Jr.')
      expect(person.formal_name).to eq('John Doe, Jr.')
    end
  end

  describe '#primary_party' do
    it 'returns the primary party from person_parties' do
      person = create(:person)
      party = create(:party)
      create(:person_party, person: person, party: party, is_primary: true)

      expect(person.primary_party).to eq(party)
    end

    it 'falls back to legacy party_affiliation' do
      legacy_party = create(:party)
      person = create(:person, party_affiliation: legacy_party)

      expect(person.primary_party).to eq(legacy_party)
    end

    it 'prefers person_parties over legacy affiliation' do
      legacy_party = create(:party, name: 'Legacy Party', abbreviation: 'LEG')
      new_party = create(:party, name: 'New Party', abbreviation: 'NEW')
      person = create(:person, party_affiliation: legacy_party)
      create(:person_party, person: person, party: new_party, is_primary: true)

      expect(person.primary_party).to eq(new_party)
    end

    it 'returns nil when no party' do
      person = create(:person)
      expect(person.primary_party).to be_nil
    end
  end

  describe '#primary_party=' do
    it 'sets a new primary party' do
      person = create(:person)
      party = create(:party)

      person.primary_party = party

      expect(person.primary_party).to eq(party)
      expect(person.person_parties.find_by(party: party).is_primary).to be true
    end

    it 'clears existing primary when setting a new one' do
      person = create(:person)
      old_party = create(:party, name: 'Old Party', abbreviation: 'OLD')
      new_party = create(:party, name: 'New Party', abbreviation: 'NEW')
      create(:person_party, person: person, party: old_party, is_primary: true)

      person.primary_party = new_party

      expect(person.person_parties.find_by(party: old_party).is_primary).to be false
      expect(person.person_parties.find_by(party: new_party).is_primary).to be true
    end

    it 'handles nil to clear primary' do
      person = create(:person)
      party = create(:party)
      create(:person_party, person: person, party: party, is_primary: true)

      person.primary_party = nil

      expect(person.person_parties.where(is_primary: true)).to be_empty
    end
  end

  describe '#add_party' do
    it 'adds a party as non-primary by default' do
      person = create(:person)
      party = create(:party)

      pp = person.add_party(party)

      expect(pp.is_primary).to be false
      expect(person.parties).to include(party)
    end

    it 'adds a party as primary when specified' do
      person = create(:person)
      party = create(:party)

      pp = person.add_party(party, is_primary: true)

      expect(pp.is_primary).to be true
    end

    it 'clears other primaries when adding a new primary' do
      person = create(:person)
      party1 = create(:party, name: 'Party 1', abbreviation: 'P1')
      party2 = create(:party, name: 'Party 2', abbreviation: 'P2')
      person.add_party(party1, is_primary: true)

      person.add_party(party2, is_primary: true)

      expect(person.person_parties.find_by(party: party1).is_primary).to be false
      expect(person.person_parties.find_by(party: party2).is_primary).to be true
    end

    it 'does not duplicate party membership' do
      person = create(:person)
      party = create(:party)
      person.add_party(party)

      expect { person.add_party(party) }.not_to change { person.person_parties.count }
    end
  end

  describe 'scopes' do
    describe '.current_officeholders' do
      it 'returns people currently in office' do
        current_person = create(:person)
        create(:officeholder, person: current_person, end_date: nil)
        former_person = create(:person)
        create(:officeholder, person: former_person, end_date: 1.year.ago.to_date)

        expect(Person.current_officeholders).to include(current_person)
        expect(Person.current_officeholders).not_to include(former_person)
      end
    end

    describe '.former_officeholders' do
      it 'returns people no longer in office' do
        current_person = create(:person)
        create(:officeholder, person: current_person, end_date: nil)
        former_person = create(:person)
        create(:officeholder, person: former_person, end_date: 1.year.ago.to_date)

        expect(Person.former_officeholders).to include(former_person)
        expect(Person.former_officeholders).not_to include(current_person)
      end
    end

    describe '.officeholders_as_of' do
      it 'returns people in office on a specific date' do
        person = create(:person)
        create(:officeholder,
               person: person,
               start_date: Date.new(2022, 1, 1),
               end_date: Date.new(2026, 1, 1))

        expect(Person.officeholders_as_of(Date.new(2024, 6, 1))).to include(person)
        expect(Person.officeholders_as_of(Date.new(2021, 12, 31))).not_to include(person)
        expect(Person.officeholders_as_of(Date.new(2027, 1, 1))).not_to include(person)
      end
    end

    describe '.by_state' do
      it 'filters by state of residence' do
        ca_person = create(:person, state_of_residence: 'CA')
        tx_person = create(:person, state_of_residence: 'TX')

        expect(Person.by_state('CA')).to include(ca_person)
        expect(Person.by_state('CA')).not_to include(tx_person)
      end
    end

    describe '.by_party' do
      it 'filters by party' do
        party = create(:party)
        member = create(:person)
        create(:person_party, person: member, party: party)
        non_member = create(:person)

        expect(Person.by_party(party)).to include(member)
        expect(Person.by_party(party)).not_to include(non_member)
      end
    end
  end

  describe '#current_officeholder?' do
    it 'returns true when person has current officeholder record' do
      person = create(:person)
      create(:officeholder, person: person, end_date: nil)

      expect(person.current_officeholder?).to be true
    end

    it 'returns false when person has no officeholder records' do
      person = create(:person)

      expect(person.current_officeholder?).to be false
    end

    it 'returns false when all officeholder records are former' do
      person = create(:person)
      create(:officeholder, person: person, end_date: 1.year.ago.to_date)

      expect(person.current_officeholder?).to be false
    end
  end

  describe '#officeholder_on?' do
    it 'returns true when person was in office on the date' do
      person = create(:person)
      create(:officeholder,
             person: person,
             start_date: Date.new(2020, 1, 1),
             end_date: Date.new(2024, 12, 31))

      expect(person.officeholder_on?(Date.new(2022, 6, 1))).to be true
    end

    it 'returns false when person was not in office on the date' do
      person = create(:person)
      create(:officeholder,
             person: person,
             start_date: Date.new(2020, 1, 1),
             end_date: Date.new(2024, 12, 31))

      expect(person.officeholder_on?(Date.new(2019, 12, 31))).to be false
    end
  end

  describe '#current_offices' do
    it 'returns offices currently held' do
      person = create(:person)
      current_office = create(:office, title: 'Current Office')
      former_office = create(:office, title: 'Former Office')
      create(:officeholder, person: person, office: current_office, end_date: nil)
      create(:officeholder, person: person, office: former_office, end_date: 1.year.ago.to_date)

      expect(person.current_offices).to include(current_office)
      expect(person.current_offices).not_to include(former_office)
    end
  end

  describe '#offices_held_on' do
    it 'returns offices held on a specific date' do
      person = create(:person)
      office = create(:office)
      create(:officeholder,
             person: person,
             office: office,
             start_date: Date.new(2020, 1, 1),
             end_date: Date.new(2024, 12, 31))

      expect(person.offices_held_on(Date.new(2022, 6, 1))).to include(office)
      expect(person.offices_held_on(Date.new(2025, 6, 1))).not_to include(office)
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      person = create(:person, first_name: 'John')
      person.update!(first_name: 'Jane')

      expect(person.versions.count).to eq(2)
    end
  end
end
