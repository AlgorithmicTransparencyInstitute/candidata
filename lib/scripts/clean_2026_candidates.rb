#!/usr/bin/env ruby
require 'csv'
require 'fileutils'

class CandidateDataCleaner
  INPUT_DIR = Rails.root.join('data', '2026_states')
  OUTPUT_FILE = Rails.root.join('data', '2026_states', '2026_candidates_cleaned.csv')

  # State mapping from filename to 2-letter code
  STATE_MAP = {
    'Arkansas' => 'AR',
    'Illinois' => 'IL',
    'Kentucky' => 'KY',
    'Mississippi' => 'MS',
    'NorthCarolina' => 'NC',
    'Texas' => 'TX'
  }

  # Standardized output columns
  OUTPUT_HEADERS = %w[
    state
    candidate_name
    is_incumbent
    withdrew
    party
    office
    district
    race
    gender
    website
    twitter
    facebook
    instagram
    youtube
    tiktok
    bluesky
    notes
  ]

  def initialize
    @cleaned_rows = []
    @stats = Hash.new(0)
  end

  def run
    puts "Starting data cleaning process..."

    STATE_MAP.each do |state_name, state_code|
      process_state_files(state_name, state_code)
    end

    write_cleaned_csv
    print_stats
  end

  private

  def process_state_files(state_name, state_code)
    # Find CSV files for this state
    pattern = INPUT_DIR.join("#{state_name}*.csv")
    files = Dir.glob(pattern)

    if files.empty?
      puts "⚠️  No files found for #{state_name}"
      return
    end

    # Use the first file (or the one without "(1)" if there are duplicates)
    file = files.size > 1 ? files.reject { |f| f.include?('(1)') }.first : files.first

    puts "\n📄 Processing #{File.basename(file)} → #{state_code}"

    process_csv_file(file, state_code)
  end

  def process_csv_file(file_path, state_code)
    csv = CSV.read(file_path, headers: true, encoding: 'UTF-8')

    csv.each_with_index do |row, index|
      # Skip empty rows or rows that are just notes (like NC's footer)
      next if row['CandidateName'].nil? || row['CandidateName'].strip.empty?
      next if row['CandidateName'].start_with?('Primaries called off')
      next if row['CandidateName'].strip == 'District'

      cleaned = clean_row(row, state_code)
      @cleaned_rows << cleaned
      @stats[:total_candidates] += 1
      @stats[:incumbents] += 1 if cleaned[:is_incumbent]
      @stats[:withdrew] += 1 if cleaned[:withdrew]
    end
  rescue => e
    puts "❌ Error processing #{file_path}: #{e.message}"
    puts e.backtrace.first(5)
  end

  def clean_row(row, state_code)
    {
      state: state_code,
      candidate_name: clean_candidate_name(row['CandidateName']),
      is_incumbent: is_incumbent?(row['CandidateName']),
      withdrew: withdrew?(row),
      party: standardize_party(row['Party']),
      office: standardize_office(row['Office']),
      district: clean_district(row['District']),
      race: standardize_race(row['Race']),
      gender: standardize_gender(row['Gender']),
      website: clean_url(row['Website']),
      twitter: clean_url(row['Twitter']),
      facebook: clean_url(row['Facebook']),
      instagram: clean_url(row['Instagram']),
      youtube: clean_url(row['YouTube']),
      tiktok: clean_url(row['TikTok']),
      bluesky: clean_url(row['BlueSky'] || row['BlueSkye']),
      notes: clean_notes(row['Notes'])
    }
  end

  def clean_candidate_name(name)
    return nil if name.nil?

    # Remove "(Incumbent)" from name
    name = name.gsub(/\s*\(Incumbent\)\s*/, '')

    # Remove quotes that are just formatting (not part of nickname)
    # Keep quotes that are clearly nicknames like: James "Rus" Russell
    name = name.gsub(/^["']|["']$/, '')

    # Clean up extra whitespace
    name.strip
  end

  def is_incumbent?(name)
    return false if name.nil?
    name.include?('(Incumbent)')
  end

  def withdrew?(row)
    # Texas has a "Withdrew" column with "X" for withdrawn candidates
    return true if row['Withdrew'] == 'X'
    false
  end

  def standardize_party(party)
    return nil if party.nil? || party.strip.empty?

    party = party.strip

    # Handle "99" as missing data
    return nil if party == '99'

    # Standardize party names
    case party.downcase
    when 'd', 'democrat', 'democratic'
      'Democratic'
    when 'r', 'republican'
      'Republican'
    when 'l', 'libertarian'
      'Libertarian'
    when 'i', 'independent', 'independent/write in'
      'Independent'
    when 'working class'
      'Working Class'
    else
      party # Keep original if not recognized
    end
  end

  def standardize_office(office)
    return nil if office.nil? || office.strip.empty?

    office = office.strip

    case office.downcase
    when 's', 'senate', 'u.s. senate'
      'U.S. Senate'
    when 'h', 'house', 'u.s. house'
      'U.S. House'
    else
      office
    end
  end

  def clean_district(district)
    return nil if district.nil? || district.strip.empty?

    district = district.strip

    # Handle "99" as missing data
    return nil if district == '99'

    # Handle state names in district field (Illinois error)
    return nil if district.match?(/^[A-Za-z]+$/)

    # Return the district number
    district
  end

  def standardize_race(race)
    return nil if race.nil? || race.strip.empty?

    race = race.strip

    # Handle "99" or "other/99" as missing data
    return nil if race == '99' || race.downcase.start_with?('other/99') || race.downcase == 'not sure'

    # Standardize race values
    case race.downcase
    when 'white, non-hispanic', 'white'
      'White'
    when 'black'
      'Black'
    when 'hispanic'
      'Hispanic'
    when 'asian', 'asian american'
      'Asian'
    when 'other', 'mixed'
      'Other'
    else
      nil # For unclear values
    end
  end

  def standardize_gender(gender)
    return nil if gender.nil? || gender.strip.empty?

    gender = gender.strip

    # Handle "99" as missing data
    return nil if gender == '99'

    # Standardize gender values
    case gender.downcase
    when 'm', 'male'
      'Male'
    when 'f', 'female'
      'Female'
    when 'i'
      'Non-binary'
    else
      nil
    end
  end

  def clean_url(url)
    return nil if url.nil? || url.strip.empty?

    url = url.strip

    # Handle "99" as missing data
    return nil if url == '99'

    # Handle "see notes" as missing data
    return nil if url.downcase.include?('see notes')

    # Handle "see notes for all social media/99"
    return nil if url.downcase.include?('see notes for all')

    # Return the URL
    url
  end

  def clean_notes(notes)
    return nil if notes.nil? || notes.strip.empty?

    notes = notes.strip

    # Handle "N/A" as empty
    return nil if notes.downcase == 'n/a'

    notes
  end

  def write_cleaned_csv
    puts "\n📝 Writing cleaned CSV to #{OUTPUT_FILE}..."

    CSV.open(OUTPUT_FILE, 'w') do |csv|
      csv << OUTPUT_HEADERS

      @cleaned_rows.each do |row|
        csv << OUTPUT_HEADERS.map { |header| row[header.to_sym] }
      end
    end

    puts "✅ Cleaned CSV written successfully!"
  end

  def print_stats
    puts "\n" + "="*60
    puts "CLEANING STATISTICS"
    puts "="*60
    puts "Total candidates processed: #{@stats[:total_candidates]}"
    puts "Incumbents identified: #{@stats[:incumbents]}"
    puts "Withdrawn candidates: #{@stats[:withdrew]}"
    puts "\nBreakdown by state:"

    STATE_MAP.each do |state_name, state_code|
      count = @cleaned_rows.count { |r| r[:state] == state_code }
      puts "  #{state_code}: #{count} candidates"
    end

    puts "\nBreakdown by office:"
    @cleaned_rows.group_by { |r| r[:office] }.each do |office, rows|
      puts "  #{office}: #{rows.size} candidates"
    end

    puts "\nBreakdown by party:"
    @cleaned_rows.group_by { |r| r[:party] }.each do |party, rows|
      puts "  #{party || '(Unknown)'}: #{rows.size} candidates"
    end

    puts "="*60
  end
end

# Run the cleaner
cleaner = CandidateDataCleaner.new
cleaner.run
