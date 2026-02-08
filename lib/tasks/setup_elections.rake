namespace :elections do
  desc "Complete elections setup: import elections and link to ballots (production-ready)"
  task setup: :environment do
    puts "\n" + "=" * 80
    puts "🎯 ELECTIONS SETUP - Full Import & Linking"
    puts "=" * 80
    puts "\nThis task will:"
    puts "  1. Import/update elections from CSV"
    puts "  2. Link ballots to their corresponding elections"
    puts "=" * 80

    # Step 1: Import elections
    puts "\n📍 STEP 1: Importing Elections"
    puts "-" * 80
    Rake::Task['import:elections'].invoke

    # Step 2: Link ballots
    puts "\n📍 STEP 2: Linking Ballots to Elections"
    puts "-" * 80
    Rake::Task['elections:link_ballots'].invoke

    # Final summary
    puts "\n" + "=" * 80
    puts "✨ ELECTIONS SETUP COMPLETE"
    puts "=" * 80
    puts "\n📊 Final Statistics:"
    puts "   📅 Total Elections: #{Election.count}"
    puts "   🗳️  Ballots with Elections: #{Ballot.where.not(election_id: nil).count}/#{Ballot.count}"
    puts "   📋 Unlinked Ballots: #{Ballot.where(election_id: nil).count}"

    unlinked = Ballot.where(election_id: nil)
    if unlinked.any?
      puts "\n⚠️  Note: #{unlinked.count} ballot(s) could not be linked:"
      unlinked.group(:state, :election_type, :year).count.each do |(state, type, year), count|
        puts "     - #{state} #{type} #{year}: #{count} ballot(s)"
        missing = Election.find_by(state: state, election_type: type, year: year)
        if missing.nil?
          puts "       → No election exists for #{state} #{type} #{year}"
        end
      end
    end

    puts "\n✅ Ready for production!"
    puts "=" * 80 + "\n"
  end

  desc "Reset and rebuild all election data (DESTRUCTIVE - use with caution)"
  task rebuild: :environment do
    puts "\n⚠️  WARNING: This will delete ALL elections and unlink ALL ballots!"
    puts "Press Ctrl+C to cancel, or Enter to continue..."
    STDIN.gets

    puts "\n🗑️  Deleting all elections..."
    Election.destroy_all

    puts "🔓 Unlinking all ballots..."
    Ballot.update_all(election_id: nil)

    puts "\n✅ Reset complete. Running full setup...\n"
    Rake::Task['elections:setup'].invoke
  end
end
