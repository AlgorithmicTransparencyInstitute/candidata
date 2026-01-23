class Contest < ApplicationRecord
  belongs_to :office
  belongs_to :ballot
  has_many :candidates
  has_many :people, through: :candidates
  
  validates :date, presence: true
  validates :location, presence: true
  validates :contest_type, presence: true
  
  scope :primary, -> { where(contest_type: 'primary') }
  scope :general, -> { where(contest_type: 'general') }
  scope :special, -> { where(contest_type: 'special') }
  
  def winner
    candidates.find_by(outcome: 'won')&.person
  end
  
  def total_votes
    candidates.sum(:tally)
  end
end
