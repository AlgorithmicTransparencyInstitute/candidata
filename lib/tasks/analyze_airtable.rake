namespace :analyze do
  desc "Analyze Airtable data structure for seed generation"
  task airtable: :environment do
    puts "Analyzing Airtable data for seed generation..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    airtable = AirtableService.instance
    
    puts "\nFetching all People records..."
    all_records = []
    offset = nil
    
    loop do
      params = { limit: 100 }
      params[:offset] = offset if offset
      
      response = airtable.fetch_records('People', params)
      records = response['records'] || []
      all_records.concat(records)
      
      puts "  Fetched #{records.length} records (total: #{all_records.length})"
      
      offset = response['offset']
      break unless offset
    end
    
    puts "\n" + "=" * 60
    puts "ANALYSIS RESULTS"
    puts "=" * 60
    
    # Analyze unique values for key fields
    analysis = {
      states: {},
      parties: {},
      levels: {},
      roles: {},
      office_names: {},
      office_categories: {},
      body_names: {},
      jurisdictions: {}
    }
    
    all_records.each do |record|
      fields = record['fields']
      
      # States
      state = fields['State']
      analysis[:states][state] = (analysis[:states][state] || 0) + 1 if state.present?
      
      # Parties
      party = fields['Registered Political Party']
      analysis[:parties][party] = (analysis[:parties][party] || 0) + 1 if party.present?
      
      # Levels
      level = fields['Level']
      analysis[:levels][level] = (analysis[:levels][level] || 0) + 1 if level.present?
      
      # Roles
      role = fields['Role']
      analysis[:roles][role] = (analysis[:roles][role] || 0) + 1 if role.present?
      
      # Office Names
      office_name = fields['Office Name']
      analysis[:office_names][office_name] = (analysis[:office_names][office_name] || 0) + 1 if office_name.present?
      
      # Office Categories
      office_category = fields['Office Category']
      analysis[:office_categories][office_category] = (analysis[:office_categories][office_category] || 0) + 1 if office_category.present?
      
      # Body Names
      body_name = fields['Body Name']
      analysis[:body_names][body_name] = (analysis[:body_names][body_name] || 0) + 1 if body_name.present?
      
      # Jurisdictions
      jurisdiction = fields['Jurisdiction']
      analysis[:jurisdictions][jurisdiction] = (analysis[:jurisdictions][jurisdiction] || 0) + 1 if jurisdiction.present?
    end
    
    # Print results
    puts "\n--- STATES (#{analysis[:states].keys.length} unique) ---"
    analysis[:states].sort_by { |_, count| -count }.each do |state, count|
      puts "  #{state}: #{count}"
    end
    
    puts "\n--- PARTIES (#{analysis[:parties].keys.length} unique) ---"
    analysis[:parties].sort_by { |_, count| -count }.each do |party, count|
      puts "  #{party}: #{count}"
    end
    
    puts "\n--- LEVELS (#{analysis[:levels].keys.length} unique) ---"
    analysis[:levels].sort_by { |_, count| -count }.each do |level, count|
      puts "  #{level}: #{count}"
    end
    
    puts "\n--- ROLES (#{analysis[:roles].keys.length} unique) ---"
    analysis[:roles].sort_by { |_, count| -count }.each do |role, count|
      puts "  #{role}: #{count}"
    end
    
    puts "\n--- OFFICE NAMES (#{analysis[:office_names].keys.length} unique) ---"
    analysis[:office_names].sort_by { |_, count| -count }.each do |name, count|
      puts "  #{name}: #{count}"
    end
    
    puts "\n--- OFFICE CATEGORIES (#{analysis[:office_categories].keys.length} unique) ---"
    analysis[:office_categories].sort_by { |_, count| -count }.each do |category, count|
      puts "  #{category}: #{count}"
    end
    
    puts "\n--- BODY NAMES (#{analysis[:body_names].keys.length} unique) ---"
    analysis[:body_names].sort_by { |_, count| -count }.each do |body, count|
      puts "  #{body}: #{count}"
    end
    
    puts "\n--- JURISDICTIONS (#{analysis[:jurisdictions].keys.length} unique) ---"
    analysis[:jurisdictions].sort_by { |_, count| -count }.each do |jurisdiction, count|
      puts "  #{jurisdiction}: #{count}"
    end
    
    puts "\n" + "=" * 60
    puts "Total records analyzed: #{all_records.length}"
    puts "=" * 60
  end
end
