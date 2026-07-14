require 'rails_helper'

# Pins the single source of truth for the ballot/contest party vocabulary:
# the legacy short-label list unioned with the parties table (org names with a
# trailing " Party" stripped), minus noise. See Party.ballot_vocabulary.
RSpec.describe Party, type: :model do
  describe '.ballot_vocabulary' do
    it 'includes the legacy short labels even with no party rows' do
      expect(Party.ballot_vocabulary).to include(
        'Democratic', 'Republican', 'No Party Preference', 'Legal Marijuana NOW'
      )
    end

    it 'derives short labels from the parties table (strips a trailing " Party")' do
      Party.create!(name: 'Green Party', abbreviation: 'GRN')
      expect(Party.ballot_vocabulary).to include('Green')
    end

    it 'excludes the "Unknown" placeholder party' do
      Party.create!(name: 'Unknown', abbreviation: 'UNK')
      expect(Party.ballot_vocabulary).not_to include('Unknown')
    end

    it 'is sorted and de-duplicated even when a table name collides with a legacy label' do
      Party.create!(name: 'Independent Party', abbreviation: 'IPT') # -> "Independent", already legacy
      vocab = Party.ballot_vocabulary
      expect(vocab).to eq(vocab.uniq.sort)
      expect(vocab.count('Independent')).to eq(1)
    end
  end

  describe '.canonical_ballot_party' do
    before { Party.create!(name: 'Green Party', abbreviation: 'GRN') }

    it 'snaps case-insensitively and tolerates a trailing " Party"' do
      expect(Party.canonical_ballot_party('green')).to eq('Green')
      expect(Party.canonical_ballot_party('GREEN PARTY')).to eq('Green')
    end

    it 'returns nil for an unrecognized party' do
      expect(Party.canonical_ballot_party('Zzz')).to be_nil
    end
  end
end
