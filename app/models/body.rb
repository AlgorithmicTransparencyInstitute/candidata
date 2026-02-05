class Body < ApplicationRecord
  has_many :offices
  belongs_to :parent_body, class_name: 'Body', optional: true
  has_many :sub_bodies, class_name: 'Body', foreign_key: 'parent_body_id'

  LEVELS = %w[federal state local].freeze
  BRANCHES = %w[legislative executive judicial].freeze
  CHAMBER_TYPES = %w[upper lower unicameral].freeze

  validates :name, presence: true
  validates :name, uniqueness: { scope: :country }
  validates :level, inclusion: { in: LEVELS, allow_blank: true }
  validates :branch, inclusion: { in: BRANCHES, allow_blank: true }
  validates :chamber_type, inclusion: { in: CHAMBER_TYPES, allow_blank: true }

  scope :federal, -> { where(level: 'federal') }
  scope :state_level, -> { where(level: 'state') }
  scope :local, -> { where(level: 'local') }
  scope :legislative, -> { where(branch: 'legislative') }
  scope :by_country, ->(country) { where(country: country) }
  scope :by_state, ->(state) { where(state: state) }

  def current_members
    Person.joins(officeholders: :office)
          .where(offices: { body_id: id })
          .where(officeholders: { end_date: nil })
          .distinct
  end

  def current_officeholders
    Officeholder.current.joins(:office).where(offices: { body_id: id })
  end

  def display_name
    name
  end
end
