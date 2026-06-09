namespace :import do
  MAY_STATES_2026 = %w[IA ME ND OK SC SD UT VA].freeze

  desc "Clean and import 2026 candidates batch 5: May states (IA, ME, ND, OK, SC, SD, UT, VA-Senate-only)"
  task candidates_2026_may: :environment do
    # Pre-flight: refuse to import unless every state has a 2026 primary Election
    # on file. Without this, the importer silently falls back to 2026-03-04,
    # which would create wrong ballots for these states.
    missing = MAY_STATES_2026.reject do |abbrev|
      Election.exists?(state: abbrev, election_type: 'primary', year: 2026)
    end

    if missing.any?
      puts "ABORTING: missing 2026 primary Election records for: #{missing.join(', ')}"
      puts "Add the Election record(s) first so the importer uses the correct primary date instead of the March 4 fallback."
      exit 1
    end

    cleaned_dir = Rails.root.join('data', '2026_states', 'cleaned')
    state_files = MAY_STATES_2026.map { |s| cleaned_dir.join("#{s}_candidates_cleaned.csv").to_s }
                                 .select { |f| File.exist?(f) }

    if state_files.empty?
      puts "No cleaned CSV files found for May states in #{cleaned_dir}"
      puts "Run: bin/rails import:clean_candidates_2026_may"
      exit 1
    end

    puts "\nFound #{state_files.size} cleaned state files:"
    state_files.each { |f| puts "  #{File.basename(f)}" }
    puts

    state_files.each do |file|
      puts "\n" + "=" * 80
      puts "IMPORTING: #{File.basename(file)}"
      puts "=" * 80
      importer = Importers::EnhancedCandidate2026Importer.new(file)
      importer.import
    end
  end

  desc "Clean raw CSVs for May states (IA, ME, ND, OK, SC, SD, UT, VA-Senate) into standardized format"
  task clean_candidates_2026_may: :environment do
    load Rails.root.join('lib', 'scripts', 'clean_may_states_2026.rb')
  end

  desc "Test import with smallest May state (North Dakota — 3 candidates)"
  task test_candidates_2026_may: :environment do
    test_file = Rails.root.join('data', '2026_states', 'cleaned', 'ND_candidates_cleaned.csv')

    unless File.exist?(test_file)
      puts "Cleaned ND file not found. Running cleaner first..."
      load Rails.root.join('lib', 'scripts', 'clean_may_states_2026.rb')
    end

    unless Election.exists?(state: 'ND', election_type: 'primary', year: 2026)
      puts "ABORTING: missing 2026 primary Election for ND"
      exit 1
    end

    importer = Importers::EnhancedCandidate2026Importer.new(test_file)
    importer.import
  end
end
