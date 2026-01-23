class Officeholder < ApplicationRecord
  belongs_to :person
  belongs_to :office
  
  validates :start_date, presence: true
  validate :end_date_after_start_date
  
  scope :current, -> { where('end_date IS NULL OR end_date >= ?', Date.current) }
  scope :former, -> { where('end_date < ?', Date.current) }
  
  def current?
    end_date.nil? || end_date >= Date.current
  end
  
  def tenure_length
    end_date ||= Date.current
    (end_date - start_date).to_i
  end
  
  private
  
  def end_date_after_start_date
    return if end_date.blank? || end_date >= start_date
    errors.add(:end_date, 'must be after start date')
  end
end
