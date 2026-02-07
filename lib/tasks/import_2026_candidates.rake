require_relative '../importers/candidate_2026_importer'

namespace :import do
  desc "Import 2026 primary candidates from cleaned CSV"
  task candidates_2026: :environment do
    csv_path = Rails.root.join('data', '2026_states', '2026_candidates_cleaned.csv')

    unless File.exist?(csv_path)
      puts "❌ Cleaned CSV not found at #{csv_path}"
      puts "Run: bin/rails runner lib/scripts/clean_2026_candidates.rb"
      exit 1
    end

    importer = Candidate2026Importer.new(csv_path)
    importer.import
  end

  desc "Test import with first 20 candidates"
  task test_2026: :environment do
    csv_path = Rails.root.join('data', '2026_states', '2026_candidates_test.csv')

    unless File.exist?(csv_path)
      puts "❌ Test CSV not found at #{csv_path}"
      puts "Creating test file..."
      system("head -20 #{Rails.root}/data/2026_states/2026_candidates_cleaned.csv > #{csv_path}")
    end

    importer = Candidate2026Importer.new(csv_path)
    importer.import
  end
end
