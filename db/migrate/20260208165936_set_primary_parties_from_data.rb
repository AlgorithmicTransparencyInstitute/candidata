class SetPrimaryPartiesFromData < ActiveRecord::Migration[8.0]
  def up
    # Strategy:
    # 1. If person has party_affiliation_id (legacy field), mark that party as primary in person_parties
    # 2. If person has only one party in person_parties and no party_affiliation, mark it as primary

    updated_count = 0

    # Case 1: Use party_affiliation_id if present
    Person.where.not(party_affiliation_id: nil).find_each do |person|
      pp = PersonParty.find_by(person_id: person.id, party_id: person.party_affiliation_id)
      if pp && !pp.is_primary
        pp.update_column(:is_primary, true)
        updated_count += 1
      end
    end

    puts "Set #{updated_count} primary parties from party_affiliation_id"

    # Case 2: If person has exactly one party and no existing primary, mark it as primary
    single_party_count = 0
    Person.find_each do |person|
      person_parties = PersonParty.where(person_id: person.id)

      # Only if person has exactly one party and no primary is already set
      if person_parties.count == 1 && !person_parties.where(is_primary: true).exists?
        person_parties.first.update_column(:is_primary, true)
        single_party_count += 1
      end
    end

    puts "Set #{single_party_count} primary parties for people with single party affiliation"
    puts "Total primary parties set: #{updated_count + single_party_count}"
  end

  def down
    # Reset all is_primary flags to false
    PersonParty.update_all(is_primary: false)
    puts "Reset all primary party flags"
  end
end
