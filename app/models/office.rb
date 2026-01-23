class Office < ApplicationRecord
  belongs_to :district, optional: true
  has_many :contests
  has_many :officeholders
  has_many :people, through: :officeholders
  
  validates :title, presence: true
  validates :level, presence: true
  validates :branch, presence: true
  
  scope :federal, -> { where(level: 'federal') }
  scope :state, -> { where(level: 'state') }
  scope :local, -> { where(level: 'local') }
  
  def full_title
    parts = [title]
    parts << "District #{district.district_number}" if district
    parts << state if state
    parts.join(' - ')
  end
end
