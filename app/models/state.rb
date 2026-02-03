class State < ApplicationRecord
  has_many :districts
  has_many :offices
  has_many :ballots

  validates :name, presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true

  scope :states, -> { where(state_type: 'state') }
  scope :territories, -> { where(state_type: 'territory') }
  scope :federal_district, -> { where(state_type: 'federal_district') }

  def self.find_by_abbrev(abbrev)
    find_by(abbreviation: abbrev.to_s.upcase)
  end

  def territory?
    state_type == 'territory'
  end

  def federal_district?
    state_type == 'federal_district'
  end
end
