require 'rails_helper'

RSpec.describe Body, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:offices) }
    it { is_expected.to belong_to(:parent_body).class_name('Body').optional }
    it { is_expected.to have_many(:sub_bodies).class_name('Body') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    it 'validates name uniqueness scoped to country' do
      create(:body, name: 'U.S. Senate', country: 'US')
      duplicate = build(:body, name: 'U.S. Senate', country: 'US')
      expect(duplicate).not_to be_valid
    end

    it 'allows same name in different countries' do
      create(:body, name: 'Senate', country: 'US')
      different = build(:body, name: 'Senate', country: 'CA')
      expect(different).to be_valid
    end

    it 'validates level inclusion when present' do
      %w[federal state local].each do |level|
        expect(build(:body, level: level)).to be_valid
      end
      expect(build(:body, level: nil)).to be_valid
      expect(build(:body, level: '')).to be_valid
      expect(build(:body, level: 'regional')).not_to be_valid
    end

    it 'validates branch inclusion when present' do
      %w[legislative executive judicial].each do |branch|
        expect(build(:body, branch: branch)).to be_valid
      end
      expect(build(:body, branch: nil)).to be_valid
      expect(build(:body, branch: 'military')).not_to be_valid
    end

    it 'validates chamber_type inclusion when present' do
      %w[upper lower unicameral].each do |type|
        expect(build(:body, chamber_type: type)).to be_valid
      end
      expect(build(:body, chamber_type: nil)).to be_valid
      expect(build(:body, chamber_type: 'middle')).not_to be_valid
    end
  end

  describe 'constants' do
    it 'defines LEVELS' do
      expect(Body::LEVELS).to eq(%w[federal state local])
    end

    it 'defines BRANCHES' do
      expect(Body::BRANCHES).to eq(%w[legislative executive judicial])
    end

    it 'defines CHAMBER_TYPES' do
      expect(Body::CHAMBER_TYPES).to eq(%w[upper lower unicameral])
    end
  end

  describe 'scopes' do
    describe '.federal / .state_level / .local' do
      it 'filters by level' do
        federal = create(:body, level: 'federal')
        state = create(:body, level: 'state')
        local = create(:body, level: 'local')

        expect(Body.federal).to include(federal)
        expect(Body.state_level).to include(state)
        expect(Body.local).to include(local)
      end
    end

    describe '.legislative' do
      it 'returns legislative bodies' do
        leg = create(:body, branch: 'legislative')
        exe = create(:body, branch: 'executive')

        expect(Body.legislative).to include(leg)
        expect(Body.legislative).not_to include(exe)
      end
    end

    describe '.by_country' do
      it 'filters by country' do
        us = create(:body, country: 'US')
        ca = create(:body, country: 'CA')

        expect(Body.by_country('US')).to include(us)
        expect(Body.by_country('US')).not_to include(ca)
      end
    end

    describe '.by_state' do
      it 'filters by state' do
        tx = create(:body, state: 'TX')
        ny = create(:body, state: 'NY')

        expect(Body.by_state('TX')).to include(tx)
        expect(Body.by_state('TX')).not_to include(ny)
      end
    end
  end

  describe 'self-referential hierarchy' do
    it 'supports parent-child relationships' do
      congress = create(:body, name: 'U.S. Congress')
      senate = create(:body, name: 'U.S. Senate', parent_body: congress)
      house = create(:body, name: 'U.S. House', parent_body: congress)

      expect(congress.sub_bodies).to contain_exactly(senate, house)
      expect(senate.parent_body).to eq(congress)
      expect(house.parent_body).to eq(congress)
    end
  end

  describe '#display_name' do
    it 'returns the body name' do
      body = build(:body, name: 'U.S. Senate')
      expect(body.display_name).to eq('U.S. Senate')
    end
  end

  describe '#current_members' do
    it 'returns people currently holding offices in this body' do
      body = create(:body)
      office = create(:office, body: body)
      person = create(:person)
      create(:officeholder, person: person, office: office, end_date: nil)

      expect(body.current_members).to include(person)
    end

    it 'excludes former officeholders' do
      body = create(:body)
      office = create(:office, body: body)
      former = create(:person)
      create(:officeholder, person: former, office: office, end_date: 1.year.ago.to_date)

      expect(body.current_members).not_to include(former)
    end
  end

  describe '#current_officeholders' do
    it 'returns current officeholder records for this body' do
      body = create(:body)
      office = create(:office, body: body)
      oh = create(:officeholder, office: office, end_date: nil)

      expect(body.current_officeholders).to include(oh)
    end
  end
end
