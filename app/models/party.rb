class Party < ApplicationRecord
  has_paper_trail

  # Legacy direct link (kept for backwards compatibility)
  has_many :affiliated_people, class_name: 'Person', foreign_key: 'party_affiliation_id'
  
  # New many-to-many relationship
  has_many :person_parties, dependent: :destroy
  has_many :people, through: :person_parties
  
  validates :name, presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true

  scope :major, -> { where(name: ['Democratic Party', 'Republican Party']) }
  scope :minor, -> { where.not(name: ['Democratic Party', 'Republican Party']) }
end
