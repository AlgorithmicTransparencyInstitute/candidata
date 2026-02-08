class BackfillPartyLinksFrom2026Candidates < ActiveRecord::Migration[8.0]
  def up
    puts "Backfilling party links from 2026 candidates..."

    # Get all 2026 candidates
    candidates_2026 = Candidate.joins(contest: :ballot)
                                .where(ballots: { year: 2026 })
                                .where.not(party_at_time: [nil, ''])

    total = candidates_2026.count
    puts "Found #{total} 2026 candidates with party_at_time"

    created_count = 0
    skipped_count = 0
    updated_primary_count = 0

    candidates_2026.find_each.with_index do |candidate, index|
      person = candidate.person
      party_name = candidate.party_at_time.strip

      # Find the party
      party = Party.find_by("LOWER(name) = ? OR LOWER(abbreviation) = ?",
                            party_name.downcase,
                            party_name.downcase)

      unless party
        # Try common variations
        party = case party_name.downcase
                when 'democratic', 'democrat', 'dem'
                  Party.find_by(name: 'Democratic Party')
                when 'republican', 'rep'
                  Party.find_by(name: 'Republican Party')
                when 'libertarian', 'lib'
                  Party.find_by(name: 'Libertarian Party')
                when 'green'
                  Party.find_by(name: 'Green Party')
                when 'independent', 'ind'
                  Party.find_by(name: 'Independent')
                else
                  nil
                end
      end

      unless party
        puts "  ⚠️  Could not find party: #{party_name} for #{person.full_name}"
        skipped_count += 1
        next
      end

      # Check if person already has this party
      person_party = PersonParty.find_by(person_id: person.id, party_id: party.id)

      if person_party
        # Already exists - if they don't have a primary, make this the primary
        if !PersonParty.exists?(person_id: person.id, is_primary: true)
          person_party.update_column(:is_primary, true)
          updated_primary_count += 1
        end
        skipped_count += 1
      else
        # Create new PersonParty
        # If person has no primary party yet, make this the primary
        has_primary = PersonParty.exists?(person_id: person.id, is_primary: true)

        PersonParty.create!(
          person_id: person.id,
          party_id: party.id,
          is_primary: !has_primary
        )
        created_count += 1
      end

      if (index + 1) % 100 == 0
        puts "  Processed #{index + 1}/#{total}..."
      end
    end

    puts "✅ Backfill complete!"
    puts "   Created: #{created_count} new party links"
    puts "   Updated: #{updated_primary_count} to be primary"
    puts "   Skipped: #{skipped_count} (already existed)"
  end

  def down
    # Don't delete - too risky to know which ones were added by this migration
    puts "⚠️  Not removing party links (reversible operation not safe)"
  end
end
