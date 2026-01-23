namespace :import_debug do
  desc "Test Airtable connection with timeout"
  task test_connection: :environment do
    puts "Testing Airtable connection with timeout..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    begin
      Timeout::timeout(30) do
        airtable = AirtableService.instance
        response = airtable.fetch_records('People', limit: 1)
        
        if response['records'] && !response['records'].empty?
          puts "✅ Connection successful!"
          puts "Found #{response['records'].length} test record(s)"
        else
          puts "❌ No records found"
        end
      end
    rescue Timeout::Error
      puts "❌ Connection timed out after 30 seconds"
    rescue => e
      puts "❌ Connection failed: #{e.message}"
    end
  end
  
  desc "Import only parties (small test)"
  task parties: :environment do
    puts "Importing parties only..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    begin
      Timeout::timeout(60) do
        airtable = AirtableService.instance
        
        # Get just 10 records to test
        puts "Fetching 10 records from People table..."
        response = airtable.fetch_records('People', limit: 10)
        
        if response['records'] && !response['records'].empty?
          puts "✅ Fetched #{response['records'].length} records"
          
          # Extract unique parties
          party_names = response['records'].map { |r| r['fields']['Registered Political Party'] }.compact.uniq
          puts "Found parties: #{party_names.inspect}"
          
          party_names.each do |party_name|
            next if party_name.blank?
            
            abbreviation = case party_name
                          when 'Democratic Party' then 'DEM'
                          when 'Republican Party' then 'GOP'
                          when 'Independent' then 'IND'
                          when 'Green Party' then 'GRN'
                          when 'Libertarian Party' then 'LP'
                          else party_name[0..2].upcase
                          end
            
            ideology = case party_name
                      when 'Democratic Party' then 'Center-left'
                      when 'Republican Party' then 'Center-right'
                      when 'Green Party' then 'Left-wing'
                      when 'Libertarian Party' then 'Libertarian'
                      else 'Various'
                      end
            
            party = Party.find_or_create_by!(name: party_name) do |p|
              p.abbreviation = abbreviation
              p.ideology = ideology
            end
            
            puts "✅ Created/updated party: #{party.name}"
          end
          
          puts "✅ Parties import completed. Total: #{Party.count}"
        else
          puts "❌ No records found"
        end
      end
    rescue Timeout::Error
      puts "❌ Parties import timed out after 60 seconds"
    rescue => e
      puts "❌ Parties import failed: #{e.message}"
      puts e.backtrace.join("\n") if Rails.env.development?
    end
  end
  
  desc "Import only people (small test)"
  task people: :environment do
    puts "Importing people only (first 5 records)..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    begin
      Timeout::timeout(60) do
        airtable = AirtableService.instance
        
        puts "Fetching 5 records from People table..."
        response = airtable.fetch_records('People', limit: 5)
        
        if response['records'] && !response['records'].empty?
          puts "✅ Fetched #{response['records'].length} records"
          
          response['records'].each_with_index do |record, index|
            fields = record['fields']
            
            puts "\nProcessing record #{index + 1}:"
            puts "  Official Name: #{fields['Official Name']}"
            puts "  Party: #{fields['Registered Political Party']}"
            
            # Parse name
            official_name = fields['Official Name'] || fields['Candidate Name']
            next if official_name.blank?
            
            name_parts = official_name.split(' ')
            first_name = name_parts[0]
            last_name = name_parts[1..].join(' ')
            
            # Find party
            party_name = fields['Registered Political Party']
            party = Party.find_by(name: party_name) if party_name.present?
            
            # Parse dates
            birth_date = parse_date(fields['DOB'])
            
            # Extract state
            state = extract_state_from_fields(fields)
            
            person = Person.find_or_create_by!(
              first_name: first_name,
              last_name: last_name
            ) do |person|
              person.party_affiliation = party
              person.birth_date = birth_date
              person.death_date = nil
              person.state_of_residence = state
            end
            
            puts "  ✅ Created/updated person: #{person.full_name}"
          end
          
          puts "\n✅ People import completed. Total: #{Person.count}"
        else
          puts "❌ No records found"
        end
      end
    rescue Timeout::Error
      puts "❌ People import timed out after 60 seconds"
    rescue => e
      puts "❌ People import failed: #{e.message}"
      puts e.backtrace.join("\n") if Rails.env.development?
    end
  end
  
  desc "Check record count"
  task count: :environment do
    puts "Checking record counts..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    begin
      Timeout::timeout(30) do
        airtable = AirtableService.instance
        
        # Count records
        response = airtable.fetch_records('People', limit: 1)
        puts "✅ Connection successful"
        
        # Try to get a few more records
        response = airtable.fetch_records('People', limit: 100)
        puts "✅ Can fetch #{response['records']&.count || 0} records"
        
      end
    rescue Timeout::Error
      puts "❌ Count check timed out after 30 seconds"
    rescue => e
      puts "❌ Count check failed: #{e.message}"
    end
  end
  
  private
  
  def parse_date(date_string)
    return nil if date_string.blank?
    
    Date.strptime(date_string, '%m/%d/%y') rescue 
    Date.strptime(date_string, '%Y-%m-%d') rescue
    Date.strptime(date_string, '%m/%d/%Y') rescue
    nil
  end
  
  def extract_state_from_fields(fields)
    state = fields['State']
    return state if state.present?
    
    contest = fields['Contest']
    if contest.present?
      match = contest.match(/^(\w{2}),/)
      return match[1] if match
    end
    
    electoral_district = fields['Electoral District']
    if electoral_district.present?
      match = electoral_district.match(/^(\w+)'s/)
      return match[1] if match
    end
    
    nil
  end
end
