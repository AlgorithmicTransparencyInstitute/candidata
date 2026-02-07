class Officeholder < ApplicationRecord
  belongs_to :person
  belongs_to :office
  
  validates :start_date, presence: true
  validates :airtable_id, uniqueness: true, allow_nil: true
  validate :end_date_after_start_date
  
  scope :current, -> { where('officeholders.end_date IS NULL OR officeholders.end_date >= ?', Date.current) }
  scope :former, -> { where('officeholders.end_date < ?', Date.current) }
  scope :as_of, ->(date) { where('officeholders.start_date <= ? AND (officeholders.end_date IS NULL OR officeholders.end_date >= ?)', date, date) }
  scope :elected_in, ->(year) { where(elected_year: year) }
  scope :appointed, -> { where(appointed: true) }
  scope :elected, -> { where(appointed: [false, nil]) }
  scope :term_ending_before, ->(date) { where('term_end_date <= ?', date) }
  scope :up_for_election_before, ->(date) { where('next_election_date <= ?', date) }
  
  def current?
    end_date.nil? || end_date >= Date.current
  end

  def active_on?(date)
    start_date <= date && (end_date.nil? || end_date >= date)
  end
  
  def tenure_length
    end_dt = end_date || Date.current
    (end_dt - start_date).to_i
  end

  def tenure_years
    (tenure_length / 365.25).round(1)
  end
  
  private
  
  def end_date_after_start_date
    return if end_date.blank? || end_date >= start_date
    errors.add(:end_date, 'must be after start date')
  end
end
