require 'rails_helper'

RSpec.describe Officeholder, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:person) }
    it { is_expected.to belong_to(:office) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:start_date) }

    it 'validates uniqueness of airtable_id allowing nil' do
      create(:officeholder, airtable_id: 'rec123')
      expect(build(:officeholder, airtable_id: 'rec123')).not_to be_valid
      expect(build(:officeholder, airtable_id: nil)).to be_valid
    end

    describe 'end_date_after_start_date' do
      it 'is valid when end_date is after start_date' do
        oh = build(:officeholder, start_date: Date.new(2020, 1, 1), end_date: Date.new(2024, 1, 1))
        expect(oh).to be_valid
      end

      it 'is valid when end_date is nil' do
        oh = build(:officeholder, start_date: Date.new(2020, 1, 1), end_date: nil)
        expect(oh).to be_valid
      end

      it 'is invalid when end_date is before start_date' do
        oh = build(:officeholder, start_date: Date.new(2024, 1, 1), end_date: Date.new(2023, 12, 31))
        expect(oh).not_to be_valid
        expect(oh.errors[:end_date]).to include('must be after start date')
      end

      it 'is valid when end_date equals start_date' do
        oh = build(:officeholder, start_date: Date.new(2024, 1, 1), end_date: Date.new(2024, 1, 1))
        expect(oh).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.current' do
      it 'includes officeholders with nil end_date' do
        current = create(:officeholder, end_date: nil)
        expect(Officeholder.current).to include(current)
      end

      it 'includes officeholders with future end_date' do
        current = create(:officeholder, end_date: 1.year.from_now.to_date)
        expect(Officeholder.current).to include(current)
      end

      it 'excludes officeholders with past end_date' do
        former = create(:officeholder, end_date: 1.year.ago.to_date)
        expect(Officeholder.current).not_to include(former)
      end
    end

    describe '.former' do
      it 'includes officeholders with past end_date' do
        former = create(:officeholder, end_date: 1.year.ago.to_date)
        expect(Officeholder.former).to include(former)
      end

      it 'excludes officeholders with nil end_date' do
        current = create(:officeholder, end_date: nil)
        expect(Officeholder.former).not_to include(current)
      end
    end

    describe '.as_of' do
      it 'returns officeholders active on a specific date' do
        oh = create(:officeholder,
                    start_date: Date.new(2022, 1, 1),
                    end_date: Date.new(2026, 1, 1))

        expect(Officeholder.as_of(Date.new(2024, 6, 1))).to include(oh)
        expect(Officeholder.as_of(Date.new(2021, 12, 31))).not_to include(oh)
        expect(Officeholder.as_of(Date.new(2027, 1, 1))).not_to include(oh)
      end

      it 'includes boundary dates' do
        oh = create(:officeholder,
                    start_date: Date.new(2022, 1, 1),
                    end_date: Date.new(2026, 1, 1))

        expect(Officeholder.as_of(Date.new(2022, 1, 1))).to include(oh)
        expect(Officeholder.as_of(Date.new(2026, 1, 1))).to include(oh)
      end

      it 'includes officeholders with nil end_date' do
        oh = create(:officeholder, start_date: Date.new(2022, 1, 1), end_date: nil)

        expect(Officeholder.as_of(Date.new(2024, 6, 1))).to include(oh)
      end
    end

    describe '.elected_in' do
      it 'returns officeholders elected in a specific year' do
        oh2022 = create(:officeholder, elected_year: 2022)
        oh2024 = create(:officeholder, elected_year: 2024)

        expect(Officeholder.elected_in(2022)).to include(oh2022)
        expect(Officeholder.elected_in(2022)).not_to include(oh2024)
      end
    end

    describe '.appointed / .elected' do
      it 'filters by appointed flag' do
        appointed = create(:officeholder, appointed: true)
        elected = create(:officeholder, appointed: false)

        expect(Officeholder.appointed).to include(appointed)
        expect(Officeholder.elected).to include(elected)
        expect(Officeholder.elected).not_to include(appointed)
      end
    end

    describe '.term_ending_before' do
      it 'returns officeholders with term ending before date' do
        soon = create(:officeholder, term_end_date: 3.months.from_now.to_date)
        later = create(:officeholder, term_end_date: 2.years.from_now.to_date)

        expect(Officeholder.term_ending_before(1.year.from_now.to_date)).to include(soon)
        expect(Officeholder.term_ending_before(1.year.from_now.to_date)).not_to include(later)
      end
    end
  end

  describe '#current?' do
    it 'returns true when end_date is nil' do
      oh = build(:officeholder, end_date: nil)
      expect(oh.current?).to be true
    end

    it 'returns true when end_date is in the future' do
      oh = build(:officeholder, end_date: 1.year.from_now.to_date)
      expect(oh.current?).to be true
    end

    it 'returns false when end_date is in the past' do
      oh = build(:officeholder, end_date: 1.year.ago.to_date)
      expect(oh.current?).to be false
    end

    it 'returns true when end_date is today' do
      oh = build(:officeholder, end_date: Date.current)
      expect(oh.current?).to be true
    end
  end

  describe '#active_on?' do
    let(:oh) { build(:officeholder, start_date: Date.new(2022, 1, 1), end_date: Date.new(2026, 1, 1)) }

    it 'returns true for dates within range' do
      expect(oh.active_on?(Date.new(2024, 6, 1))).to be true
    end

    it 'returns true on start_date' do
      expect(oh.active_on?(Date.new(2022, 1, 1))).to be true
    end

    it 'returns true on end_date' do
      expect(oh.active_on?(Date.new(2026, 1, 1))).to be true
    end

    it 'returns false before start_date' do
      expect(oh.active_on?(Date.new(2021, 12, 31))).to be false
    end

    it 'returns false after end_date' do
      expect(oh.active_on?(Date.new(2026, 1, 2))).to be false
    end

    it 'handles nil end_date' do
      oh_current = build(:officeholder, start_date: Date.new(2022, 1, 1), end_date: nil)
      expect(oh_current.active_on?(Date.new(2030, 1, 1))).to be true
    end
  end

  describe '#tenure_length' do
    it 'returns days between start and end date' do
      oh = build(:officeholder, start_date: Date.new(2022, 1, 1), end_date: Date.new(2024, 1, 1))
      expect(oh.tenure_length).to eq(730) # 2022 + 2023 = 365 + 365 = 730 days
    end

    it 'uses current date when end_date is nil' do
      oh = build(:officeholder, start_date: Date.current - 100, end_date: nil)
      expect(oh.tenure_length).to eq(100)
    end
  end

  describe '#tenure_years' do
    it 'returns approximate years of service' do
      oh = build(:officeholder, start_date: Date.new(2022, 1, 1), end_date: Date.new(2024, 1, 1))
      expect(oh.tenure_years).to eq(2.0)
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      oh = create(:officeholder)
      oh.update!(elected_year: 2024)

      expect(oh.versions.count).to eq(2)
    end
  end
end
