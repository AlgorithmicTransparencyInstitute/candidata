require 'csv'

namespace :govproj do
  desc "Analyze the govproj CSV files structure and content"
  task analyze: :environment do
    puts "=" * 70
    puts "GOVPROJ CSV ANALYSIS"
    puts "=" * 70

    csv_dir = Rails.root.join('data', 'govproj')
    all_rows = []
    
    # Read all CSV files
    Dir.glob(csv_dir.join('*.csv')).sort.each do |file|
      state = File.basename(file, '_office_holders.csv').upcase
      CSV.foreach(file, col_sep: "\t", headers: true, liberal_parsing: true) do |row|
        all_rows << row
      end
      puts "  #{state}: #{all_rows.length} total records"
    end

    puts "\n" + "=" * 70
    puts "TOTAL RECORDS: #{all_rows.length}"
    puts "=" * 70

    # Get headers from first file
    sample_file = Dir.glob(csv_dir.join('*.csv')).first
    headers = CSV.read(sample_file, col_sep: "\t", headers: true, liberal_parsing: true).headers
    
    puts "\n=== COLUMNS (#{headers.length}) ==="
    headers.each_with_index do |h, i|
      puts "  #{(i+1).to_s.rjust(2)}. #{h}"
    end

    # Analyze unique values for key columns
    puts "\n=== UNIQUE VALUES BY COLUMN ==="
    
    key_columns = ['State', 'Level', 'Role', 'Office Category', 'Body Name', 'Party Roll Up']
    
    key_columns.each do |col|
      values = all_rows.map { |r| r.is_a?(CSV::Row) ? r[col] : nil }.compact.reject { |v| v.to_s.empty? }.tally.sort_by { |k, v| -v }
      puts "\n#{col} (#{values.length} unique):"
      values.first(15).each do |val, count|
        puts "  #{count.to_s.rjust(6)} | #{val}"
      end
      puts "  ... and #{values.length - 15} more" if values.length > 15
    end

    # Check for new fields not in our schema
    puts "\n" + "=" * 70
    puts "SCHEMA COMPARISON"
    puts "=" * 70
    
    existing_person_fields = %w[first_name last_name middle_name suffix gender race photo_url 
                                website_official website_campaign website_personal 
                                birth_date death_date state_of_residence person_uuid airtable_id]
    
    existing_office_fields = %w[title level branch state office_category body_name seat role
                                jurisdiction jurisdiction_ocdid ocdid airtable_id]
    
    govproj_person_fields = {
      'Person UUID' => 'person_uuid',
      'Official Name' => 'needs parsing to first/last',
      'DOB' => 'birth_date',
      'Photo URL' => 'photo_url',
      'Wiki Word' => 'NEW - wikipedia reference',
      'Registered Political Party' => 'party link',
      'Party Roll Up' => 'party link (simplified)',
    }
    
    govproj_office_fields = {
      'Office UUID' => 'airtable_id equivalent',
      'Office Name' => 'title',
      'Office Category' => 'office_category',
      'Body Name' => 'body_name',
      'Seat' => 'seat',
      'Level' => 'level (needs mapping)',
      'Role' => 'role',
      'Jurisdiction' => 'jurisdiction',
      'Jurisdiction OCDID' => 'jurisdiction_ocdid',
      'Electoral District' => 'district name',
      'Electoral District OCDID' => 'ocdid',
      'County' => 'NEW - county for local offices',
    }
    
    govproj_officeholder_fields = {
      'Term End' => 'end_date',
      'Officeholder Start' => 'start_date',
      'Expires' => 'term expiration info',
      'Next Election Date' => 'NEW - next election',
      'Regular Election Date' => 'NEW - regular election cycle',
    }
    
    govproj_contact_fields = {
      'Gov Email' => 'NEW - official email',
      'Gov Email Form' => 'NEW - contact form URL',
      'Gov Phone' => 'NEW - official phone',
      'Gov Mailing Address' => 'NEW - official address',
      'Website (Official)' => 'website_official',
    }
    
    govproj_social_fields = {
      'Youtube (Gov)' => 'SocialMediaAccount - YouTube',
      'Instagram URL (Gov)' => 'SocialMediaAccount - Instagram',
      'Twitter Name (Gov)' => 'SocialMediaAccount - Twitter',
      'Facebook URL (Gov)' => 'SocialMediaAccount - Facebook',
      'TikTok (Gov)' => 'SocialMediaAccount - TikTok',
      'Threads (Gov)' => 'SocialMediaAccount - Threads',
    }
    
    puts "\n=== NEW FIELDS TO CONSIDER ==="
    puts "\nPerson/Officeholder Contact Info (not in current schema):"
    govproj_contact_fields.each { |k, v| puts "  - #{k}: #{v}" }
    
    puts "\nOffice/Officeholder Temporal Info:"
    puts "  - Next Election Date: useful for tracking upcoming elections"
    puts "  - Regular Election Date: election cycle pattern"
    puts "  - County: for local office jurisdiction"
    
    puts "\nPerson Metadata:"
    puts "  - Wiki Word: Wikipedia article reference (e.g., 'Ted_Cruz')"
  end

  desc "Count total records across all govproj files"
  task count: :environment do
    csv_dir = Rails.root.join('data', 'govproj')
    total = 0
    
    Dir.glob(csv_dir.join('*.csv')).sort.each do |file|
      rows = CSV.read(file, col_sep: "\t", headers: true, liberal_parsing: true)
      total += rows.length
    end
    
    puts "Total records across all govproj files: #{total}"
  end

  desc "Load all govproj CSV data into temp_govproj staging table"
  task load_temp: :environment do
    puts "=" * 70
    puts "LOADING GOVPROJ DATA INTO TEMP TABLE"
    puts "=" * 70
    
    csv_dir = Rails.root.join('data', 'govproj')
    
    # Clear existing temp data
    TempGovproj.delete_all
    puts "Cleared existing temp_govproj records."
    
    total = 0
    
    Dir.glob(csv_dir.join('*.csv')).sort.each do |file|
      state_abbrev = File.basename(file, '_office_holders.csv').upcase
      count = 0
      
      CSV.foreach(file, col_sep: "\t", headers: true, liberal_parsing: true) do |row|
        TempGovproj.create!(
          state: row['State']&.strip,
          level: row['Level']&.strip,
          jurisdiction: row['Jurisdiction']&.strip,
          jurisdiction_ocdid: row['Jurisdiction OCDID']&.strip,
          electoral_district: row['Electoral District']&.strip,
          electoral_district_ocdid: row['Electoral District OCDID']&.strip,
          county: row['County']&.strip,
          office_uuid: row['Office UUID']&.strip,
          seat: row['Seat']&.strip,
          office_name: row['Office Name']&.strip,
          office_category: row['Office Category']&.strip,
          body_name: row['Body Name']&.strip,
          role: row['Role']&.strip,
          term_end: row['Term End']&.strip,
          expires: row['Expires']&.strip,
          officeholder_start: row['Officeholder Start']&.strip,
          next_election_date: row['Next Election Date']&.strip,
          regular_election_date: row['Regular Election Date']&.strip,
          person_uuid: row['Person UUID']&.strip,
          official_name: row['Official Name']&.strip,
          dob: row['DOB']&.strip,
          wiki_word: row['Wiki Word']&.strip,
          photo_url: row['Photo URL']&.strip,
          registered_political_party: row['Registered Political Party']&.strip,
          party_roll_up: row['Party Roll Up']&.strip,
          gov_email: row['Gov Email']&.strip,
          gov_email_form: row['Gov Email Form']&.strip,
          gov_phone: row['Gov Phone']&.strip,
          gov_mailing_address: row['Gov Mailing Address']&.strip,
          website_official: row['Website (Official)']&.strip,
          youtube_gov: row['YouTube (Gov)']&.strip,
          instagram_url_gov: row['Instagram URL (Gov)']&.strip,
          twitter_name_gov: row['Twitter Name (Gov)']&.strip,
          facebook_url_gov: row['Facebook URL (Gov)']&.strip,
          tiktok_gov: row['TikTok (Gov)']&.strip,
          threads_gov: row['Threads (Gov)']&.strip
        )
        count += 1
      end
      
      total += count
      puts "  #{state_abbrev}: #{count} records"
    end
    
    puts "\n" + "=" * 70
    puts "LOAD COMPLETE: #{total} records in temp_govproj"
    puts "=" * 70
  end

  desc "Analyze temp_govproj for distinct values (run after load_temp)"
  task analyze_temp: :environment do
    puts "=" * 70
    puts "ANALYZING TEMP_GOVPROJ DATA"
    puts "=" * 70
    puts "Total records: #{TempGovproj.count}"
    
    puts "\n--- STATES (#{TempGovproj.distinct.count(:state)}) ---"
    TempGovproj.group(:state).count.sort.each { |s, c| puts "  #{s}: #{c}" }
    
    puts "\n--- LEVELS (#{TempGovproj.distinct.count(:level)}) ---"
    TempGovproj.group(:level).count.sort_by { |k, v| -v }.each { |l, c| puts "  #{c.to_s.rjust(6)} | #{l}" }
    
    puts "\n--- ROLES (#{TempGovproj.distinct.count(:role)}) ---"
    TempGovproj.group(:role).count.sort_by { |k, v| -v }.each { |r, c| puts "  #{c.to_s.rjust(6)} | #{r}" }
    
    puts "\n--- PARTIES (#{TempGovproj.distinct.count(:party_roll_up)}) ---"
    TempGovproj.group(:party_roll_up).count.sort_by { |k, v| -v }.each { |p, c| puts "  #{c.to_s.rjust(6)} | #{p}" }
    
    puts "\n--- OFFICE CATEGORIES (#{TempGovproj.distinct.count(:office_category)}) ---"
    TempGovproj.group(:office_category).count.sort_by { |k, v| -v }.each { |o, c| puts "  #{c.to_s.rjust(6)} | #{o}" }
    
    puts "\n--- UNIQUE COUNTS ---"
    puts "  Distinct offices (by UUID): #{TempGovproj.distinct.count(:office_uuid)}"
    puts "  Distinct people (by UUID): #{TempGovproj.distinct.count(:person_uuid)}"
    puts "  Distinct jurisdictions: #{TempGovproj.distinct.count(:jurisdiction)}"
    
    puts "=" * 70
  end

  desc "Import offices from govproj (state/local to complement seeded federal offices)"
  task import_offices: :environment do
    puts "=" * 70
    puts "IMPORTING OFFICES FROM GOVPROJ"
    puts "=" * 70
    puts "Note: This adds state/local offices. Federal offices come from db:seed."
    
    csv_dir = Rails.root.join('data', 'govproj')
    stats = { created: 0, skipped: 0, errors: [] }
    
    map_level = ->(level) {
      case level
      when 'country' then 'federal'
      when 'administrativeArea1' then 'state'
      when 'administrativeArea2', 'locality', 'regional' then 'local'
      else 'local'
      end
    }

    map_branch = ->(role) {
      case role
      when 'legislatorLowerBody', 'legislatorUpperBody' then 'legislative'
      when 'headOfGovernment', 'deputyHeadOfGovernment', 'governmentOfficer', 'executiveCouncil', 'schoolBoard' then 'executive'
      when 'highestCourtJudge', 'judge' then 'judicial'
      else 'executive'
      end
    }

    Dir.glob(csv_dir.join('*.csv')).sort.each do |file|
      state_abbrev = File.basename(file, '_office_holders.csv').upcase
      
      CSV.foreach(file, col_sep: "\t", headers: true, liberal_parsing: true) do |row|
        begin
          office_uuid = row['Office UUID']&.strip
          next if office_uuid.blank?
          
          # Skip if office already exists (by UUID)
          if Office.exists?(airtable_id: office_uuid)
            stats[:skipped] += 1
            next
          end
          
          Office.create!(
            airtable_id: office_uuid,
            title: row['Office Name']&.strip || 'Unknown Office',
            level: map_level.call(row['Level']&.strip),
            branch: map_branch.call(row['Role']&.strip),
            role: row['Role']&.strip,
            state: row['State']&.strip,
            office_category: row['Office Category']&.strip,
            body_name: row['Body Name']&.strip,
            seat: row['Seat']&.strip.presence,
            jurisdiction: row['Jurisdiction']&.strip,
            jurisdiction_ocdid: row['Jurisdiction OCDID']&.strip,
            ocdid: row['Electoral District OCDID']&.strip,
            county: row['County']&.strip.presence
          )
          stats[:created] += 1
        rescue => e
          stats[:errors] << "#{state_abbrev}: #{row['Office Name']} - #{e.message}"
        end
      end
      
      print "."
    end
    
    puts "\n\n" + "=" * 70
    puts "OFFICES IMPORT COMPLETE"
    puts "=" * 70
    puts "  Created: #{stats[:created]}"
    puts "  Skipped (existing): #{stats[:skipped]}"
    puts "  Errors: #{stats[:errors].length}"
    stats[:errors].first(5).each { |e| puts "    - #{e}" } if stats[:errors].any?
    puts "  Total offices now: #{Office.count}"
    puts "=" * 70
  end

  desc "Import people and officeholders from govproj (transactional data)"
  task import_people: :environment do
    puts "=" * 70
    puts "IMPORTING PEOPLE & OFFICEHOLDERS FROM GOVPROJ"
    puts "=" * 70
    puts "Prereq: Run 'rake db:seed' and 'rake govproj:import_offices' first."
    puts "This task does NOT touch parties or offices - only people/officeholders."

    csv_dir = Rails.root.join('data', 'govproj')
    
    stats = {
      people_created: 0,
      people_found: 0,
      officeholders_created: 0,
      officeholders_skipped: 0,
      offices_missing: 0,
      party_links: 0,
      errors: []
    }

    parse_name = ->(full_name) {
      return { first_name: 'Unknown', last_name: 'Unknown' } if full_name.blank?
      name = full_name.dup
      suffixes = ['Jr.', 'Jr', 'Sr.', 'Sr', 'II', 'III', 'IV', 'V']
      suffix = nil
      suffixes.each do |s|
        pattern = Regexp.new('[,\s]\s*' + Regexp.escape(s) + '\.?\s*$', Regexp::IGNORECASE)
        if name.match?(pattern)
          suffix = s.sub(/\.$/, '')
          suffix = suffix + '.' if ['Jr', 'Sr'].include?(suffix)
          name = name.sub(pattern, '').strip
          break
        end
      end
      parts = name.split(/\s+/)
      if parts.length == 1
        { first_name: parts[0], last_name: 'Unknown', suffix: suffix }
      elsif parts.length == 2
        { first_name: parts[0], last_name: parts[1], suffix: suffix }
      else
        { first_name: parts[0], middle_name: parts[1..-2].join(' '), last_name: parts[-1], suffix: suffix }
      end
    }

    parse_date = ->(str) {
      return nil if str.blank?
      Date.parse(str) rescue nil
    }

    Dir.glob(csv_dir.join('*.csv')).sort.each do |file|
      state_abbrev = File.basename(file, '_office_holders.csv').upcase
      
      CSV.foreach(file, col_sep: "\t", headers: true, liberal_parsing: true) do |row|
        begin
          # 1. Find or create Person
          person_uuid = row['Person UUID']&.strip
          next if person_uuid.blank?
          
          person = Person.find_by(person_uuid: person_uuid)
          unless person
            np = parse_name.call(row['Official Name']&.strip)
            person = Person.create!(
              person_uuid: person_uuid,
              first_name: np[:first_name],
              last_name: np[:last_name],
              middle_name: np[:middle_name],
              suffix: np[:suffix],
              birth_date: parse_date.call(row['DOB']),
              photo_url: row['Photo URL']&.strip.presence,
              website_official: row['Website (Official)']&.strip.presence,
              wikipedia_id: row['Wiki Word']&.strip.presence,
              state_of_residence: row['State']&.strip
            )
            stats[:people_created] += 1
          else
            stats[:people_found] += 1
          end
          
          # 2. Find Office (must already exist from import_offices or db:seed)
          office_uuid = row['Office UUID']&.strip
          next if office_uuid.blank?
          
          office = Office.find_by(airtable_id: office_uuid)
          unless office
            stats[:offices_missing] += 1
            stats[:errors] << "#{state_abbrev}: Office not found: #{row['Office Name']}" if stats[:offices_missing] <= 10
            next
          end
          
          # 3. Create Officeholder (if not exists)
          start_date = parse_date.call(row['Officeholder Start']) || Date.current
          existing = Officeholder.find_by(person: person, office: office, start_date: start_date)
          if existing
            stats[:officeholders_skipped] += 1
          else
            Officeholder.create!(
              person: person,
              office: office,
              start_date: start_date,
              term_end_date: parse_date.call(row['Term End']),
              next_election_date: parse_date.call(row['Next Election Date']),
              official_email: row['Gov Email']&.strip.presence,
              official_phone: row['Gov Phone']&.strip.presence,
              official_address: row['Gov Mailing Address']&.strip.presence,
              contact_form_url: row['Gov Email Form']&.strip.presence
            )
            stats[:officeholders_created] += 1
          end
          
          # 4. Link Party (party must already exist from db:seed)
          party_name = row['Party Roll Up']&.strip
          if party_name.present?
            party = Party.find_by(name: party_name)
            if party && !person.parties.include?(party)
              person.add_party(party, is_primary: person.parties.empty?)
              stats[:party_links] += 1
            end
          end
          
        rescue => e
          stats[:errors] << "#{state_abbrev}: #{row['Official Name']} - #{e.message}"
        end
      end
      
      print "."
    end

    puts "\n\n" + "=" * 70
    puts "PEOPLE/OFFICEHOLDERS IMPORT COMPLETE"
    puts "=" * 70
    puts "  People created: #{stats[:people_created]}"
    puts "  People found (existing): #{stats[:people_found]}"
    puts "  Officeholders created: #{stats[:officeholders_created]}"
    puts "  Officeholders skipped: #{stats[:officeholders_skipped]}"
    puts "  Offices missing: #{stats[:offices_missing]}"
    puts "  Party links added: #{stats[:party_links]}"
    puts "  Errors: #{stats[:errors].length}"
    
    if stats[:errors].any?
      puts "\nFirst 10 errors:"
      stats[:errors].first(10).each { |e| puts "  - #{e}" }
    end
    puts "\nDB Totals: People=#{Person.count}, Officeholders=#{Officeholder.count}"
    puts "=" * 70
  end

  desc "Full import: offices first, then people/officeholders"
  task import: [:import_offices, :import_people]

  desc "Import a single state for testing (e.g., rake govproj:import_state[DC])"
  task :import_state, [:state] => :environment do |t, args|
    state = args[:state]&.upcase
    abort "Usage: rake govproj:import_state[STATE] (e.g., DC, TX, CA)" unless state

    puts "=" * 70
    puts "IMPORTING SINGLE STATE: #{state}"
    puts "=" * 70

    file = Rails.root.join('data', 'govproj', "#{state.downcase}_office_holders.csv")
    abort "File not found: #{file}" unless File.exist?(file)

    stats = {
      offices_created: 0, offices_skipped: 0,
      people_created: 0, people_found: 0,
      officeholders_created: 0, officeholders_skipped: 0,
      social_accounts: 0, party_links: 0,
      errors: []
    }

    map_level = ->(level) {
      case level
      when 'country' then 'federal'
      when 'administrativeArea1' then 'state'
      when 'administrativeArea2', 'locality', 'regional' then 'local'
      else 'local'
      end
    }

    map_branch = ->(role) {
      case role
      when 'legislatorLowerBody', 'legislatorUpperBody' then 'legislative'
      when 'headOfGovernment', 'deputyHeadOfGovernment', 'governmentOfficer', 'executiveCouncil', 'schoolBoard' then 'executive'
      when 'highestCourtJudge', 'judge' then 'judicial'
      else 'executive'
      end
    }

    parse_name = ->(full_name) {
      return { first_name: 'Unknown', last_name: 'Unknown' } if full_name.blank?
      name = full_name.dup
      suffixes = ['Jr.', 'Jr', 'Sr.', 'Sr', 'II', 'III', 'IV', 'V']
      suffix = nil
      suffixes.each do |s|
        pattern = Regexp.new('[,\s]\s*' + Regexp.escape(s) + '\.?\s*$', Regexp::IGNORECASE)
        if name.match?(pattern)
          suffix = s.sub(/\.$/, '')
          suffix = suffix + '.' if ['Jr', 'Sr'].include?(suffix)
          name = name.sub(pattern, '').strip
          break
        end
      end
      parts = name.split(/\s+/)
      if parts.length == 1
        { first_name: parts[0], last_name: 'Unknown', suffix: suffix }
      elsif parts.length == 2
        { first_name: parts[0], last_name: parts[1], suffix: suffix }
      else
        { first_name: parts[0], middle_name: parts[1..-2].join(' '), last_name: parts[-1], suffix: suffix }
      end
    }

    parse_date = ->(str) {
      return nil if str.blank?
      Date.parse(str) rescue nil
    }

    CSV.foreach(file, col_sep: "\t", headers: true, liberal_parsing: true) do |row|
      begin
        office_uuid = row['Office UUID']&.strip
        person_uuid = row['Person UUID']&.strip
        next if office_uuid.blank? || person_uuid.blank?

        # 1. Find or create Office
        office = Office.find_by(airtable_id: office_uuid)
        unless office
          office = Office.create!(
            airtable_id: office_uuid,
            title: row['Office Name']&.strip || 'Unknown Office',
            level: map_level.call(row['Level']&.strip),
            branch: map_branch.call(row['Role']&.strip),
            role: row['Role']&.strip,
            state: row['State']&.strip,
            office_category: row['Office Category']&.strip,
            body_name: row['Body Name']&.strip,
            seat: row['Seat']&.strip.presence,
            jurisdiction: row['Jurisdiction']&.strip,
            jurisdiction_ocdid: row['Jurisdiction OCDID']&.strip,
            ocdid: row['Electoral District OCDID']&.strip,
            county: row['County']&.strip.presence
          )
          stats[:offices_created] += 1
        else
          stats[:offices_skipped] += 1
        end

        # 2. Find or create Person
        person = Person.find_by(person_uuid: person_uuid)
        unless person
          np = parse_name.call(row['Official Name']&.strip)
          person = Person.create!(
            person_uuid: person_uuid,
            first_name: np[:first_name],
            last_name: np[:last_name],
            middle_name: np[:middle_name],
            suffix: np[:suffix],
            birth_date: parse_date.call(row['DOB']),
            photo_url: row['Photo URL']&.strip.presence,
            website_official: row['Website (Official)']&.strip.presence,
            wikipedia_id: row['Wiki Word']&.strip.presence,
            state_of_residence: row['State']&.strip
          )
          stats[:people_created] += 1
        else
          stats[:people_found] += 1
        end

        # 3. Create Officeholder
        start_date = parse_date.call(row['Officeholder Start']) || Date.current
        existing_oh = Officeholder.find_by(person: person, office: office)
        if existing_oh
          stats[:officeholders_skipped] += 1
        else
          Officeholder.create!(
            person: person,
            office: office,
            start_date: start_date,
            term_end_date: parse_date.call(row['Term End']),
            next_election_date: parse_date.call(row['Next Election Date']),
            official_email: row['Gov Email']&.strip.presence,
            official_phone: row['Gov Phone']&.strip.presence,
            official_address: row['Gov Mailing Address']&.strip.presence,
            contact_form_url: row['Gov Email Form']&.strip.presence
          )
          stats[:officeholders_created] += 1
        end

        # 4. Link Party
        party_name = row['Party Roll Up']&.strip
        if party_name.present?
          party = Party.find_by(name: party_name)
          if party && !person.parties.include?(party)
            person.add_party(party, is_primary: person.parties.empty?)
            stats[:party_links] += 1
          end
        end

        # 5. Create Social Media Accounts
        social_mappings = {
          'Twitter Name (Gov)' => 'Twitter',
          'Facebook URL (Gov)' => 'Facebook',
          'Instagram URL (Gov)' => 'Instagram',
          'YouTube (Gov)' => 'YouTube',
          'TikTok (Gov)' => 'TikTok',
          'Threads (Gov)' => 'Threads'
        }
        social_mappings.each do |col, platform|
          handle_or_url = row[col]&.strip
          next if handle_or_url.blank?
          
          existing = SocialMediaAccount.find_by(person: person, platform: platform, handle: handle_or_url)
          unless existing
            SocialMediaAccount.create!(
              person: person,
              platform: platform,
              handle: handle_or_url,
              url: handle_or_url.start_with?('http') ? handle_or_url : nil,
              channel_type: 'Official Office',
              verified: true
            )
            stats[:social_accounts] += 1
          end
        end

      rescue => e
        stats[:errors] << "#{row['Official Name']}: #{e.message}"
      end
    end

    puts "\n" + "=" * 70
    puts "IMPORT COMPLETE FOR #{state}"
    puts "=" * 70
    puts "  Offices: #{stats[:offices_created]} created, #{stats[:offices_skipped]} existed"
    puts "  People: #{stats[:people_created]} created, #{stats[:people_found]} existed"
    puts "  Officeholders: #{stats[:officeholders_created]} created, #{stats[:officeholders_skipped]} skipped"
    puts "  Party links: #{stats[:party_links]}"
    puts "  Social accounts: #{stats[:social_accounts]}"
    puts "  Errors: #{stats[:errors].length}"
    if stats[:errors].any?
      puts "\nErrors:"
      stats[:errors].first(10).each { |e| puts "  - #{e}" }
    end
    puts "\nDB Totals: People=#{Person.count}, Offices=#{Office.count}, Officeholders=#{Officeholder.count}"
    puts "=" * 70
  end

  desc "Import all states from temp_govproj (uses staging table data)"
  task import_from_temp: :environment do
    puts "=" * 70
    puts "IMPORTING ALL DATA FROM TEMP_GOVPROJ"
    puts "=" * 70
    puts "Records to process: #{TempGovproj.count}"

    stats = {
      offices_created: 0, offices_skipped: 0,
      people_created: 0, people_found: 0,
      officeholders_created: 0, officeholders_skipped: 0,
      social_accounts: 0, party_links: 0,
      errors: []
    }

    map_level = ->(level) {
      case level
      when 'country' then 'federal'
      when 'administrativeArea1' then 'state'
      when 'administrativeArea2', 'locality', 'regional' then 'local'
      else 'local'
      end
    }

    map_branch = ->(role) {
      case role
      when 'legislatorLowerBody', 'legislatorUpperBody' then 'legislative'
      when 'headOfGovernment', 'deputyHeadOfGovernment', 'governmentOfficer', 'executiveCouncil', 'schoolBoard' then 'executive'
      when 'highestCourtJudge', 'judge' then 'judicial'
      else 'executive'
      end
    }

    parse_name = ->(full_name) {
      return { first_name: 'Unknown', last_name: 'Unknown' } if full_name.blank?
      name = full_name.dup
      suffixes = ['Jr.', 'Jr', 'Sr.', 'Sr', 'II', 'III', 'IV', 'V']
      suffix = nil
      suffixes.each do |s|
        pattern = Regexp.new('[,\s]\s*' + Regexp.escape(s) + '\.?\s*$', Regexp::IGNORECASE)
        if name.match?(pattern)
          suffix = s.sub(/\.$/, '')
          suffix = suffix + '.' if ['Jr', 'Sr'].include?(suffix)
          name = name.sub(pattern, '').strip
          break
        end
      end
      parts = name.split(/\s+/)
      if parts.length == 1
        { first_name: parts[0], last_name: 'Unknown', suffix: suffix }
      elsif parts.length == 2
        { first_name: parts[0], last_name: parts[1], suffix: suffix }
      else
        { first_name: parts[0], middle_name: parts[1..-2].join(' '), last_name: parts[-1], suffix: suffix }
      end
    }

    parse_date = ->(str) {
      return nil if str.blank?
      Date.parse(str) rescue nil
    }

    processed = 0
    total_records = TempGovproj.count
    batch_size = 1000

    TempGovproj.find_each do |row|
      begin
        office_uuid = row.office_uuid
        person_uuid = row.person_uuid
        next if office_uuid.blank? || person_uuid.blank?

        # 1. Find or create Office
        office = Office.find_by(airtable_id: office_uuid)
        unless office
          # Find or create the Body if body_name is present
          body = nil
          if row.body_name.present?
            body = Body.find_or_create_by!(name: row.body_name) do |b|
              b.country = row.state # Assume state-level or local
              b.classification = 'legislature' # Default, could be refined
            end
          end

          office = Office.create!(
            airtable_id: office_uuid,
            title: row.office_name || 'Unknown Office',
            level: map_level.call(row.level),
            branch: map_branch.call(row.role),
            role: row.role,
            state: row.state,
            office_category: row.office_category,
            body_name: row.body_name,
            body_id: body&.id, # Link to the Body record
            seat: row.seat.presence,
            jurisdiction: row.jurisdiction,
            jurisdiction_ocdid: row.jurisdiction_ocdid,
            ocdid: row.electoral_district_ocdid,
            county: row.county.presence
          )
          stats[:offices_created] += 1
        else
          stats[:offices_skipped] += 1
        end

        # 2. Find or create Person
        person = Person.find_by(person_uuid: person_uuid)
        unless person
          np = parse_name.call(row.official_name)
          person = Person.create!(
            person_uuid: person_uuid,
            first_name: np[:first_name],
            last_name: np[:last_name],
            middle_name: np[:middle_name],
            suffix: np[:suffix],
            birth_date: parse_date.call(row.dob),
            photo_url: row.photo_url.presence,
            website_official: row.website_official.presence,
            wikipedia_id: row.wiki_word.presence,
            state_of_residence: row.state
          )
          stats[:people_created] += 1
        else
          stats[:people_found] += 1
        end

        # 3. Create Officeholder
        start_date = parse_date.call(row.officeholder_start) || Date.current
        existing_oh = Officeholder.find_by(person: person, office: office)
        if existing_oh
          stats[:officeholders_skipped] += 1
        else
          Officeholder.create!(
            person: person,
            office: office,
            start_date: start_date,
            term_end_date: parse_date.call(row.term_end),
            next_election_date: parse_date.call(row.next_election_date),
            official_email: row.gov_email.presence,
            official_phone: row.gov_phone.presence,
            official_address: row.gov_mailing_address.presence,
            contact_form_url: row.gov_email_form.presence
          )
          stats[:officeholders_created] += 1
        end

        # 4. Link Party
        party_name = row.party_roll_up
        if party_name.present?
          party = Party.find_by(name: party_name)
          if party && !person.parties.include?(party)
            person.add_party(party, is_primary: person.parties.empty?)
            stats[:party_links] += 1
          end
        end

        # 5. Create Social Media Accounts
        social_data = {
          'Twitter' => row.twitter_name_gov,
          'Facebook' => row.facebook_url_gov,
          'Instagram' => row.instagram_url_gov,
          'YouTube' => row.youtube_gov,
          'TikTok' => row.tiktok_gov,
          'Threads' => row.threads_gov
        }
        social_data.each do |platform, handle_or_url|
          next if handle_or_url.blank?

          existing = SocialMediaAccount.find_by(person: person, platform: platform, handle: handle_or_url)
          unless existing
            SocialMediaAccount.create!(
              person: person,
              platform: platform,
              handle: handle_or_url,
              url: handle_or_url.start_with?('http') ? handle_or_url : nil,
              channel_type: 'Official Office',
              verified: true
            )
            stats[:social_accounts] += 1
          end
        end

        processed += 1
        if processed % batch_size == 0
          percent = ((processed.to_f / total_records) * 100).round(1)
          puts "\nProcessed #{processed}/#{total_records} (#{percent}%) - People: #{stats[:people_created]}, Offices: #{stats[:offices_created]}, Officeholders: #{stats[:officeholders_created]}"
        end

      rescue => e
        stats[:errors] << "#{row.official_name}: #{e.message}"
      end
    end

    puts "\n\n" + "=" * 70
    puts "IMPORT COMPLETE"
    puts "=" * 70
    puts "  Processed: #{processed}"
    puts "  Offices: #{stats[:offices_created]} created, #{stats[:offices_skipped]} existed"
    puts "  People: #{stats[:people_created]} created, #{stats[:people_found]} existed"
    puts "  Officeholders: #{stats[:officeholders_created]} created, #{stats[:officeholders_skipped]} skipped"
    puts "  Party links: #{stats[:party_links]}"
    puts "  Social accounts: #{stats[:social_accounts]}"
    puts "  Errors: #{stats[:errors].length}"
    if stats[:errors].any?
      puts "\nFirst 20 errors:"
      stats[:errors].first(20).each { |e| puts "  - #{e}" }
    end
    puts "\nDB Totals:"
    puts "  People: #{Person.count}"
    puts "  Offices: #{Office.count}"
    puts "  Officeholders: #{Officeholder.count}"
    puts "  SocialMediaAccounts: #{SocialMediaAccount.count}"
    puts "=" * 70
  end
end
