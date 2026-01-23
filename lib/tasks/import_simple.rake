namespace :import_simple do
  desc "Import all data in small batches"
  task all: :environment do
    puts "Starting simplified import with small batches..."
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    airtable = AirtableService.instance
    
    # Step 1: Import parties
    puts "\n=== Step 1: Importing Parties ==="
    import_parties_simple(airtable)
    
    # Step 2: Import people
    puts "\n=== Step 2: Importing People ==="
    import_people_simple(airtable)
    
    # Step 3: Import districts
    puts "\n=== Step 3: Importing Districts ==="
    import_districts_simple(airtable)
    
    # Step 4: Import offices
    puts "\n=== Step 4: Importing Offices ==="
    import_offices_simple(airtable)
    
    # Step 5: Import ballots
    puts "\n=== Step 5: Importing Ballots ==="
    import_ballots_simple(airtable)
    
    # Step 6: Import contests
    puts "\n=== Step 6: Importing Contests ==="
    import_contests_simple(airtable)
    
    # Step 7: Import candidates
    puts "\n=== Step 7: Importing Candidates ==="
    import_candidates_simple(airtable)
    
    # Step 8: Import officeholders
    puts "\n=== Step 8: Importing Officeholders ==="
    import_officeholders_simple(airtable)
    
    puts "\n✅ Import completed!"
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
  
  desc "Import parties only"
  task parties: :environment do
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    airtable = AirtableService.instance
    import_parties_simple(airtable)
  end
  
  desc "Import people only"
  task people: :environment do
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    airtable = AirtableService.instance
    import_people_simple(airtable)
  end
  
  desc "Import districts only"
  task districts: :environment do
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    airtable = AirtableService.instance
    import_districts_simple(airtable)
  end
  
  desc "Import offices only"
  task offices: :environment do
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    airtable = AirtableService.instance
    import_offices_simple(airtable)
  end
  
  private
  
  def import_parties_simple(airtable)
    puts "Fetching all records to extract parties..."
    
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "  Fetched #{all_records.length} total records"
    
    # Extract unique parties
    party_names = all_records.map { |r| r['fields']['Registered Political Party'] }.compact.uniq
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
      
      created_party = Party.find_or_create_by!(name: party_name) do |p|
        p.abbreviation = abbreviation
        p.ideology = ideology
      end
      
      puts "  ✅ Created/updated party: #{created_party.name}"
    end
    
    puts "✅ Parties import completed. Total: #{Party.count}"
  end
  
  def import_people_simple(airtable)
    puts "Importing people..."
    
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "  Fetched #{all_records.length} total records"
    
    puts "Processing #{all_records.length} people records..."
    
    all_records.each_with_index do |record, index|
      fields = record['fields']
      
      # Show progress every 10 records
      if (index + 1) % 10 == 0
        puts "  Processed #{index + 1}/#{all_records.length} people..."
      end
      
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
      
      Person.find_or_create_by!(
        first_name: first_name,
        last_name: last_name
      ) do |person|
        person.party_affiliation = party
        person.birth_date = birth_date
        person.death_date = nil
        person.state_of_residence = state
      end
    end
    
    puts "✅ People import completed. Total: #{Person.count}"
  end
  
  def import_districts_simple(airtable)
    puts "Importing districts..."
    
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "  Fetched #{all_records.length} total records"
    
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
    
    # Remove duplicates and create districts
    districts_data.uniq.each do |district_data|
      District.find_or_create_by!(
        state: district_data[:state],
        district_number: district_data[:district_number],
        level: district_data[:level]
      )
      
      puts "  ✅ Created district: #{district_data[:state]} #{district_data[:level]} #{district_data[:district_number]}"
    end
    
    puts "✅ Districts import completed. Total: #{District.count}"
  end
  
  def import_offices_simple(airtable)
    puts "Importing offices..."
    
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "  Fetched #{all_records.length} total records"
    
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
    
    # Remove duplicates and create offices
    offices_data.uniq.each do |office_data|
      Office.find_or_create_by!(
        title: office_data[:title],
        level: office_data[:level],
        branch: office_data[:branch],
        state: office_data[:state],
        district: office_data[:district]
      )
      
      district_info = office_data[:district] ? "District #{office_data[:district].district_number}" : "At-large"
      puts "  ✅ Created office: #{office_data[:title]} (#{office_data[:state]} #{district_info})"
    end
    
    puts "✅ Offices import completed. Total: #{Office.count}"
  end
  
  def import_ballots_simple(airtable)
    puts "Importing ballots..."
    
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "  Fetched #{all_records.length} total records"
    
    # Create 2024 general election ballots for each state
    states = all_records.map { |r| extract_state_from_fields(r['fields']) }.compact.uniq
    
    states.each do |state|
      Ballot.find_or_create_by!(
        state: state,
        date: Date.new(2024, 11, 5),
        election_type: 'general'
      )
      
      puts "  ✅ Created ballot: #{state} General Election 2024"
    end
    
    puts "✅ Ballots import completed. Total: #{Ballot.count}"
  end
  
  def import_contests_simple(airtable)
    puts "Importing contests..."
    
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "  Fetched #{all_records.length} total records"
    
    contests_created = 0
    
    all_records.each do |record|
      fields = record['fields']
      
      # Only import for 2024 general election candidates
      next unless fields['2024 General Election Candidate'] == 'True'
      
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
        puts "  ✅ Created contest: #{office_name} in #{state}" if contests_created <= 10
      end
    end
    
    puts "✅ Contests import completed. Total: #{Contest.count}"
  end
  
  def import_candidates_simple(airtable)
    puts "Importing candidates..."
    
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "  Fetched #{all_records.length} total records"
    
    candidates_created = 0
    
    all_records.each do |record|
      fields = record['fields']
      
      # Only import for 2024 general election candidates
      next unless fields['2024 General Election Candidate'] == 'True'
      
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
        candidate.tally = 0 # Vote counts not available in current data
      end
      
      if candidate
        candidates_created += 1
        puts "  ✅ Created candidate: #{person.full_name} (#{outcome})" if candidates_created <= 10
      end
    end
    
    puts "✅ Candidates import completed. Total: #{Candidate.count}"
  end
  
  def import_officeholders_simple(airtable)
    puts "Importing officeholders..."
    
    response = airtable.fetch_records('People')
    all_records = response['records'] || []
    
    puts "  Fetched #{all_records.length} total records"
    
    officeholders_created = 0
    
    all_records.each do |record|
      fields = record['fields']
      
      # Only import current officeholders
      next unless fields['2024 Office Holder'] == true
      
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
        puts "  ✅ Created officeholder: #{person.full_name}" if officeholders_created <= 10
      end
    end
    
    puts "✅ Officeholders import completed. Total: #{Officeholder.count}"
  end
  
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
    
    # Parse formats like "California's 8th congressional district" or "OR, U.S. Representative District 3"
    match = electoral_district.match(/^(\w+)'s (\d+)[\w\s]*district/i)
    if match
      [state_abbreviation(match[1]), { number: match[2].to_i }]
    else
      # Try alternative format
      match = electoral_district.match(/^(\w{2}),.*?District (\d+)/i)
      if match
        [match[1], { number: match[2].to_i }]
      else
        [nil, nil]
      end
    end
  end
  
  def state_abbreviation(state_name)
    # Simple state name to abbreviation mapping
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
