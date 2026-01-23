class CandidateImportService
  def initialize(airtable_service)
    @airtable = airtable_service
  end
  
  def import_2024_candidates
    puts "Starting import of 2024 candidates from Airtable..."
    
    # Import parties first (they're referenced by people)
    import_parties_from_airtable
    
    # Import people from Airtable
    import_people_from_airtable
    
    # Import districts from Airtable data
    import_districts_from_airtable
    
    # Import offices from Airtable data
    import_offices_from_airtable
    
    # Import ballots (2024 general election)
    import_ballots_from_airtable
    
    # Import contests from Airtable data
    import_contests_from_airtable
    
    # Import candidates (the join table)
    import_candidates_from_airtable
    
    # Import officeholders
    import_officeholders_from_airtable
    
    puts "Import completed successfully!"
  end
  
  private
  
  def import_parties_from_airtable
    puts "Importing parties from Airtable..."
    
    # Extract unique parties from People records
    records = @airtable.all_records('People')
    party_names = records.map { |r| r['fields']['Registered Political Party'] }.compact.uniq
    
    party_names.each do |party_name|
      next if party_name.blank?
      
      # Map party names to abbreviations
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
      
      Party.find_or_create_by!(name: party_name) do |party|
        party.abbreviation = abbreviation
        party.ideology = ideology
      end
    end
    
    puts "Created #{Party.count} parties"
  end
  
  def import_people_from_airtable
    puts "Importing people from Airtable..."
    
    records = @airtable.all_records('People')
    
    records.each do |record|
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
      term_start = parse_date(fields['Officeholder Start'])
      term_end = parse_date(fields['Term End'])
      
      # Extract state from contest or electoral district
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
    
    puts "Created #{Person.count} people"
  end
  
  def import_districts_from_airtable
    puts "Importing districts from Airtable..."
    
    records = @airtable.all_records('People')
    
    districts_data = []
    
    records.each do |record|
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
    
    districts_data.uniq.each do |district_data|
      District.find_or_create_by!(
        state: district_data[:state],
        district_number: district_data[:district_number],
        level: district_data[:level]
      )
    end
    
    puts "Created #{District.count} districts"
  end
  
  def import_offices_from_airtable
    puts "Importing offices from Airtable..."
    
    records = @airtable.all_records('People')
    
    offices_data = []
    
    records.each do |record|
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
    
    offices_data.uniq.each do |office_data|
      Office.find_or_create_by!(
        title: office_data[:title],
        level: office_data[:level],
        branch: office_data[:branch],
        state: office_data[:state],
        district: office_data[:district]
      )
    end
    
    puts "Created #{Office.count} offices"
  end
  
  def import_ballots_from_airtable
    puts "Importing ballots from Airtable..."
    
    # Create 2024 general election ballots for each state
    states = @airtable.all_records('People').map { |r| extract_state_from_fields(r['fields']) }.compact.uniq
    
    states.each do |state|
      Ballot.find_or_create_by!(
        state: state,
        date: Date.new(2024, 11, 5),
        election_type: 'general'
      )
    end
    
    puts "Created #{Ballot.count} ballots"
  end
  
  def import_contests_from_airtable
    puts "Importing contests from Airtable..."
    
    records = @airtable.all_records('People')
    
    records.each do |record|
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
      
      Contest.find_or_create_by!(
        date: Date.new(2024, 11, 5),
        location: state,
        office: office,
        ballot: ballot
      ) do |contest|
        contest.contest_type = 'general'
      end
    end
    
    puts "Created #{Contest.count} contests"
  end
  
  def import_candidates_from_airtable
    puts "Importing candidates from Airtable..."
    
    records = @airtable.all_records('People')
    
    records.each do |record|
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
      
      Candidate.find_or_create_by!(
        person: person,
        contest: contest
      ) do |candidate|
        candidate.outcome = outcome
        candidate.tally = 0 # Vote counts not available in current data
      end
    end
    
    puts "Created #{Candidate.count} candidate records"
  end
  
  def import_officeholders_from_airtable
    puts "Importing officeholders from Airtable..."
    
    records = @airtable.all_records('People')
    
    records.each do |record|
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
      
      Officeholder.find_or_create_by!(
        person: person,
        office: office,
        start_date: start_date
      ) do |holder|
        holder.end_date = end_date
      end
    end
    
    puts "Created #{Officeholder.count} officeholder records"
  end
  
  # Helper methods
  def parse_date(date_string)
    return nil if date_string.blank?
    
    # Handle various date formats
    Date.strptime(date_string, '%m/%d/%y') rescue 
    Date.strptime(date_string, '%Y-%m-%d') rescue
    Date.strptime(date_string, '%m/%d/%Y') rescue
    nil
  end
  
  def extract_state_from_fields(fields)
    # Try to extract state from various fields
    state = fields['State']
    return state if state.present?
    
    # Try to extract from contest field
    contest = fields['Contest']
    if contest.present?
      match = contest.match(/^(\w{2}),/)
      return match[1] if match
    end
    
    # Try to extract from electoral district
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
