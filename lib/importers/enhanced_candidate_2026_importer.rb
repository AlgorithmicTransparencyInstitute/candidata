require 'csv'

module Importers
  class EnhancedCandidate2026Importer
    PRIMARY_DATE = Date.new(2026, 3, 4) # Default primary date (will vary by state)
    CORE_PLATFORMS = ['Facebook', 'Twitter', 'Instagram', 'YouTube', 'TikTok', 'BlueSky'].freeze

    def initialize(csv_path)
      @csv_path = csv_path
      @stats = {
        total_rows: 0,
        people_created: 0,
        people_matched: 0,
        people_skipped: 0,
        ballots_created: 0,
        contests_created: 0,
        candidates_created: 0,
        accounts_with_data: 0,
        accounts_placeholder: 0,
        errors: []
      }
      @ballot_cache = {}
    end

    def import
      puts "\n" + "="*80
      puts "IMPORTING 2026 PRIMARY CANDIDATES (ENHANCED)"
      puts "="*80
      puts "Features:"
      puts "  ✓ Import campaign websites to Person.website_campaign"
      puts "  ✓ Create real accounts for platforms with data"
      puts "  ✓ Create placeholders for platforms without data"
      puts "  ✓ Ensures all candidates have 6 core platform rows"
      puts "="*80

      CSV.foreach(@csv_path, headers: true) do |row|
        @stats[:total_rows] += 1
        process_row(row)
      end

      print_report
    end

    private

    def process_row(row)
      # Skip withdrawn candidates
      return if row['withdrew'] == 'true'

      # Skip if missing critical data
      unless row['candidate_name'].present? && row['party'].present? && row['office'].present?
        @stats[:people_skipped] += 1
        @stats[:errors] << "Row #{@stats[:total_rows]}: Missing critical data - #{row['candidate_name']}"
        return
      end

      # Find or create the person
      person = find_or_create_person(row)
      return unless person

      # Find or create ballot
      ballot = find_or_create_ballot(row)
      return unless ballot

      # Find or create office
      office = find_or_create_office(row)
      return unless office

      # Find or create contest
      contest = find_or_create_contest(row, ballot, office)
      return unless contest

      # Create candidate record
      create_candidate(person, contest, row)

      # Create campaign social media accounts (smart placeholders)
      create_campaign_accounts(person, row)

    rescue => e
      @stats[:errors] << "Row #{@stats[:total_rows]}: #{e.message}"
      puts "❌ Error processing #{row['candidate_name']}: #{e.message}"
    end

    def find_or_create_person(row)
      name = row['candidate_name'].strip
      state = row['state']
      is_incumbent = row['is_incumbent'] == 'true'

      # Try to match existing person
      person = match_existing_person(name, state, is_incumbent)

      if person
        @stats[:people_matched] += 1
        puts "✓ Matched existing person: #{person.full_name} (#{state})"

        # Update website_campaign if provided and not already set
        if row['website'].present? && person.website_campaign.blank?
          person.update_column(:website_campaign, row['website'])
        end

        return person
      end

      # Parse name into first/last
      name_parts = parse_name(name)
      unless name_parts
        @stats[:people_skipped] += 1
        @stats[:errors] << "Could not parse name: #{name}"
        return nil
      end

      # Create new person
      person = Person.create!(
        first_name: name_parts[:first],
        middle_name: name_parts[:middle],
        last_name: name_parts[:last],
        suffix: name_parts[:suffix],
        state_of_residence: state,
        gender: standardize_gender(row['gender']),
        race: row['race'],
        website_campaign: row['website'] # ← IMPORT WEBSITE!
      )

      @stats[:people_created] += 1
      puts "✨ Created new person: #{person.full_name} (#{state})"

      person
    end

    def match_existing_person(name, state, is_incumbent)
      # For incumbents, try harder to match
      if is_incumbent
        # Try exact match on full name in same state
        name_parts = parse_name(name)
        return nil unless name_parts

        Person.where(state_of_residence: state)
              .where("LOWER(first_name) = ? AND LOWER(last_name) = ?",
                     name_parts[:first].downcase,
                     name_parts[:last].downcase)
              .first
      else
        # For non-incumbents, don't auto-match (too risky)
        nil
      end
    end

    def parse_name(full_name)
      # Handle nicknames in quotes: James "Rus" Russell
      # Handle suffixes: John Smith III, John Smith Jr.

      # Remove extra whitespace
      name = full_name.strip

      # Extract suffix (Jr., Sr., III, IV, etc.)
      suffix = nil
      if name =~ /\s+(Jr\.?|Sr\.?|III|IV|V|II)$/i
        suffix = $1
        name = name.sub(/\s+(Jr\.?|Sr\.?|III|IV|V|II)$/i, '').strip
      end

      # Extract nickname in quotes
      nickname = nil
      if name =~ /"([^"]+)"/
        nickname = $1
        name = name.gsub(/"[^"]+"/, '').strip
      end

      # Split remaining name
      parts = name.split(/\s+/)

      return nil if parts.length < 2

      if parts.length == 2
        # Simple: First Last
        {
          first: parts[0],
          middle: nickname,
          last: parts[1],
          suffix: suffix
        }
      elsif parts.length == 3
        # Could be: First Middle Last or First Last-Last
        if parts[1].include?('-') || parts[2].include?('-')
          # Hyphenated last name
          {
            first: parts[0],
            middle: nickname,
            last: parts[1..2].join(' '),
            suffix: suffix
          }
        else
          # First Middle Last
          {
            first: parts[0],
            middle: nickname || parts[1],
            last: parts[2],
            suffix: suffix
          }
        end
      else
        # 4+ parts: assume everything after first is middle + last
        {
          first: parts[0],
          middle: nickname || parts[1..-2].join(' '),
          last: parts[-1],
          suffix: suffix
        }
      end
    end

    def standardize_gender(gender_str)
      return nil if gender_str.blank?
      case gender_str.downcase
      when 'male', 'm'
        'Male'
      when 'female', 'f'
        'Female'
      else
        'Other'
      end
    end

    def create_campaign_accounts(person, row)
      # CSV columns mapped to platforms
      csv_platform_map = {
        'twitter' => 'Twitter',
        'facebook' => 'Facebook',
        'instagram' => 'Instagram',
        'youtube' => 'YouTube',
        'tiktok' => 'TikTok',
        'bluesky' => 'BlueSky'
      }

      # For each core platform, create either real account or placeholder
      CORE_PLATFORMS.each do |platform|
        # Find the CSV column for this platform
        csv_col = csv_platform_map.invert[platform]
        url = row[csv_col]&.strip

        # Check if account already exists for this person/platform/channel
        existing = SocialMediaAccount.find_by(
          person: person,
          platform: platform,
          channel_type: 'Campaign'
        )

        if existing
          # Account already exists (maybe from temp data import), skip
          next
        end

        if url.present?
          # CSV has data → create real account
          handle = extract_handle_from_url(url, platform)

          SocialMediaAccount.create!(
            person: person,
            platform: platform,
            channel_type: 'Campaign',
            url: url,
            handle: handle,
            research_status: 'entered',
            pre_populated: false
          )
          @stats[:accounts_with_data] += 1
        else
          # CSV has no data → create placeholder for research
          SocialMediaAccount.create!(
            person: person,
            platform: platform,
            channel_type: 'Campaign',
            research_status: 'not_started',
            pre_populated: true
          )
          @stats[:accounts_placeholder] += 1
        end
      end
    end

    def extract_handle_from_url(url, platform)
      # Simple handle extraction (could be improved)
      case platform
      when 'Twitter'
        url.match(/@([\w]+)/)&.captures&.first || url.split('/').last
      when 'Facebook'
        url.split('/').last
      when 'Instagram'
        url.match(/instagram\.com\/([\w.]+)/)&.captures&.first
      else
        url.split('/').last
      end
    end

    def find_or_create_ballot(row)
      state = row['state']
      party = row['party']

      # Use cached ballot if already created for this state+party
      cache_key = "#{state}_#{party}"
      if @ballot_cache[cache_key]
        # Reload to ensure it's still valid
        return @ballot_cache[cache_key].reload
      end

      ballot = Ballot.find_or_create_by!(
        state: state,
        date: PRIMARY_DATE,
        election_type: 'primary',
        party: party
      ) do |b|
        b.year = 2026
        b.name = "2026 #{state} #{party} Primary"
      end

      if ballot.previously_new_record?
        @stats[:ballots_created] += 1
        puts "🗳️  Created ballot: #{ballot.full_name}"
      end

      # Cache it
      @ballot_cache[cache_key] = ballot
      ballot
    rescue ActiveRecord::RecordInvalid => e
      # If creation failed, try to find it (might have been created by another process)
      ballot = Ballot.find_by!(
        state: state,
        date: PRIMARY_DATE,
        election_type: 'primary',
        party: party
      )
      @ballot_cache[cache_key] = ballot
      ballot
    end

    def find_or_create_office(row)
      state = row['state']
      office_type = row['office']
      district = row['district']

      case office_type
      when 'U.S. House'
        # Find U.S. Representative with matching state and district
        seat = "District #{district}"

        # Find matching district
        district_record = District.find_by(
          state: state,
          level: 'federal',
          district_number: district.to_i
        )

        Office.find_or_create_by!(
          title: 'U.S. Representative',
          state: state,
          seat: seat
        ) do |o|
          o.level = 'federal'
          o.branch = 'legislative'
          o.role = 'legislatorLowerBody'
          o.office_category = 'U.S. Representative'
          o.body_name = 'U.S. House of Representatives'
          o.district_id = district_record&.id
        end
      when 'U.S. Senate'
        # Find U.S. Senator for this state
        Office.find_or_create_by!(
          title: 'U.S. Senator',
          state: state
        ) do |o|
          o.level = 'federal'
          o.branch = 'legislative'
          o.role = 'legislatorUpperBody'
          o.office_category = 'U.S. Senator'
          o.body_name = 'U.S. Senate'
        end
      else
        @stats[:errors] << "Unknown office type: #{office_type}"
        nil
      end
    end

    def find_or_create_contest(row, ballot, office)
      contest = Contest.find_or_create_by!(
        ballot: ballot,
        office: office,
        contest_type: 'primary',
        party: row['party']
      ) do |c|
        c.date = PRIMARY_DATE
        c.location = row['state']
      end

      if contest.previously_new_record?
        @stats[:contests_created] += 1
        puts "🏁 Created contest: #{contest.full_name}"
      end

      contest
    end

    def create_candidate(person, contest, row)
      is_incumbent = row['is_incumbent'] == 'true'

      candidate = Candidate.find_or_create_by!(
        person: person,
        contest: contest
      ) do |c|
        c.party_at_time = row['party']
        c.incumbent = is_incumbent
        c.outcome = 'pending' # Primary hasn't happened yet
      end

      if candidate.previously_new_record?
        @stats[:candidates_created] += 1
      end
    end

    def print_report
      puts "\n" + "="*80
      puts "IMPORT COMPLETE"
      puts "="*80
      puts "Total rows processed: #{@stats[:total_rows]}"
      puts "\nPEOPLE:"
      puts "  ✨ Created: #{@stats[:people_created]}"
      puts "  ✓ Matched existing: #{@stats[:people_matched]}"
      puts "  ⊘ Skipped: #{@stats[:people_skipped]}"
      puts "\nBALLOTS:"
      puts "  Created: #{@stats[:ballots_created]}"
      puts "\nCONTESTS:"
      puts "  Created: #{@stats[:contests_created]}"
      puts "\nCANDIDATES:"
      puts "  Created: #{@stats[:candidates_created]}"
      puts "\nSOCIAL MEDIA ACCOUNTS:"
      puts "  ✓ With data (from CSV): #{@stats[:accounts_with_data]}"
      puts "  📝 Placeholders (need research): #{@stats[:accounts_placeholder]}"
      puts "  TOTAL: #{@stats[:accounts_with_data] + @stats[:accounts_placeholder]}"

      if @stats[:errors].any?
        puts "\n⚠️  ERRORS (#{@stats[:errors].length}):"
        @stats[:errors].first(10).each do |error|
          puts "  - #{error}"
        end
        if @stats[:errors].length > 10
          puts "  ... and #{@stats[:errors].length - 10} more"
        end
      end

      puts "="*80
      puts "\nTo review imported data:"
      puts "  Ballots: Ballot.for_year(2026).for_state('TX')"
      puts "  Contests: Contest.for_year(2026).for_party('Democratic')"
      puts "  Candidates: Candidate.joins(:contest).merge(Contest.for_year(2026))"
      puts "  Accounts needing research: SocialMediaAccount.campaign.needs_research.count"
      puts "="*80
    end
  end
end
