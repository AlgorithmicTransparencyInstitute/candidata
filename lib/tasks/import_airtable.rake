namespace :import do
  desc "Import data from Airtable"
  task airtable: :environment do
    puts "Starting Airtable import..."
    
    # Check for required environment variables
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      puts "Set them with:"
      puts "export AIRTABLE_API_KEY='your_api_key'"
      puts "export AIRTABLE_BASE_ID='your_base_id'"
      exit 1
    end
    
    # Initialize services
    airtable = AirtableService.instance
    importer = CandidateImportService.new(airtable)
    
    # Run the import
    begin
      importer.import_2024_candidates
      puts "✅ Import completed successfully!"
    rescue => e
      puts "❌ Import failed: #{e.message}"
      puts e.backtrace.join("\n") if Rails.env.development?
      exit 1
    end
  end
  
  desc "Test Airtable connection"
  task test_airtable: :environment do
    puts "Testing Airtable connection..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    begin
      airtable = AirtableService.instance
      response = airtable.fetch_table('Candidates') rescue nil
      
      if response
        puts "✅ Connection successful!"
        puts "Found #{response['records']&.count || 0} records in Candidates table"
      else
        puts "❌ Connection failed - check your API key and base ID"
      end
    rescue => e
      puts "❌ Connection failed: #{e.message}"
    end
  end
  
  desc "List Airtable tables"
  task list_tables: :environment do
    puts "Listing Airtable tables..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    begin
      airtable = AirtableService.instance
      # This would require a different API call to list tables
      # For now, let's try to fetch from a common table name
      tables_to_try = ['Candidates', 'People', 'Contests', 'Parties']
      
      tables_to_try.each do |table|
        begin
          response = airtable.fetch_table(table)
          puts "✅ #{table}: #{response['records']&.count || 0} records"
        rescue
          puts "❌ #{table}: Not found or no access"
        end
      end
    rescue => e
      puts "❌ Failed to list tables: #{e.message}"
    end
  end
end
