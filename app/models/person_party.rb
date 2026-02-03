class PersonParty < ApplicationRecord
  belongs_to :person
  belongs_to :party

  validates :person_id, uniqueness: { scope: :party_id }
  validate :only_one_primary_per_person

  scope :primary, -> { where(is_primary: true) }

  private

  def only_one_primary_per_person
    if is_primary && PersonParty.where(person_id: person_id, is_primary: true).where.not(id: id).exists?
      errors.add(:is_primary, "can only have one primary party per person")
    end
  end
end
