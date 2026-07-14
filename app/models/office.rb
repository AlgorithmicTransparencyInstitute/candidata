class Office < ApplicationRecord
  has_paper_trail

  belongs_to :district, optional: true
  belongs_to :body, optional: true
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

  # Fuzzy search across the fields a human recognizes an office by. Used by the
  # searchable office pickers (core contest form + election editor new-contest).
  scope :search_text, ->(query) {
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where(
      'title ILIKE :p OR seat ILIKE :p OR body_name ILIKE :p OR ' \
      'office_category ILIKE :p OR jurisdiction ILIKE :p',
      p: pattern
    )
  }

  def full_title
    parts = [title]
    parts << seat if seat.present?
    parts << state if state.present? && !title.to_s.include?(state.to_s)
    parts.join(' - ')
  end

  def display_name
    if seat.present?
      "#{title} (#{seat})"
    else
      title
    end
  end

  # Richer one-line label for search results, disambiguating same-titled offices
  # across states/bodies: "State Representative (District 5) — CO · CO State House".
  def search_label
    context = [state, body_name].reject(&:blank?).uniq.join(' · ')
    context.present? ? "#{display_name} — #{context}" : display_name
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
