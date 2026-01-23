class Party < ApplicationRecord
  has_many :people, foreign_key: 'party_affiliation_id'
  
  validates :name, presence: true, uniqueness: true
  validates :abbreviation, presence: true, uniqueness: true
end
