class Contest < ApplicationRecord
  has_paper_trail

  belongs_to :office
  belongs_to :ballot
  has_many :candidates, dependent: :destroy
  has_many :people, through: :candidates

  CONTEST_TYPES = %w[primary general special runoff].freeze
  PARTIES = %w[Democratic Republican Libertarian Independent].freeze + ['Working Class']

  validates :date, presence: true
  validates :contest_type, presence: true, inclusion: { in: CONTEST_TYPES }
  validates :party, inclusion: { in: PARTIES }, allow_nil: true
  validates :party, presence: true, if: -> { contest_type == 'primary' }

  scope :primary, -> { where(contest_type: 'primary') }
  scope :general, -> { where(contest_type: 'general') }
  scope :special, -> { where(contest_type: 'special') }
  scope :runoff, -> { where(contest_type: 'runoff') }
  scope :for_year, ->(year) { where(date: Date.new(year)..Date.new(year, 12, 31)) }
  scope :for_office, ->(office) { where(office: office) }
  scope :for_party, ->(party) { where(party: party) }

  delegate :state, :election_type, :year, to: :ballot, allow_nil: true

  def full_name
    parts = [year, state]
    parts << party if party.present?
    parts << contest_type.capitalize
    parts << office&.display_name
    parts.compact.join(' ')
  end

  def winner
    candidates.find_by(outcome: 'won')&.person
  end

  def winners
    candidates.winners.map(&:person)
  end

  def total_votes
    candidates.sum(:tally) || 0
  end

  def decided?
    candidates.winners.exists?
  end
end
