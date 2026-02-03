class Ballot < ApplicationRecord
  has_many :contests, dependent: :destroy
  has_many :offices, through: :contests

  ELECTION_TYPES = %w[primary general special runoff].freeze
  
  validates :state, presence: true
  validates :date, presence: true
  validates :election_type, presence: true, inclusion: { in: ELECTION_TYPES }
  validates :year, presence: true
  
  scope :primary, -> { where(election_type: 'primary') }
  scope :general, -> { where(election_type: 'general') }
  scope :special, -> { where(election_type: 'special') }
  scope :runoff, -> { where(election_type: 'runoff') }
  scope :for_year, ->(year) { where(year: year) }
  scope :for_state, ->(state) { where(state: state) }

  before_validation :set_year_from_date

  def full_name
    name.presence || "#{state} #{election_type.capitalize} Election - #{date.strftime('%B %d, %Y')}"
  end

  private

  def set_year_from_date
    self.year ||= date&.year
  end
end
