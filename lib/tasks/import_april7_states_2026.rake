namespace :import do
  desc "Clean and import 2026 candidates batch 3: April 7 states (GA, MT, NE, PA)"
  task candidates_2026_april7: :environment do
    cleaned_dir = Rails.root.join('data', '2026_states', 'cleaned')
    april7_states = %w[GA MT NE PA]
    state_files = april7_states.map { |s| cleaned_dir.join("#{s}_candidates_cleaned.csv").to_s }
                               .select { |f| File.exist?(f) }

    if state_files.empty?
      puts "No cleaned CSV files found for April 7 states in #{cleaned_dir}"
      puts "Run: bin/rails import:clean_candidates_2026_april7"
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

  desc "Clean raw CSVs for April 7 states (GA, MT, NE, PA) into standardized format"
  task clean_candidates_2026_april7: :environment do
    load Rails.root.join('lib', 'scripts', 'clean_april7_states_2026.rb')
  end

  desc "Test import with first April 7 state only (Georgia)"
  task test_candidates_2026_april7: :environment do
    test_file = Rails.root.join('data', '2026_states', 'cleaned', 'GA_candidates_cleaned.csv')

    unless File.exist?(test_file)
      puts "Cleaned GA file not found. Running cleaner first..."
      load Rails.root.join('lib', 'scripts', 'clean_april7_states_2026.rb')
    end

    importer = Importers::EnhancedCandidate2026Importer.new(test_file)
    importer.import
  end
end
