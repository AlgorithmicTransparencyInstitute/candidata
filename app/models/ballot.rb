class Ballot < ApplicationRecord
  has_many :contests
  has_many :offices, through: :contests
  
  validates :state, presence: true
  validates :date, presence: true
  validates :election_type, presence: true
  
  scope :primary, -> { where(election_type: 'primary') }
  scope :general, -> { where(election_type: 'general') }
  scope :special, -> { where(election_type: 'special') }
  
  def full_name
    "#{state} #{election_type.capitalize} Election - #{date.strftime('%B %d, %Y')}"
  end
end
