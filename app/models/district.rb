class District < ApplicationRecord
  has_paper_trail

  has_many :offices

  CHAMBERS = %w[upper lower].freeze

  validates :state, presence: true
  validates :level, presence: true
  validates :district_number, uniqueness: { scope: [:state, :level, :chamber] }, allow_nil: true
  validates :chamber, inclusion: { in: CHAMBERS }, allow_nil: true
  validates :ocdid, uniqueness: true, allow_nil: true

  VOTING_AT_LARGE_STATES = %w[AK DE ND SD VT WY].freeze
  TERRITORY_DELEGATES = %w[AS DC GU MP PR VI].freeze

  scope :federal, -> { where(level: 'federal') }
  scope :state_level, -> { where(level: 'state') }
  scope :local, -> { where(level: 'local') }
  scope :upper_chamber, -> { where(chamber: 'upper') }
  scope :lower_chamber, -> { where(chamber: 'lower') }
  scope :congressional, -> { federal.where(chamber: nil) }
  scope :at_large, -> { federal.where(district_number: 0) }
  scope :at_large_voting, -> { federal.where(district_number: 0, state: VOTING_AT_LARGE_STATES) }
  scope :at_large_territories, -> { federal.where(district_number: 0, state: TERRITORY_DELEGATES) }
  scope :numbered_congressional, -> { federal.where(chamber: nil).where('district_number > 0') }
  scope :voting_members, -> { federal.where('district_number > 0 OR (district_number = 0 AND state IN (?))', VOTING_AT_LARGE_STATES) }
  scope :state_senate, -> { state_level.upper_chamber }
  scope :state_house, -> { state_level.lower_chamber }

  def full_name
    case
    when level == 'federal' && district_number && district_number > 0
      "#{state} Congressional District #{district_number}"
    when level == 'federal' && district_number == 0
      "#{state} At-Large"
    when level == 'state' && chamber == 'upper'
      "#{state} State Senate District #{district_number}"
    when level == 'state' && chamber == 'lower'
      "#{state} State House District #{district_number}"
    when district_number && district_number > 0
      "#{state} #{level.capitalize} District #{district_number}"
    else
      "#{state} #{level.capitalize}"
    end
  end
end
