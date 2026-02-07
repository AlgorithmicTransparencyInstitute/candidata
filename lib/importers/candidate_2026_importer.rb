require 'csv'

class Candidate2026Importer
  PRIMARY_DATE = Date.new(2026, 3, 4) # Default primary date (will vary by state)

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
      errors: []
    }
    @ballot_cache = {}
  end

  def import
    puts "\n" + "="*80
    puts "IMPORTING 2026 PRIMARY CANDIDATES"
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
      race: row['race']
    )

    @stats[:people_created] += 1
    puts "✨ Created new person: #{person.full_name} (#{state})"

    # Create social media accounts
    create_social_media_accounts(person, row)

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

  def create_social_media_accounts(person, row)
    platforms = {
      'twitter' => 'Twitter',
      'facebook' => 'Facebook',
      'instagram' => 'Instagram',
      'youtube' => 'YouTube',
      'tiktok' => 'TikTok',
      'bluesky' => 'BlueSky'
    }

    platforms.each do |csv_col, platform_name|
      url = row[csv_col]
      next if url.blank?

      # Determine handle from URL
      handle = extract_handle_from_url(url, platform_name)

      SocialMediaAccount.find_or_create_by!(
        person: person,
        platform: platform_name,
        channel_type: 'Campaign'
      ) do |account|
        account.url = url
        account.handle = handle
        account.research_status = 'entered'
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
    puts "="*80
  end
end
