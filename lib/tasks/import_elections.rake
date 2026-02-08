require 'csv'

namespace :import do
  desc "Import 2026 primary elections from CSV"
  task elections: :environment do
    csv_path = Rails.root.join('data', '2026 Election Calendar - clean_state_election_dates.csv')

    unless File.exist?(csv_path)
      puts "❌ CSV file not found at: #{csv_path}"
      exit 1
    end

    puts "📅 Importing 2026 primary elections from CSV..."
    puts "=" * 80

    created_count = 0
    updated_count = 0
    skipped_count = 0
    errors = []

    CSV.foreach(csv_path, headers: true) do |row|
      state_name = row['State']&.strip
      election_date = row['Primary Date']&.strip
      filing_deadline = row['Filing Deadline']&.strip

      # Skip if missing critical data
      if state_name.blank? || election_date.blank?
        skipped_count += 1
        puts "⚠️  Skipping row: #{state_name || 'Unknown'} - missing state or date"
        next
      end

      # Convert state name to abbreviation
      state = State.find_by("name ILIKE ?", state_name)
      unless state
        skipped_count += 1
        errors << "State not found: #{state_name}"
        puts "❌ State not found: #{state_name}"
        next
      end

      # Parse dates
      begin
        parsed_date = Date.strptime(election_date, '%m/%d/%Y')
      rescue ArgumentError
        skipped_count += 1
        errors << "Invalid election date for #{state_name}: #{election_date}"
        puts "❌ Invalid election date for #{state_name}: #{election_date}"
        next
      end

      parsed_filing_deadline = nil
      if filing_deadline.present?
        begin
          parsed_filing_deadline = Date.strptime(filing_deadline, '%m/%d/%Y')
        rescue ArgumentError
          puts "⚠️  Invalid filing deadline for #{state_name}: #{filing_deadline} (continuing without it)"
        end
      end

      # Find or create election
      election = Election.find_or_initialize_by(
        state: state.abbreviation,
        election_type: 'primary',
        year: 2026
      )

      if election.new_record?
        created_count += 1
        action = "✅ Created"
      else
        updated_count += 1
        action = "🔄 Updated"
      end

      election.date = parsed_date
      election.registration_deadline = parsed_filing_deadline

      if election.save
        puts "#{action}: #{state.abbreviation} Primary - #{parsed_date.strftime('%B %d, %Y')}"
      else
        skipped_count += 1
        errors << "Failed to save #{state_name}: #{election.errors.full_messages.join(', ')}"
        puts "❌ Failed to save #{state_name}: #{election.errors.full_messages.join(', ')}"
      end
    end

    puts "=" * 80
    puts "📊 Import Summary:"
    puts "   ✅ Created: #{created_count}"
    puts "   🔄 Updated: #{updated_count}"
    puts "   ⚠️  Skipped: #{skipped_count}"
    puts "   📅 Total Elections: #{Election.where(election_type: 'primary', year: 2026).count}"

    if errors.any?
      puts "\n❌ Errors encountered:"
      errors.each { |err| puts "   - #{err}" }
    end

    puts "\n✨ Done!"
  end
end
