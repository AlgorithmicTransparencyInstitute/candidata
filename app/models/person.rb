class Person < ApplicationRecord
  belongs_to :party_affiliation, class_name: 'Party', optional: true
  has_many :candidates
  has_many :contests, through: :candidates
  has_many :officeholders
  has_many :offices, through: :officeholders
  
  validates :first_name, presence: true
  validates :last_name, presence: true
  
  def full_name
    "#{first_name} #{last_name}"
  end
end
