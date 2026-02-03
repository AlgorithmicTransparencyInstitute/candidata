class Candidate < ApplicationRecord
  belongs_to :person
  belongs_to :contest

  OUTCOMES = %w[won lost pending withdrawn unknown].freeze
  
  validates :outcome, inclusion: { in: OUTCOMES, allow_blank: true }
  validates :tally, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :airtable_id, uniqueness: true, allow_nil: true
  
  scope :winners, -> { where(outcome: 'won') }
  scope :losers, -> { where(outcome: 'lost') }
  scope :pending, -> { where(outcome: ['pending', nil, '']) }
  scope :incumbents, -> { where(incumbent: true) }
  scope :challengers, -> { where(incumbent: [false, nil]) }
  scope :for_year, ->(year) { joins(:contest).where(contests: { date: Date.new(year)..Date.new(year, 12, 31) }) }

  delegate :office, :ballot, to: :contest
  
  def vote_percentage
    return 0 if contest.total_votes.zero? || tally.nil?
    (tally.to_f / contest.total_votes * 100).round(2)
  end

  def won?
    outcome == 'won'
  end

  def lost?
    outcome == 'lost'
  end
end
