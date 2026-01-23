class District < ApplicationRecord
  has_many :offices
  
  validates :state, presence: true
  validates :level, presence: true
  validates :district_number, uniqueness: { scope: [:state, :level] }, allow_nil: true
  
  scope :federal, -> { where(level: 'federal') }
  scope :state, -> { where(level: 'state') }
  scope :local, -> { where(level: 'local') }
  
  def full_name
    if district_number
      "#{state} #{level.capitalize} District #{district_number}"
    else
      "#{state} #{level.capitalize}"
    end
  end
end
