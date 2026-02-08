class Ballot < ApplicationRecord
  has_paper_trail

  belongs_to :election, optional: true
  has_many :contests, dependent: :destroy
  has_many :offices, through: :contests

  ELECTION_TYPES = %w[primary general special runoff].freeze
  PARTIES = %w[Democratic Republican Libertarian Independent].freeze + ['Working Class']

  validates :state, presence: true
  validates :date, presence: true
  validates :election_type, presence: true, inclusion: { in: ELECTION_TYPES }
  validates :year, presence: true
  validates :party, inclusion: { in: PARTIES }, allow_nil: true
  validates :party, presence: true, if: -> { election_type == 'primary' }

  scope :primary, -> { where(election_type: 'primary') }
  scope :general, -> { where(election_type: 'general') }
  scope :special, -> { where(election_type: 'special') }
  scope :runoff, -> { where(election_type: 'runoff') }
  scope :for_year, ->(year) { where(year: year) }
  scope :for_state, ->(state) { where(state: state) }
  scope :for_party, ->(party) { where(party: party) }

  before_validation :set_year_from_date

  def full_name
    return name if name.present?

    parts = [year, state]
    parts << party if party.present?
    parts << election_type.capitalize
    parts.join(' ')
  end

  private

  def set_year_from_date
    self.year ||= date&.year
  end
end
