class Candidate < ApplicationRecord
  belongs_to :person
  belongs_to :contest
  
  validates :outcome, presence: true, inclusion: { in: %w[won lost] }
  validates :tally, numericality: { greater_than_or_equal_to: 0 }
  
  scope :winners, -> { where(outcome: 'won') }
  scope :losers, -> { where(outcome: 'lost') }
  
  def vote_percentage
    return 0 if contest.total_votes.zero?
    (tally.to_f / contest.total_votes * 100).round(2)
  end
end
