class Ballot < ApplicationRecord
  has_paper_trail

  belongs_to :election, optional: true
  has_many :contests, dependent: :destroy
  has_many :offices, through: :contests

  ELECTION_TYPES = %w[primary general special runoff].freeze

  validates :state, presence: true
  validates :date, presence: true
  validates :election_type, presence: true, inclusion: { in: ELECTION_TYPES }
  validates :year, presence: true
  validates :party, inclusion: { in: ->(_record) { Party.ballot_vocabulary } }, allow_nil: true
  validates :party, presence: true, if: -> { election_type == 'primary' }

  scope :primary, -> { where(election_type: 'primary') }
  scope :general, -> { where(election_type: 'general') }
  scope :special, -> { where(election_type: 'special') }
  scope :runoff, -> { where(election_type: 'runoff') }
  scope :for_year, ->(year) { where(year: year) }
  scope :for_state, ->(state) { where(state: state) }
  scope :for_party, ->(party) { where(party: party) }

  before_validation :set_year_from_date
  before_validation :set_default_name

  # Always returns a human label; `name` is auto-filled on save (see
  # set_default_name) so this normally just returns the stored name.
  def full_name
    name.presence || composed_name
  end

  private

  def set_year_from_date
    self.year ||= date&.year
  end

  # Ensure every ballot carries a name. Ballots created by the election editor /
  # CSV import previously saved with a blank name; auto-populate the logical
  # label (e.g. "2026 OH Republican Primary") when none was given.
  def set_default_name
    self.name = composed_name if name.blank?
  end

  def composed_name
    parts = [year, state]
    parts << party if party.present?
    parts << election_type&.capitalize
    parts.compact.join(' ').presence
  end
end
