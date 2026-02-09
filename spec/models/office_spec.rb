require 'rails_helper'

RSpec.describe Office, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:district).optional }
    it { is_expected.to belong_to(:body).optional }
    it { is_expected.to have_many(:contests) }
    it { is_expected.to have_many(:officeholders) }
    it { is_expected.to have_many(:people).through(:officeholders) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:level) }
    it { is_expected.to validate_inclusion_of(:level).in_array(%w[federal state local]) }
    it { is_expected.to validate_presence_of(:branch) }
    it { is_expected.to validate_inclusion_of(:branch).in_array(%w[legislative executive judicial]) }

    it 'validates role inclusion when present' do
      valid_roles = %w[headOfGovernment headOfState deputyHeadOfGovernment legislatorUpperBody legislatorLowerBody highestCourtJudge judge executiveCouncil governmentOfficer schoolBoard]
      valid_roles.each do |role|
        expect(build(:office, role: role)).to be_valid
      end
    end

    it 'allows blank role' do
      expect(build(:office, role: nil)).to be_valid
      expect(build(:office, role: '')).to be_valid
    end

    it 'rejects invalid roles' do
      expect(build(:office, role: 'president')).not_to be_valid
    end

    it 'validates uniqueness of airtable_id allowing nil' do
      create(:office, airtable_id: 'rec123')
      expect(build(:office, airtable_id: 'rec123')).not_to be_valid
      expect(build(:office, airtable_id: nil)).to be_valid
    end
  end

  describe 'constants' do
    it 'defines LEVELS' do
      expect(Office::LEVELS).to eq(%w[federal state local])
    end

    it 'defines BRANCHES' do
      expect(Office::BRANCHES).to eq(%w[legislative executive judicial])
    end

    it 'defines ROLES' do
      expect(Office::ROLES).to include('headOfGovernment', 'legislatorUpperBody', 'legislatorLowerBody')
    end
  end

  describe 'scopes' do
    describe '.federal / .state / .local' do
      it 'filters by level' do
        federal = create(:office, level: 'federal')
        state = create(:office, level: 'state')
        local = create(:office, level: 'local')

        expect(Office.federal).to include(federal)
        expect(Office.state).to include(state)
        expect(Office.local).to include(local)
      end
    end

    describe '.legislative / .executive / .judicial' do
      it 'filters by branch' do
        leg = create(:office, branch: 'legislative')
        exe = create(:office, branch: 'executive')
        jud = create(:office, branch: 'judicial')

        expect(Office.legislative).to include(leg)
        expect(Office.executive).to include(exe)
        expect(Office.judicial).to include(jud)
      end
    end

    describe '.by_category' do
      it 'filters by office_category' do
        senator = create(:office, office_category: 'U.S. Senator')
        rep = create(:office, office_category: 'U.S. Representative')

        expect(Office.by_category('U.S. Senator')).to include(senator)
        expect(Office.by_category('U.S. Senator')).not_to include(rep)
      end
    end

    describe '.by_body' do
      it 'filters by body_name' do
        senate = create(:office, body_name: 'U.S. Senate')
        house = create(:office, body_name: 'U.S. House')

        expect(Office.by_body('U.S. Senate')).to include(senate)
        expect(Office.by_body('U.S. Senate')).not_to include(house)
      end
    end
  end

  describe '#full_title' do
    it 'returns title alone when no seat or state' do
      office = build(:office, title: 'Governor', seat: nil, state: nil)
      expect(office.full_title).to eq('Governor')
    end

    it 'includes seat when present' do
      office = build(:office, title: 'U.S. Senator', seat: 'Seat 1', state: nil)
      expect(office.full_title).to eq('U.S. Senator - Seat 1')
    end

    it 'includes state when present and not already in title' do
      office = build(:office, title: 'Governor', seat: nil, state: 'CA')
      expect(office.full_title).to eq('Governor - CA')
    end

    it 'does not duplicate state if already in title' do
      office = build(:office, title: 'CA Governor', seat: nil, state: 'CA')
      expect(office.full_title).to eq('CA Governor')
    end
  end

  describe '#display_name' do
    it 'returns title with seat in parentheses' do
      office = build(:office, title: 'U.S. Senator', seat: 'Seat 2')
      expect(office.display_name).to eq('U.S. Senator (Seat 2)')
    end

    it 'returns title alone when no seat' do
      office = build(:office, title: 'Governor', seat: nil)
      expect(office.display_name).to eq('Governor')
    end
  end

  describe 'branch helper methods' do
    it '#legislative? returns true for legislative branch' do
      expect(build(:office, branch: 'legislative').legislative?).to be true
      expect(build(:office, branch: 'executive').legislative?).to be false
    end

    it '#executive? returns true for executive branch' do
      expect(build(:office, branch: 'executive').executive?).to be true
      expect(build(:office, branch: 'legislative').executive?).to be false
    end

    it '#judicial? returns true for judicial branch' do
      expect(build(:office, branch: 'judicial').judicial?).to be true
      expect(build(:office, branch: 'legislative').judicial?).to be false
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      office = create(:office, title: 'Original')
      office.update!(title: 'Updated')

      expect(office.versions.count).to eq(2)
    end
  end
end
