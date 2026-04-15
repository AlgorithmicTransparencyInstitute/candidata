namespace :import do
  desc "Clean and import 2026 candidates batch 4: April 15 states (CA, NV, NJ, OR)"
  task candidates_2026_april15: :environment do
    cleaned_dir = Rails.root.join('data', '2026_states', 'cleaned')
    april15_states = %w[CA NV NJ OR]
    state_files = april15_states.map { |s| cleaned_dir.join("#{s}_candidates_cleaned.csv").to_s }
                                .select { |f| File.exist?(f) }

    if state_files.empty?
      puts "No cleaned CSV files found for April 15 states in #{cleaned_dir}"
      puts "Run: bin/rails import:clean_candidates_2026_april15"
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

  desc "Clean raw CSVs for April 15 states (CA, NV, NJ, OR) into standardized format"
  task clean_candidates_2026_april15: :environment do
    load Rails.root.join('lib', 'scripts', 'clean_april15_states_2026.rb')
  end

  desc "Test import with first April 15 state only (California)"
  task test_candidates_2026_april15: :environment do
    test_file = Rails.root.join('data', '2026_states', 'cleaned', 'CA_candidates_cleaned.csv')

    unless File.exist?(test_file)
      puts "Cleaned CA file not found. Running cleaner first..."
      load Rails.root.join('lib', 'scripts', 'clean_april15_states_2026.rb')
    end

    importer = Importers::EnhancedCandidate2026Importer.new(test_file)
    importer.import
  end
end
