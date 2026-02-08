class Election < ApplicationRecord
  has_paper_trail

  has_many :ballots, dependent: :nullify

  validates :state, presence: true
  validates :date, presence: true
  validates :election_type, presence: true, inclusion: { in: %w[primary general special] }
  validates :year, presence: true

  before_validation :set_year_from_date, if: -> { date.present? && year.blank? }

  scope :primaries, -> { where(election_type: 'primary') }
  scope :generals, -> { where(election_type: 'general') }
  scope :by_year, ->(year) { where(year: year) }
  scope :by_state, ->(state) { where(state: state) }
  scope :upcoming, -> { where('date >= ?', Date.current).order(:date) }
  scope :past, -> { where('date < ?', Date.current).order(date: :desc) }

  def full_name
    name.presence || "#{state} #{election_type.titleize} #{year}"
  end

  private

  def set_year_from_date
    self.year = date.year
  end
end
