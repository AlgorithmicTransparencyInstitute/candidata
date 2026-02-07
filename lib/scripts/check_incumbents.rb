puts 'Checking incumbent import status:'
puts ''

# Get all incumbent names from CSV
incumbents_in_csv = []
require 'csv'
CSV.foreach('data/2026_states/2026_candidates_cleaned.csv', headers: true) do |row|
  if row['is_incumbent'] == 'true' && row['withdrew'] != 'true'
    incumbents_in_csv << {
      name: row['candidate_name'],
      state: row['state'],
      office: row['office'],
      district: row['district']
    }
  end
end

puts "CSV has #{incumbents_in_csv.length} incumbents"
puts "Database has #{Candidate.where(incumbent: true).count} candidates marked as incumbent"
puts ''

# Check each incumbent
incumbents_in_csv.each do |inc|
  name_parts = inc[:name].split
  first = name_parts.first
  last = name_parts.last

  person = Person.where(state_of_residence: inc[:state])
                 .where('LOWER(first_name) = ? AND LOWER(last_name) = ?', first.downcase, last.downcase)
                 .first

  if person
    candidate = Candidate.joins(:contest)
                        .where(person: person, incumbent: true)
                        .where('contests.date >= ?', Date.new(2026, 1, 1))
                        .first

    if candidate
      puts "✓ #{inc[:name]} (#{inc[:state]}) - MATCHED and marked as incumbent"
    else
      puts "⚠️  #{inc[:name]} (#{inc[:state]}) - Person exists but NOT marked as incumbent in 2026 contest"
    end
  else
    puts "❌ #{inc[:name]} (#{inc[:state]}) - Person not found"
  end
end
