namespace :import_batch do
  desc "Import all data in batches with progress tracking"
  task all: :environment do
    puts "Starting batch import with progress tracking..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    airtable = AirtableService.instance
    
    # Get all records with proper pagination
    puts "\n=== Fetching all records from Airtable ==="
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
    
    puts "✅ Fetched #{all_records.length} total records"
    
    # Define batch size
    batch_size = 20
    
    # Step 1: Import parties (from all records)
    puts "\n=== Step 1: Importing Parties ==="
    import_parties_batch(all_records)
    
    # Step 2: Import people in batches
    puts "\n=== Step 2: Importing People (in batches) ==="
    import_people_batch(all_records, batch_size)
    
    # Step 3: Import districts in batches
    puts "\n=== Step 3: Importing Districts (in batches) ==="
    import_districts_batch(all_records, batch_size)
    
    # Step 4: Import offices in batches
    puts "\n=== Step 4: Importing Offices (in batches) ==="
    import_offices_batch(all_records, batch_size)
    
    # Step 5: Import ballots
    puts "\n=== Step 5: Importing Ballots ==="
    import_ballots_batch(all_records)
    
    # Step 6: Import contests in batches
    puts "\n=== Step 6: Importing Contests (in batches) ==="
    import_contests_batch(all_records, batch_size)
    
    # Step 7: Import candidates in batches
    puts "\n=== Step 7: Importing Candidates (in batches) ==="
    import_candidates_batch(all_records, batch_size)
    
    # Step 8: Import officeholders in batches
    puts "\n=== Step 8: Importing Officeholders (in batches) ==="
    import_officeholders_batch(all_records, batch_size)
    
    puts "\n🎉 Batch import completed!"
    puts "Final counts:"
    puts "  Parties: #{Party.count}"
    puts "  People: #{Person.count}"
    puts "  Districts: #{District.count}"
    puts "  Offices: #{Office.count}"
    puts "  Ballots: #{Ballot.count}"
    puts "  Contests: #{Contest.count}"
    puts "  Candidates: #{Candidate.count}"
    puts "  Officeholders: #{Officeholder.count}"
  end
  
  desc "Reset database and re-import"
  task reset_and_import: :environment do
    puts "🔄 Resetting database..."
    
    # Delete all data in reverse order of dependencies
    Officeholder.delete_all
    Candidate.delete_all
    Contest.delete_all
    Ballot.delete_all
    Office.delete_all
    District.delete_all
    Person.delete_all
    Party.delete_all
    
    puts "✅ Database reset complete"
    
    # Run the import
    Rake::Task['import_batch:all'].invoke
  end
  
  desc "Import only people in batches"
  task people: :environment do
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    airtable = AirtableService.instance
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "Fetched #{all_records.length} records"
    import_people_batch(all_records, 20)
  end
  
  private
  
  def import_parties_batch(all_records)
    puts "Extracting parties from #{all_records.length} records..."
    
    party_names = all_records.map { |r| r['fields']['Registered Political Party'] }.compact.uniq
    puts "Found parties: #{party_names.inspect}"
    
    parties_created = 0
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
      
      created_party = Party.find_or_create_by!(name: party_name) do |p|
        p.abbreviation = abbreviation
        p.ideology = ideology
      end
      
      parties_created += 1
      puts "  ✅ #{created_party.name} (#{created_party.abbreviation})"
    end
    
    puts "✅ Parties import completed. Total: #{Party.count}"
  end
  
  def import_people_batch(all_records, batch_size)
    total_batches = (all_records.length.to_f / batch_size).ceil
    
    all_records.each_slice(batch_size).with_index do |batch, batch_index|
      puts "\n--- Processing batch #{batch_index + 1}/#{total_batches} (#{batch.length} records) ---"
      
      batch.each_with_index do |record, record_index|
        fields = record['fields']
        
        # Parse name
        official_name = fields['Official Name'] || fields['Candidate Name']
        next if official_name.blank?
        
        # Split name into first and last
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
        
        if record_index < 5 || record_index == batch.length - 1
          puts "  ✅ #{person.full_name} - #{party&.name || 'No party'}"
        end
      end
      
      puts "  Batch #{batch_index + 1} completed. People so far: #{Person.count}"
    end
    
    puts "✅ People import completed. Total: #{Person.count}"
  end
  
  def import_districts_batch(all_records, batch_size)
    puts "Processing districts from #{all_records.length} records..."
    
    districts_data = []
    
    all_records.each do |record|
      fields = record['fields']
      electoral_district = fields['Electoral District']
      level = fields['Level']
      
      next if electoral_district.blank? || level.blank?
      
      # Parse district info
      state, district_info = parse_district_info(electoral_district)
      
      if district_info.present?
        districts_data << {
          state: state,
          district_number: district_info[:number],
          level: map_level(level)
        }
      end
    end
    
    # Remove duplicates
    unique_districts = districts_data.uniq
    puts "Found #{unique_districts.length} unique districts"
    
    # Process in batches
    unique_districts.each_slice(batch_size).with_index do |batch, batch_index|
      puts "\n--- Processing district batch #{batch_index + 1} ---"
      
      batch.each do |district_data|
        District.find_or_create_by!(
          state: district_data[:state],
          district_number: district_data[:district_number],
          level: district_data[:level]
        )
        
        puts "  ✅ #{district_data[:state]} #{district_data[:level]} #{district_data[:district_number]}"
      end
      
      puts "  Districts so far: #{District.count}"
    end
    
    puts "✅ Districts import completed. Total: #{District.count}"
  end
  
  def import_offices_batch(all_records, batch_size)
    puts "Processing offices from #{all_records.length} records..."
    
    offices_data = []
    
    all_records.each do |record|
      fields = record['fields']
      
      office_name = fields['Office Name']
      level = fields['Level']
      state = extract_state_from_fields(fields)
      electoral_district = fields['Electoral District']
      
      next if office_name.blank? || level.blank?
      
      # Find district
      district = nil
      if electoral_district.present?
        state_abbr, district_info = parse_district_info(electoral_district)
        if district_info.present?
          district = District.find_by(
            state: state_abbr,
            district_number: district_info[:number],
            level: map_level(level)
          )
        end
      end
      
      offices_data << {
        title: office_name,
        level: map_level(level),
        branch: map_branch(office_name),
        state: state,
        district: district
      }
    end
    
    # Remove duplicates
    unique_offices = offices_data.uniq
    puts "Found #{unique_offices.length} unique offices"
    
    # Process in batches
    unique_offices.each_slice(batch_size).with_index do |batch, batch_index|
      puts "\n--- Processing office batch #{batch_index + 1} ---"
      
      batch.each do |office_data|
        Office.find_or_create_by!(
          title: office_data[:title],
          level: office_data[:level],
          branch: office_data[:branch],
          state: office_data[:state],
          district: office_data[:district]
        )
        
        district_info = office_data[:district] ? "District #{office_data[:district].district_number}" : "At-large"
        puts "  ✅ #{office_data[:title]} (#{office_data[:state]} #{district_info})"
      end
      
      puts "  Offices so far: #{Office.count}"
    end
    
    puts "✅ Offices import completed. Total: #{Office.count}"
  end
  
  def import_ballots_batch(all_records)
    puts "Creating ballots for each state..."
    
    # Create 2024 general election ballots for each state
    states = all_records.map { |r| extract_state_from_fields(r['fields']) }.compact.uniq
    
    states.each do |state|
      Ballot.find_or_create_by!(
        state: state,
        date: Date.new(2024, 11, 5),
        election_type: 'general'
      )
      
      puts "  ✅ #{state} General Election 2024"
    end
    
    puts "✅ Ballots import completed. Total: #{Ballot.count}"
  end
  
  def import_contests_batch(all_records, batch_size)
    puts "Processing contests from #{all_records.length} records..."
    
    # Filter for 2024 general election candidates only
    election_records = all_records.select { |r| r['fields']['2024 General Election Candidate'] == 'True' }
    puts "Found #{election_records.length} 2024 general election candidates"
    
    contests_created = 0
    
    election_records.each_slice(batch_size).with_index do |batch, batch_index|
      puts "\n--- Processing contest batch #{batch_index + 1} ---"
      
      batch.each do |record|
        fields = record['fields']
        
        office_name = fields['Office Name']
        level = fields['Level']
        state = extract_state_from_fields(fields)
        electoral_district = fields['Electoral District']
        
        next if office_name.blank? || level.blank?
        
        # Find office
        district = nil
        if electoral_district.present?
          state_abbr, district_info = parse_district_info(electoral_district)
          if district_info.present?
            district = District.find_by(
              state: state_abbr,
              district_number: district_info[:number],
              level: map_level(level)
            )
          end
        end
        
        office = Office.find_by(
          title: office_name,
          level: map_level(level),
          branch: map_branch(office_name),
          state: state,
          district: district
        )
        
        next unless office
        
        # Find ballot
        ballot = Ballot.find_by(
          state: state,
          date: Date.new(2024, 11, 5),
          election_type: 'general'
        )
        
        next unless ballot
        
        contest = Contest.find_or_create_by!(
          date: Date.new(2024, 11, 5),
          location: state,
          office: office,
          ballot: ballot
        ) do |contest|
          contest.contest_type = 'general'
        end
        
        if contest
          contests_created += 1
          puts "  ✅ #{office_name} in #{state}" if contests_created <= 10
        end
      end
      
      puts "  Contests so far: #{Contest.count}"
    end
    
    puts "✅ Contests import completed. Total: #{Contest.count}"
  end
  
  def import_candidates_batch(all_records, batch_size)
    puts "Processing candidates from #{all_records.length} records..."
    
    # Filter for 2024 general election candidates only
    election_records = all_records.select { |r| r['fields']['2024 General Election Candidate'] == 'True' }
    puts "Found #{election_records.length} 2024 general election candidates"
    
    candidates_created = 0
    
    election_records.each_slice(batch_size).with_index do |batch, batch_index|
      puts "\n--- Processing candidate batch #{batch_index + 1} ---"
      
      batch.each do |record|
        fields = record['fields']
        
        official_name = fields['Official Name'] || fields['Candidate Name']
        next if official_name.blank?
        
        # Find person
        name_parts = official_name.split(' ')
        first_name = name_parts[0]
        last_name = name_parts[1..].join(' ')
        
        person = Person.find_by(first_name: first_name, last_name: last_name)
        next unless person
        
        # Find contest
        state = extract_state_from_fields(fields)
        office_name = fields['Office Name']
        level = fields['Level']
        
        district = nil
        if fields['Electoral District'].present?
          state_abbr, district_info = parse_district_info(fields['Electoral District'])
          if district_info.present?
            district = District.find_by(
              state: state_abbr,
              district_number: district_info[:number],
              level: map_level(level)
            )
          end
        end
        
        office = Office.find_by(
          title: office_name,
          level: map_level(level),
          branch: map_branch(office_name),
          state: state,
          district: district
        )
        
        next unless office
        
        ballot = Ballot.find_by(
          state: state,
          date: Date.new(2024, 11, 5),
          election_type: 'general'
        )
        
        next unless ballot
        
        contest = Contest.find_by(
          date: Date.new(2024, 11, 5),
          location: state,
          office: office,
          ballot: ballot
        )
        
        next unless contest
        
        # Determine outcome
        outcome = fields['General Election Winner'] == 'Yes' ? 'won' : 'lost'
        
        candidate = Candidate.find_or_create_by!(
          person: person,
          contest: contest
        ) do |candidate|
          candidate.outcome = outcome
          candidate.tally = 0
        end
        
        if candidate
          candidates_created += 1
          puts "  ✅ #{person.full_name} (#{outcome})" if candidates_created <= 10
        end
      end
      
      puts "  Candidates so far: #{Candidate.count}"
    end
    
    puts "✅ Candidates import completed. Total: #{Candidate.count}"
  end
  
  def import_officeholders_batch(all_records, batch_size)
    puts "Processing officeholders from #{all_records.length} records..."
    
    # Filter for current officeholders only
    holder_records = all_records.select { |r| r['fields']['2024 Office Holder'] == true }
    puts "Found #{holder_records.length} current officeholders"
    
    officeholders_created = 0
    
    holder_records.each_slice(batch_size).with_index do |batch, batch_index|
      puts "\n--- Processing officeholder batch #{batch_index + 1} ---"
      
      batch.each do |record|
        fields = record['fields']
        
        official_name = fields['Official Name'] || fields['Candidate Name']
        next if official_name.blank?
        
        # Find person
        name_parts = official_name.split(' ')
        first_name = name_parts[0]
        last_name = name_parts[1..].join(' ')
        
        person = Person.find_by(first_name: first_name, last_name: last_name)
        next unless person
        
        # Find office
        office_name = fields['Office Name']
        level = fields['Level']
        state = extract_state_from_fields(fields)
        
        district = nil
        if fields['Electoral District'].present?
          state_abbr, district_info = parse_district_info(fields['Electoral District'])
          if district_info.present?
            district = District.find_by(
              state: state_abbr,
              district_number: district_info[:number],
              level: map_level(level)
            )
          end
        end
        
        office = Office.find_by(
          title: office_name,
          level: map_level(level),
          branch: map_branch(office_name),
          state: state,
          district: district
        )
        
        next unless office
        
        # Parse dates
        start_date = parse_date(fields['Officeholder Start'])
        end_date = parse_date(fields['Term End'])
        
        officeholder = Officeholder.find_or_create_by!(
          person: person,
          office: office,
          start_date: start_date
        ) do |holder|
          holder.end_date = end_date
        end
        
        if officeholder
          officeholders_created += 1
          puts "  ✅ #{person.full_name}" if officeholders_created <= 10
        end
      end
      
      puts "  Officeholders so far: #{Officeholder.count}"
    end
    
    puts "✅ Officeholders import completed. Total: #{Officeholder.count}"
  end
  
  # Helper methods (same as before)
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
  
  def parse_district_info(electoral_district)
    return [nil, nil] if electoral_district.blank?
    
    match = electoral_district.match(/^(\w+)'s (\d+)[\w\s]*district/i)
    if match
      [state_abbreviation(match[1]), { number: match[2].to_i }]
    else
      match = electoral_district.match(/^(\w{2}),.*?District (\d+)/i)
      if match
        [match[1], { number: match[2].to_i }]
      else
        [nil, nil]
      end
    end
  end
  
  def state_abbreviation(state_name)
    state_map = {
      'Alabama' => 'AL', 'Alaska' => 'AK', 'Arizona' => 'AZ', 'Arkansas' => 'AR',
      'California' => 'CA', 'Colorado' => 'CO', 'Connecticut' => 'CT', 'Delaware' => 'DE',
      'Florida' => 'FL', 'Georgia' => 'GA', 'Hawaii' => 'HI', 'Idaho' => 'ID',
      'Illinois' => 'IL', 'Indiana' => 'IN', 'Iowa' => 'IA', 'Kansas' => 'KS',
      'Kentucky' => 'KY', 'Louisiana' => 'LA', 'Maine' => 'ME', 'Maryland' => 'MD',
      'Massachusetts' => 'MA', 'Michigan' => 'MI', 'Minnesota' => 'MN', 'Mississippi' => 'MS',
      'Missouri' => 'MO', 'Montana' => 'MT', 'Nebraska' => 'NE', 'Nevada' => 'NV',
      'New Hampshire' => 'NH', 'New Jersey' => 'NJ', 'New Mexico' => 'NM', 'New York' => 'NY',
      'North Carolina' => 'NC', 'North Dakota' => 'ND', 'Ohio' => 'OH', 'Oklahoma' => 'OK',
      'Oregon' => 'OR', 'Pennsylvania' => 'PA', 'Rhode Island' => 'RI', 'South Carolina' => 'SC',
      'South Dakota' => 'SD', 'Tennessee' => 'TN', 'Texas' => 'TX', 'Utah' => 'UT',
      'Vermont' => 'VT', 'Virginia' => 'VA', 'Washington' => 'WA', 'West Virginia' => 'WV',
      'Wisconsin' => 'WI', 'Wyoming' => 'WY'
    }
    
    state_map[state_name] || state_name[0..1].upcase
  end
  
  def map_level(level)
    case level
    when 'country' then 'federal'
    when 'state' then 'state'
    when 'local' then 'local'
    else level
    end
  end
  
  def map_branch(office_name)
    case office_name
    when /President|Vice President/ then 'executive'
    when /Representative|Senator|House|Senate/ then 'legislative'
    when /Governor/ then 'executive'
    when /Judge|Court/ then 'judicial'
    else 'executive'
    end
  end
end
