class Party < ApplicationRecord
  has_paper_trail

  # Legacy direct link (kept for backwards compatibility)
  has_many :affiliated_people, class_name: 'Person', foreign_key: 'party_affiliation_id'
  
  # New many-to-many relationship
  has_many :person_parties, dependent: :destroy
  has_many :people, through: :person_parties
  
  validates :name, presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true

  scope :major, -> { where(name: ['Democratic Party', 'Republican Party']) }
  scope :minor, -> { where.not(name: ['Democratic Party', 'Republican Party']) }

  # Legacy short-label party vocabulary that ballots/contests historically stored
  # in their free-text `party` column. Kept in the vocabulary permanently so no
  # already-stored value can ever fail validation, even if the parties table
  # naming diverges from these labels (e.g. "Legal Marijuana NOW" vs the table's
  # "Legal Marijuana Now", or "No Party Preference" which has no table row).
  LEGACY_BALLOT_PARTIES = (
    %w[Democratic Republican Libertarian Independent Nonpartisan Unaffiliated Constitution Forward] +
    ['Working Class', 'Legal Marijuana NOW', 'No Party Preference', 'Peace and Freedom',
     'Independent American', 'No Labels', 'Unity']
  ).freeze

  # The parties table stores org-style names ("Green Party"); ballots/contests
  # store the short label ("Green"). Strip a trailing " Party" to bridge the two.
  def self.ballot_label(name)
    name.to_s.strip.sub(/\s+Party\z/i, '')
  end

  # Single source of truth for the ballot/contest `party` string vocabulary and
  # for the party dropdowns across the app. Union of the parties table (as short
  # labels) with the legacy list, minus noise. Sorted, de-duplicated.
  def self.ballot_vocabulary
    from_table = pluck(:name).map { |name| ballot_label(name) }
    (from_table + LEGACY_BALLOT_PARTIES)
      .map { |value| value.to_s.strip }
      .reject { |value| value.blank? || value.casecmp?('Unknown') }
      .uniq
      .sort
  end

  # Snap an arbitrary party string to its canonical vocabulary casing/spelling,
  # or nil if it isn't a recognized party. Case-insensitive, " Party"-suffix
  # tolerant ("green" and "Green Party" both map to "Green").
  def self.canonical_ballot_party(raw)
    value = ballot_label(raw)
    return nil if value.blank?

    ballot_vocabulary.find { |candidate| candidate.casecmp?(value) }
  end
end
