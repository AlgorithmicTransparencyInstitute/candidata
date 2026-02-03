class Office < ApplicationRecord
  belongs_to :district, optional: true
  has_many :contests
  has_many :officeholders
  has_many :people, through: :officeholders

  LEVELS = %w[federal state local].freeze
  BRANCHES = %w[legislative executive judicial].freeze
  ROLES = %w[headOfGovernment headOfState deputyHeadOfGovernment legislatorUpperBody legislatorLowerBody highestCourtJudge judge executiveCouncil governmentOfficer schoolBoard].freeze
  
  validates :title, presence: true
  validates :level, presence: true, inclusion: { in: LEVELS }
  validates :branch, presence: true, inclusion: { in: BRANCHES }
  validates :role, inclusion: { in: ROLES, allow_blank: true }
  validates :airtable_id, uniqueness: true, allow_nil: true
  
  scope :federal, -> { where(level: 'federal') }
  scope :state, -> { where(level: 'state') }
  scope :local, -> { where(level: 'local') }
  scope :legislative, -> { where(branch: 'legislative') }
  scope :executive, -> { where(branch: 'executive') }
  scope :judicial, -> { where(branch: 'judicial') }
  scope :by_category, ->(cat) { where(office_category: cat) }
  scope :by_body, ->(body) { where(body_name: body) }
  
  def full_title
    parts = [title]
    parts << "District #{district.district_number}" if district&.district_number
    parts << state if state
    parts.join(' - ')
  end

  def legislative?
    branch == 'legislative'
  end

  def executive?
    branch == 'executive'
  end

  def judicial?
    branch == 'judicial'
  end
end
