require 'csv'

namespace :csv do
  desc "Import all CSV files into temp tables"
  task import: :environment do
    puts "Importing CSV files into temp tables..."
    
    # Clear existing data
    TempPerson.delete_all
    TempAccount.delete_all
    
    # Import People CSVs
    import_people_csv('data/Federal_People.csv', 'federal')
    import_people_csv('data/State_People.csv', 'state')
    
    # Import Accounts CSVs
    import_accounts_csv('data/Federal_Accounts.csv', 'federal')
    import_accounts_csv('data/State_Accounts.csv', 'state')
    
    puts "\n" + "=" * 60
    puts "IMPORT COMPLETE"
    puts "=" * 60
    puts "  TempPerson records: #{TempPerson.count}"
    puts "  TempAccount records: #{TempAccount.count}"
    puts "=" * 60
  end
  
  desc "Analyze temp tables to determine seed requirements"
  task analyze: :environment do
    puts "Analyzing temp data for seed requirements..."
    puts "\n" + "=" * 60
    
    # States
    puts "\n--- STATES ---"
    states = TempPerson.where.not(state: [nil, '']).group(:state).count
    puts "Total unique states: #{states.keys.length}"
    states.sort_by { |_, v| -v }.each do |state, count|
      puts "  #{state}: #{count}"
    end
    
    # Levels
    puts "\n--- LEVELS ---"
    levels = TempPerson.where.not(level: [nil, '']).group(:level).count
    levels.sort_by { |_, v| -v }.each do |level, count|
      puts "  #{level}: #{count}"
    end
    
    # Roles
    puts "\n--- ROLES ---"
    roles = TempPerson.where.not(role: [nil, '']).group(:role).count
    roles.sort_by { |_, v| -v }.each do |role, count|
      puts "  #{role}: #{count}"
    end
    
    # Office Names
    puts "\n--- OFFICE NAMES ---"
    office_names = TempPerson.where.not(office_name: [nil, '']).group(:office_name).count
    puts "Total unique office names: #{office_names.keys.length}"
    office_names.sort_by { |_, v| -v }.first(30).each do |name, count|
      puts "  #{name}: #{count}"
    end
    puts "  ... and #{office_names.keys.length - 30} more" if office_names.keys.length > 30
    
    # Office Categories
    puts "\n--- OFFICE CATEGORIES ---"
    office_categories = TempPerson.where.not(office_category: [nil, '']).group(:office_category).count
    puts "Total unique office categories: #{office_categories.keys.length}"
    office_categories.sort_by { |_, v| -v }.each do |cat, count|
      puts "  #{cat}: #{count}"
    end
    
    # Body Names
    puts "\n--- BODY NAMES ---"
    body_names = TempPerson.where.not(body_name: [nil, '']).group(:body_name).count
    puts "Total unique body names: #{body_names.keys.length}"
    body_names.sort_by { |_, v| -v }.first(20).each do |body, count|
      puts "  #{body}: #{count}"
    end
    puts "  ... and #{body_names.keys.length - 20} more" if body_names.keys.length > 20
    
    # Parties
    puts "\n--- PARTIES ---"
    parties = TempPerson.where.not(registered_political_party: [nil, '']).group(:registered_political_party).count
    puts "Total unique parties: #{parties.keys.length}"
    parties.sort_by { |_, v| -v }.each do |party, count|
      puts "  #{party}: #{count}"
    end
    
    # Party Roll Up
    puts "\n--- PARTY ROLL UP ---"
    party_rollups = TempPerson.where.not(party_roll_up: [nil, '']).group(:party_roll_up).count
    party_rollups.sort_by { |_, v| -v }.each do |party, count|
      puts "  #{party}: #{count}"
    end
    
    # Jurisdictions
    puts "\n--- JURISDICTIONS ---"
    jurisdictions = TempPerson.where.not(jurisdiction: [nil, '']).group(:jurisdiction).count
    puts "Total unique jurisdictions: #{jurisdictions.keys.length}"
    jurisdictions.sort_by { |_, v| -v }.first(20).each do |jur, count|
      puts "  #{jur}: #{count}"
    end
    puts "  ... and #{jurisdictions.keys.length - 20} more" if jurisdictions.keys.length > 20
    
    # Platforms (from Accounts)
    puts "\n--- PLATFORMS (from Accounts) ---"
    platforms = TempAccount.where.not(platform: [nil, '']).group(:platform).count
    platforms.sort_by { |_, v| -v }.each do |platform, count|
      puts "  #{platform}: #{count}"
    end
    
    # Channel Types (from Accounts)
    puts "\n--- CHANNEL TYPES (from Accounts) ---"
    channel_types = TempAccount.where.not(channel_type: [nil, '']).group(:channel_type).count
    channel_types.sort_by { |_, v| -v }.each do |type, count|
      puts "  #{type}: #{count}"
    end
    
    # Account Status
    puts "\n--- ACCOUNT STATUS ---"
    statuses = TempAccount.where.not(status: [nil, '']).group(:status).count
    statuses.sort_by { |_, v| -v }.each do |status, count|
      puts "  #{status}: #{count}"
    end
    
    puts "\n" + "=" * 60
  end
