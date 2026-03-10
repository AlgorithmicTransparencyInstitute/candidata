namespace :import do
  desc "Clean and import 2026 candidates batch 2: 7 new states (AL, IN, LA, MD, NM, OH, WV)"
  task candidates_2026_batch2: :environment do
    cleaned_dir = Rails.root.join('data', '2026_states', 'cleaned')
    state_files = Dir.glob(cleaned_dir.join('*_candidates_cleaned.csv')).sort

    if state_files.empty?
      puts "No cleaned CSV files found in #{cleaned_dir}"
      puts "Run: bin/rails import:clean_candidates_2026_batch2"
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

  desc "Clean raw CSVs for 7 new states into standardized format"
  task clean_candidates_2026_batch2: :environment do
    load Rails.root.join('lib', 'scripts', 'clean_new_states_2026.rb')
  end

  desc "Test import with first new state only (Alabama)"
  task test_candidates_2026_batch2: :environment do
    test_file = Rails.root.join('data', '2026_states', 'cleaned', 'AL_candidates_cleaned.csv')

    unless File.exist?(test_file)
      puts "Cleaned AL file not found. Running cleaner first..."
      load Rails.root.join('lib', 'scripts', 'clean_new_states_2026.rb')
    end

    importer = Importers::EnhancedCandidate2026Importer.new(test_file)
    importer.import
  end
end
