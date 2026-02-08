namespace :rebuild do
  desc "Complete database rebuild: clear data, import GovProj, import temp data, import 2026 candidates"
  task all: :environment do
    puts "\n" + "="*80
    puts "COMPLETE DATABASE REBUILD"
    puts "="*80
    puts "\nThis will:"
    puts "  1. Clear all people, contests, candidates, officeholders, accounts"
    puts "  2. Preserve: Users, States, Parties, Bodies"
    puts "  3. Import GovProj officeholder data"
    puts "  4. Extract districts from GovProj data"
    puts "  5. Import temp data for matched people"
    puts "  6. Import 2026 candidates with websites + placeholder accounts"
    puts "\n" + "="*80

    print "\nType 'yes' to continue: "
    response = STDIN.gets.chomp

    unless response.downcase == 'yes'
      puts "Aborted."
      exit
    end

    Rake::Task['rebuild:clear_data'].invoke
    Rake::Task['rebuild:import_govproj'].invoke
    Rake::Task['rebuild:extract_districts'].invoke
    Rake::Task['rebuild:import_temp_enrichment'].invoke
    Rake::Task['rebuild:import_2026_candidates'].invoke

    puts "\n" + "="*80
    puts "REBUILD COMPLETE!"
    puts "="*80
    puts "\nFinal counts:"
    puts "  People: #{Person.count}"
    puts "  Officeholders: #{Officeholder.count}"
    puts "  Districts: #{District.count}"
    puts "  Social Media Accounts: #{SocialMediaAccount.count}"
    puts "  Contests: #{Contest.count}"
    puts "  Candidates: #{Candidate.count}"
    puts "="*80
  end

  desc "Step 1: Clear existing data (preserve Users, States, Parties, Bodies)"
  task clear_data: :environment do
    puts "\n" + "="*80
    puts "CLEARING EXISTING DATA"
    puts "="*80

    puts "Clearing assignments..."
    Assignment.delete_all

    puts "Clearing social media accounts..."
    SocialMediaAccount.delete_all

    puts "Clearing candidates..."
    Candidate.delete_all

    puts "Clearing contests..."
    Contest.delete_all

    puts "Clearing ballots..."
    Ballot.delete_all

    puts "Clearing officeholders..."
    Officeholder.delete_all

    puts "Clearing offices..."
    Office.delete_all

    puts "Clearing districts..."
    District.delete_all

    puts "Clearing person_parties..."
    PersonParty.delete_all

    puts "Clearing people..."
    Person.delete_all

    puts "\n✓ Data cleared. Preserved: Users (#{User.count}), States (#{State.count}), Parties (#{Party.count}), Bodies (#{Body.count})"
    puts "="*80
  end

  desc "Step 2: Import GovProj officeholder data from temp_govproj"
  task import_govproj: :environment do
    puts "\n" + "="*80
    puts "IMPORTING GOVPROJ DATA FROM temp_govproj"
    puts "="*80
    puts "Records to process: #{TempGovproj.count}"
    puts "This will create: Offices, People, Officeholders, Official Social Media Accounts"
    puts "="*80

    Rake::Task['govproj:import_from_temp'].invoke
  end

  desc "Step 3: Enrich matched people with data from temp_people and temp_accounts"
  task import_temp_enrichment: :environment do
    puts "\n" + "="*80
    puts "ENRICHING MATCHED PEOPLE FROM TEMP DATA"
    puts "="*80
    puts "This will add race, gender, and campaign accounts for people who exist in both temp_people and main DB"
    puts "="*80

    stats = {
      people_matched: 0,
      race_added: 0,
      gender_added: 0,
      accounts_added: 0,
      errors: []
    }

    total_temp_people = TempPerson.count
    puts "Temp people to process: #{total_temp_people}"

    TempPerson.find_each do |temp_person|
      # Match by person_uuid
      person = Person.find_by(person_uuid: temp_person.person_uuid)
      next unless person

      stats[:people_matched] += 1

      # Add race if missing
      if person.race.blank? && temp_person.race.present?
        person.update_column(:race, temp_person.race)
        stats[:race_added] += 1
      end

      # Add gender if missing
      if person.gender.blank? && temp_person.gender.present?
        person.update_column(:gender, temp_person.gender)
        stats[:gender_added] += 1
      end

      # Add campaign social media accounts
      TempAccount.where(person_uuid: temp_person.person_uuid).each do |temp_account|
        next if temp_account.url.blank?
        next unless temp_account.channel_type == 'Campaign Account'

        # Skip if account already exists
        existing = SocialMediaAccount.find_by(
          person: person,
          platform: temp_account.platform,
          url: temp_account.url
        )
        next if existing

        begin
          # Extract handle from URL
          handle = case temp_account.platform
                   when 'Twitter'
                     temp_account.url.match(/@([\w]+)/)&.captures&.first || temp_account.url.split('/').last
                   when 'Facebook'
                     temp_account.url.split('/').last
                   when 'Instagram'
                     temp_account.url.match(/instagram\.com\/([\w.]+)/)&.captures&.first
                   else
                     temp_account.url.split('/').last
                   end

          SocialMediaAccount.create!(
            person: person,
            platform: temp_account.platform,
            url: temp_account.url,
            handle: handle,
            channel_type: 'Campaign',
            research_status: 'entered',
            verified: temp_account.verified || false
          )
          stats[:accounts_added] += 1
        rescue => e
          stats[:errors] << "#{person.full_name} / #{temp_account.platform}: #{e.message}"
        end
      end

      if stats[:people_matched] % 100 == 0
        puts "Matched #{stats[:people_matched]} people, added #{stats[:race_added]} races, #{stats[:gender_added]} genders, #{stats[:accounts_added]} accounts"
      end
    end

    puts "\n\n" + "="*80
    puts "TEMP DATA ENRICHMENT COMPLETE"
    puts "="*80
    puts "  People matched: #{stats[:people_matched]}"
    puts "  Race values added: #{stats[:race_added]}"
    puts "  Gender values added: #{stats[:gender_added]}"
    puts "  Campaign accounts added: #{stats[:accounts_added]}"
    puts "  Errors: #{stats[:errors].length}"
    if stats[:errors].any?
      puts "\nFirst 10 errors:"
      stats[:errors].first(10).each { |e| puts "  - #{e}" }
    end
    puts "="*80
  end

  desc "Step 4: Extract districts from GovProj data"
  task extract_districts: :environment do
    puts "\n" + "="*80
    puts "EXTRACTING DISTRICTS FROM GOVPROJ DATA"
    puts "="*80
    puts "Parsing district information from electoral_district_ocdid field"
    puts "="*80

    stats = {
      congressional: 0,
      at_large: 0,
      state_senate: 0,
      state_house: 0,
      other: 0,
      skipped: 0
    }

    # Extract districts from unique OCDIDs
    TempGovproj.where.not(electoral_district_ocdid: [nil, '']).distinct.pluck(:electoral_district_ocdid, :state).each do |ocdid, state|
      # Parse OCDID for district information
      # Congressional: ocd-division/country:us/state:al/cd:1
      # State Senate (upper): ocd-division/country:us/state:ak/sldu:a
      # State House (lower): ocd-division/country:us/state:ak/sldl:1

      if ocdid =~ /\/cd:(\d+)$/
        # Congressional district
        district_number = $1.to_i
        district = District.find_or_create_by!(
          state: state.upcase,
          level: 'federal',
          chamber: nil,
          district_number: district_number
        )
        district.update(ocdid: ocdid) if district.ocdid.blank?
        stats[:congressional] += 1
      elsif ocdid =~ /\/sldu:(.+)$/
        # State senate (upper chamber)
        district_id = $1
        # Convert letter districts to numbers (A=1, B=2, etc) if all letters
        district_number = district_id =~ /^\d+$/ ? district_id.to_i : district_id.upcase.ord - 64
        district = District.find_or_create_by!(
          state: state.upcase,
          level: 'state',
          chamber: 'upper',
          district_number: district_number
        )
        district.update(ocdid: ocdid) if district.ocdid.blank?
        stats[:state_senate] += 1
      elsif ocdid =~ /\/sldl:(.+)$/
        # State house (lower chamber)
        district_id = $1
        district_number = district_id =~ /^\d+$/ ? district_id.to_i : district_id.upcase.ord - 64
        district = District.find_or_create_by!(
          state: state.upcase,
          level: 'state',
          chamber: 'lower',
          district_number: district_number
        )
        district.update(ocdid: ocdid) if district.ocdid.blank?
        stats[:state_house] += 1
      else
        # Other district types (local, etc) - skip for now
        stats[:skipped] += 1
      end

      print "." if (stats[:congressional] + stats[:state_senate] + stats[:state_house]) % 100 == 0
    end

    # Extract at-large congressional districts (states/territories with only 1 House member)
    # These don't have /cd:N suffix, just use the state/territory OCDID
    puts "\n\nExtracting at-large congressional districts..."
    TempGovproj.where(body_name: 'U.S. House of Representatives')
               .where.not('electoral_district_ocdid LIKE ?', '%/cd:%')
               .distinct
               .pluck(:state, :electoral_district_ocdid)
               .each do |state, ocdid|
      district = District.find_or_create_by!(
        state: state.upcase,
        level: 'federal',
        chamber: nil,
        district_number: 0  # Use 0 to indicate at-large
      )
      district.update(ocdid: ocdid) if district.ocdid.blank?
      stats[:at_large] += 1
      print "."
    end

    puts "\n\n" + "="*80
    puts "DISTRICT EXTRACTION COMPLETE"
    puts "="*80
    puts "  Congressional districts (numbered): #{stats[:congressional]}"
    puts "  Congressional districts (at-large): #{stats[:at_large]}"
    puts "  Total congressional: #{stats[:congressional] + stats[:at_large]}"
    puts "  State senate districts: #{stats[:state_senate]}"
    puts "  State house districts: #{stats[:state_house]}"
    puts "  Other/skipped: #{stats[:skipped]}"
    puts "  Total districts created: #{District.count}"
    puts "="*80
  end

  desc "Step 5: Import 2026 candidates with websites and smart placeholder accounts"
  task import_2026_candidates: :environment do
    puts "\n" + "="*80
    puts "IMPORTING 2026 CANDIDATES"
    puts "="*80
    puts "Using enhanced importer with website import and smart placeholder logic"
    puts "="*80

    csv_path = Rails.root.join('data', '2026_states', '2026_candidates_cleaned.csv')

    unless File.exist?(csv_path)
      puts "❌ Cleaned CSV not found at #{csv_path}"
      exit 1
    end

    importer = Importers::EnhancedCandidate2026Importer.new(csv_path)
    importer.import
  end
end