end

def import_people_csv(file_path, source_type)
  puts "\nImporting #{file_path}..."
  
  unless File.exist?(file_path)
    puts "  ERROR: File not found: #{file_path}"
    return
  end
  
  count = 0
  errors = 0
  
  CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
    begin
      # Skip completely empty rows
      next if row.to_h.values.all?(&:blank?)
      
      TempPerson.create!(
        source_type: source_type,
        official_name: row['Official Name'],
        state: row['State'],
        level: row['Level'],
        role: row['Role'],
        jurisdiction: row['Jurisdiction'],
        jurisdiction_ocdid: row['Jurisdiction OCDID'],
        electoral_district: row['Electoral District'],
        electoral_district_ocdid: row['Electoral District OCDID'],
        office_uuid: row['Office UUID'],
        office_name: row['Office Name'],
        seat: row['Seat'],
        office_category: row['Office Category'],
        body_name: row['Body Name'],
        person_uuid: row['Person UUID'],
        registered_political_party: row['Registered Political Party'],
        race: row['Race'],
        gender: row['Gender'],
        photo_url: row['Photo URL'],
        website_official: row['Website (Official)'],
        website_campaign: row['Website (Campaign)'],
        website_personal: row['Website (Personal)'],
        candidate_uuid: row['Candidate UUID'],
        incumbent: parse_boolean(row['Incumbent']),
        is_2024_candidate: parse_boolean(row['2024 Candidate']),
        is_2024_office_holder: parse_boolean(row['2024 Office Holder']),
        general_election_winner: row['General Election Winner'],
        party_roll_up: row['Party Roll Up'],
        raw_data: row.to_h.to_json
      )
      count += 1
      
      print "\r  Imported #{count} records..." if count % 500 == 0
    rescue => e
      errors += 1
      puts "\n  Error on row #{count + errors}: #{e.message}" if errors <= 5
    end
  end
  
  puts "\r  ✓ Imported #{count} records from #{source_type} people (#{errors} errors)"
end

def import_accounts_csv(file_path, source_type)
  puts "\nImporting #{file_path}..."
  
  unless File.exist?(file_path)
    puts "  ERROR: File not found: #{file_path}"
    return
  end
  
  count = 0
  errors = 0
  
  CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
    begin
      # Skip completely empty rows
      next if row.to_h.values.all?(&:blank?)
      
      TempAccount.create!(
        source_type: source_type,
        url: row['URL'],
        platform: row['Platform'],
        channel_type: row['Channel Type'],
        status: row['Status'],
        state: row['State (from People)'],
        office_name: row['Office Name (from People)'],
        level: row['Level (from People)'],
        office_category: row['Office Category (from People)'],
        people_name: row['People'],
        party_roll_up: row['Party Roll Up (from People)'],
        account_inactive: parse_boolean(row['Account Inactive']),
        verified: parse_boolean(row['Verified']),
        person_uuid: row['person_uuid'],
        raw_data: row.to_h.to_json
      )
      count += 1
      
      print "\r  Imported #{count} records..." if count % 1000 == 0
    rescue => e
      errors += 1
      puts "\n  Error on row #{count + errors}: #{e.message}" if errors <= 5
    end
  end
  
  puts "\r  ✓ Imported #{count} records from #{source_type} accounts (#{errors} errors)"
end

def parse_boolean(value)
  return nil if value.blank?
  %w[true True TRUE yes Yes YES 1 checked].include?(value.to_s.strip)
end
