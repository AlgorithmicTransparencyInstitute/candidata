namespace :elections do
  desc "Link existing ballots to their corresponding elections"
  task link_ballots: :environment do
    puts "🔗 Linking ballots to elections..."
    puts "=" * 80

    linked_count = 0
    skipped_count = 0
    errors = []

    # Get all ballots that don't have an election_id yet
    ballots = Ballot.where(election_id: nil)

    puts "Found #{ballots.count} ballots without elections"

    ballots.each do |ballot|
      # Try to find matching election
      # Match by: state, election_type, and year
      election = Election.find_by(
        state: ballot.state,
        election_type: ballot.election_type,
        year: ballot.year
      )

      if election
        ballot.update!(election_id: election.id)
        linked_count += 1
        puts "✅ Linked: #{ballot.state} #{ballot.party} #{ballot.election_type.titleize} #{ballot.year} → Election ##{election.id}"
      else
        skipped_count += 1
        errors << "No election found for: #{ballot.state} #{ballot.election_type} #{ballot.year}"
        puts "⚠️  No election found for: #{ballot.state} #{ballot.party} #{ballot.election_type.titleize} #{ballot.year}"
      end
    end

    puts "=" * 80
    puts "📊 Linking Summary:"
    puts "   ✅ Linked: #{linked_count}"
    puts "   ⚠️  Skipped: #{skipped_count}"
    puts "   📋 Ballots with elections: #{Ballot.where.not(election_id: nil).count}/#{Ballot.count}"

    if errors.any?
      puts "\n⚠️  Issues encountered:"
      errors.uniq.each { |err| puts "   - #{err}" }
    end

    puts "\n✨ Done!"
  end
end
