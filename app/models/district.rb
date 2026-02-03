class District < ApplicationRecord
  has_many :offices

  CHAMBERS = %w[upper lower].freeze

  validates :state, presence: true
  validates :level, presence: true
  validates :district_number, uniqueness: { scope: [:state, :level, :chamber] }, allow_nil: true
  validates :chamber, inclusion: { in: CHAMBERS }, allow_nil: true
  validates :ocdid, uniqueness: true, allow_nil: true

  scope :federal, -> { where(level: 'federal') }
  scope :state_level, -> { where(level: 'state') }
  scope :local, -> { where(level: 'local') }
  scope :upper_chamber, -> { where(chamber: 'upper') }
  scope :lower_chamber, -> { where(chamber: 'lower') }
  scope :congressional, -> { federal.where(chamber: nil) }
  scope :state_senate, -> { state_level.upper_chamber }
  scope :state_house, -> { state_level.lower_chamber }

  def full_name
    case
    when level == 'federal' && district_number
      "#{state} Congressional District #{district_number}"
    when level == 'state' && chamber == 'upper'
      "#{state} State Senate District #{district_number}"
    when level == 'state' && chamber == 'lower'
      "#{state} State House District #{district_number}"
    when district_number
      "#{state} #{level.capitalize} District #{district_number}"
    else
      "#{state} #{level.capitalize}"
    end
  end
end
