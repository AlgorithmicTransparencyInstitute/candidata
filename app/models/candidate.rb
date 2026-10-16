class Candidate < ApplicationRecord
  has_paper_trail

  belongs_to :person
  belongs_to :contest

  # 'advanced' = advanced to the general without a contested primary (primary
  # cancelled / unopposed — "won by default"). Counts as a primary winner for
  # the purpose of advancement to the general election ballot.
  OUTCOMES = %w[won lost pending withdrawn unknown advanced].freeze

  # Outcomes that mean the candidate carries forward as the contest's winner /
  # nominee. Used by the winners scope and the Contest winner helpers so that
  # an unopposed advancer is treated as a winner everywhere.
  WINNING_OUTCOMES = %w[won advanced].freeze

  validates :outcome, inclusion: { in: OUTCOMES, allow_blank: true }
  validates :tally, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :airtable_id, uniqueness: true, allow_nil: true

  scope :winners, -> { where(outcome: WINNING_OUTCOMES) }
  scope :losers, -> { where(outcome: 'lost') }
  scope :pending, -> { where(outcome: ['pending', nil, '']) }
  scope :incumbents, -> { where(incumbent: true) }
  scope :challengers, -> { where(incumbent: [false, nil]) }
  scope :for_year, ->(year) { joins(:contest).where(contests: { date: Date.new(year)..Date.new(year, 12, 31) }) }

  delegate :office, :ballot, to: :contest

  # The public site's published candidate ordering (stated on race pages):
  # winners first, then by votes when tallies exist, then Democrats and
  # Republicans, then everyone else; incumbents before challengers; then
  # alphabetical by last name. Not a ranking or an endorsement. Expects
  # :person and :contest loaded.
  def self.in_public_order(candidates)
    candidates.sort_by do |c|
      party = c.party_at_time.presence || c.contest&.party.to_s
      [WINNING_OUTCOMES.include?(c.outcome) ? 0 : 1,
       -c.tally.to_i,
       party.start_with?('Democrat', 'Republican') ? 0 : 1,
       c.incumbent ? 0 : 1,
       c.person.last_name.to_s.downcase, c.person.first_name.to_s.downcase]
    end
  end
  
  def vote_percentage
    return 0 if contest.total_votes.zero? || tally.nil?
    (tally.to_f / contest.total_votes * 100).round(2)
  end

  def won?
    outcome == 'won'
  end

  # Advanced to the general unopposed (primary cancelled / no opponent).
  def advanced?
    outcome == 'advanced'
  end

  # Carries forward as the contest winner/nominee — an outright win OR an
  # unopposed advancement. Use this (not won?) for "is this the nominee?".
  def winner?
    WINNING_OUTCOMES.include?(outcome)
  end

  def lost?
    outcome == 'lost'
  end
end
