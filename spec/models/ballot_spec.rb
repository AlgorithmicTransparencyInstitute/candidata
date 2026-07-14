require 'rails_helper'

RSpec.describe Ballot, type: :model do
  describe 'party validation (Party-table-derived vocabulary)' do
    it 'accepts a party that exists only in the parties table' do
      Party.create!(name: 'Green Party', abbreviation: 'GRN')
      ballot = Ballot.new(state: 'CO', date: Date.new(2026, 6, 30), election_type: 'primary', party: 'Green')
      expect(ballot).to be_valid
    end

    it 'rejects a party that is in neither the table nor the legacy list' do
      ballot = Ballot.new(state: 'CO', date: Date.new(2026, 6, 30), election_type: 'primary', party: 'Zzz')
      expect(ballot).not_to be_valid
      expect(ballot.errors[:party]).to be_present
    end
  end

  describe 'filter scopes' do
    let!(:co) { Ballot.create!(state: 'CO', date: Date.new(2026, 6, 30), election_type: 'general', year: 2026) }
    let!(:ny) { Ballot.create!(state: 'NY', date: Date.new(2025, 11, 4), election_type: 'general', year: 2025) }

    it 'for_state matches the stored two-letter abbreviation' do
      expect(Ballot.for_state('CO')).to contain_exactly(co)
    end

    it 'for_year matches the indexed year column, casting strings' do
      expect(Ballot.for_year(2026)).to contain_exactly(co)
      expect(Ballot.for_year('2026')).to contain_exactly(co)
    end
  end
end
